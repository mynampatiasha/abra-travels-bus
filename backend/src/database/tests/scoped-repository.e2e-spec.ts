import { type INestApplication } from '@nestjs/common';
import { getConnectionToken } from '@nestjs/mongoose';
import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import {
  type DataScopeType,
  type RequestActor,
  systemActor,
} from '../../common/request-context/request-actor';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { TransactionRunner } from '../transaction-runner.service';
import { createDatabaseTestApplication, ScopeProbeRepository } from './scope-probe.fixture';

const operatorA = new Types.ObjectId();
const operatorB = new Types.ObjectId();
const partner = new Types.ObjectId();
const customer = new Types.ObjectId();

function userActor(
  type: DataScopeType,
  operatorIds: Types.ObjectId[] = [],
  extra: { userId?: string; partnerId?: string } = {},
): RequestActor {
  return {
    actorType: 'USER',
    userId: extra.userId ?? new Types.ObjectId().toHexString(),
    ...(extra.partnerId ? { partnerId: extra.partnerId } : {}),
    dataScope: { type, operatorIds: operatorIds.map((id) => id.toHexString()) },
  };
}

function as<T>(actor: RequestActor, work: () => Promise<T>): Promise<T> {
  return RequestContextService.run({ requestId: 'scope-e2e', actor }, work);
}

/** Tenant isolation through ScopedRepository against real MongoDB (authorization.md §4). */
describe('ScopedRepository (e2e, real MongoDB)', () => {
  let app: INestApplication;
  let repository: ScopeProbeRepository;
  const ids: Record<string, string> = {};

  beforeAll(async () => {
    app = await createDatabaseTestApplication();
    repository = app.get(ScopeProbeRepository);

    // Seed as an explicit SYSTEM actor (never implicit)
    await as(systemActor('scoped-repository e2e seed'), async () => {
      for (const [key, doc] of Object.entries({
        a1: { operatorId: operatorA, code: 'a1' },
        a2: { operatorId: operatorA, code: 'a2' },
        b1: { operatorId: operatorB, code: 'b1' },
        partnerDoc: { operatorId: operatorB, partnerId: partner, code: 'partner-doc' },
        customerDoc: { operatorId: operatorB, customerId: customer, code: 'customer-doc' },
      })) {
        ids[key] = (await repository.insertOne(doc))._id.toHexString();
      }
    });
  });

  afterAll(async () => {
    await app?.get<Connection>(getConnectionToken()).dropDatabase();
    await app?.close();
  });

  afterEach(() => {
    repository.assignedIds = [];
  });

  const codes = (docs: Array<{ code: string }>): string[] => docs.map((d) => d.code).sort();

  it('refuses to run without an actor in the request context', async () => {
    await expect(repository.findMany()).rejects.toThrow('No actor in the request context');
  });

  it('OWN_OPERATOR sees only its operator, and a caller filter cannot widen the scope', async () => {
    const actor = userActor('OWN_OPERATOR', [operatorA]);
    await as(actor, async () => {
      expect(codes(await repository.findMany())).toEqual(['a1', 'a2']);
      expect(await repository.count()).toBe(2);
      expect(await repository.findMany({ operatorId: operatorB })).toEqual([]);
      expect(await repository.findMany({ $or: [{ code: 'b1' }, { code: 'a1' }] })).toHaveLength(1);
    });
  });

  it('returns RESOURCE_NOT_FOUND for another tenant id and for invalid ids', async () => {
    await as(userActor('OWN_OPERATOR', [operatorA]), async () => {
      expect((await repository.getById(ids.a1!)).code).toBe('a1');
      await expect(repository.getById(ids.b1!)).rejects.toMatchObject({
        code: 'RESOURCE_NOT_FOUND',
        status: 404,
      });
      await expect(repository.getById('not-an-object-id')).rejects.toBeInstanceOf(ApiException);
    });
  });

  it('cannot update another tenant record (matches nothing) or rewrite ownership', async () => {
    await as(userActor('OWN_OPERATOR', [operatorA]), async () => {
      const outcome = await repository.updateOne({ _id: ids.b1 }, { $inc: { counter: 5 } });
      expect(outcome).toEqual({ matchedCount: 0, modifiedCount: 0 });
      expect(
        await repository.findOneAndUpdate({ _id: ids.b1 }, { $inc: { counter: 5 } }),
      ).toBeNull();
      await expect(
        repository.updateOne({ _id: ids.a1 }, { $set: { operatorId: operatorB } }),
      ).rejects.toMatchObject({ code: 'PERMISSION_DENIED' });

      const own = await repository.findOneAndUpdate({ _id: ids.a1 }, { $inc: { counter: 1 } });
      expect(own?.counter).toBe(1);
    });
    await as(systemActor('verify'), async () => {
      expect((await repository.getById(ids.b1!)).counter).toBe(0);
    });
  });

  it('inserts only inside the actor scope', async () => {
    await as(userActor('OWN_OPERATOR', [operatorA]), async () => {
      await expect(
        repository.insertOne({ operatorId: operatorB, code: 'intrusion' }),
      ).rejects.toMatchObject({ code: 'PERMISSION_DENIED', status: 403 });
      const created = await repository.insertOne({ operatorId: operatorA, code: 'a3' });
      expect(created.operatorId.equals(operatorA)).toBe(true);
    });
  });

  it('SELECTED_OPERATORS sees exactly the selected operators', async () => {
    await as(userActor('SELECTED_OPERATORS', [operatorB]), async () => {
      expect(codes(await repository.findMany())).toEqual(['b1', 'customer-doc', 'partner-doc']);
    });
  });

  it('OWN_PARTNER and OWN_RECORDS see only their own records', async () => {
    await as(userActor('OWN_PARTNER', [], { partnerId: partner.toHexString() }), async () => {
      expect(codes(await repository.findMany())).toEqual(['partner-doc']);
    });
    await as(userActor('OWN_RECORDS', [], { userId: customer.toHexString() }), async () => {
      expect(codes(await repository.findMany())).toEqual(['customer-doc']);
    });
  });

  it('ASSIGNED_RECORDS sees only assigned records, and nothing by default', async () => {
    const driver = userActor('ASSIGNED_RECORDS');
    await as(driver, async () => {
      expect(await repository.findMany()).toEqual([]);
      repository.assignedIds = [ids.b1!];
      expect(codes(await repository.findMany())).toEqual(['b1']);
    });
  });

  it('ALL and SYSTEM see every record', async () => {
    await as(userActor('ALL'), async () => {
      expect(await repository.count()).toBeGreaterThanOrEqual(5);
    });
  });

  it('takes part in a TransactionRunner transaction and rolls back with it', async () => {
    const runner = app.get(TransactionRunner);
    await as(userActor('OWN_OPERATOR', [operatorA]), async () => {
      await expect(
        runner.run(async (session) => {
          await repository.insertOne({ operatorId: operatorA, code: 'tx-a' }, { session });
          expect(await repository.count({ code: 'tx-a' }, { session })).toBe(1);
          throw new Error('abort');
        }),
      ).rejects.toThrow('abort');
      expect(await repository.count({ code: 'tx-a' })).toBe(0);
    });
  });
});
