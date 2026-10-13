import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
  email?: string;
}

interface OperatorDetail {
  id: string;
  status: string;
  payout: {
    mode: string;
    bank: {
      holderName: string;
      accountLast4: string;
      ifsc: string;
      status: string;
      method: string | null;
      note: string | null;
    } | null;
  };
}

/** Payout mode and bank verification on the operator detail page (Phase 1 step 7). */
describe('Operators payout e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
  let support: Caller;
  let owner: Caller;
  let superAdmin: Caller;

  const call = (caller: Caller) => ({
    get: (path: string) =>
      client(context)
        .get(`${API}${path}`)
        .set(...bearer(caller.tokens)),
    post: (path: string, body: object = {}) =>
      client(context)
        .post(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    put: (path: string, body: object = {}) =>
      client(context)
        .put(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
  });
  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });
  const detail = async (id: string) =>
    dataOf<OperatorDetail>(await call(admin).get(`/admin/operators/${id}`).expect(200));
  const outboxOf = (aggregateId: string) =>
    context.connection
      .collection<{ type: string; payload: Record<string, unknown> }>('outbox_events')
      .find({ aggregateId })
      .toArray();
  const auditOf = async (id: string) =>
    dataOf<{ action: string; reason?: string; after: Record<string, unknown> }[]>(
      await call(superAdmin).get(`/audit-logs?entityId=${id}&pageSize=50`).expect(200),
    );

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}pay`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    owner = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('payout mode and bank verification', () => {
    const bankOf = (accountNumber: string) => ({
      holderName: 'Test Operator Pvt Ltd',
      accountNumberEncrypted: `v1.not.a.real.${accountNumber}`,
      accountLast4: accountNumber.slice(-4),
      ifsc: 'HDFC0001234',
      status: 'PENDING',
      addedAt: new Date(),
    });
    const operators = () => context.connection.collection('operators');
    const reset = (bank?: object, payoutMode = 'MANUAL') =>
      operators().updateOne(
        { _id: new Types.ObjectId(network.operator.id) },
        bank ? { $set: { bank, payoutMode } } : { $unset: { bank: '' }, $set: { payoutMode } },
      );

    it('starts manual with no bank account, and never shows the full number', async () => {
      await reset();
      const before = await detail(network.operator.id);
      expect(before.payout).toEqual({ mode: 'MANUAL', bank: null });
      await reset(bankOf('123456789012'));
      const after = await detail(network.operator.id);
      expect(after.payout.bank).toMatchObject({ accountLast4: '9012', status: 'PENDING' });
      expect(JSON.stringify(after)).not.toContain('123456789012');
      expect(JSON.stringify(after)).not.toContain('accountNumberEncrypted');
    });

    it('refuses automatic payouts until the bank account is verified', async () => {
      const id = network.operator.id;
      await reset(bankOf('123456789012'));
      expect(
        (await call(admin).put(`/admin/operators/${id}/payout-mode`, { mode: 'AUTO_SPLIT' }))
          .status,
      ).toBe(409);
      expect(
        (await call(admin).put(`/admin/operators/${id}/payout-mode`, { mode: 'WRONG' })).status,
      ).toBe(400);
      expect((await detail(id)).payout.mode).toBe('MANUAL');
    });

    it('verifies the account with a note, audits it and tells the owner; only once', async () => {
      const id = network.operator.id;
      await reset(bankOf('123456789012'));
      expect(
        (await call(admin).post(`/admin/operators/${id}/bank/verify`, { outcome: 'VERIFIED' }))
          .status,
      ).toBe(400);
      const verified = dataOf<OperatorDetail>(
        await call(admin)
          .post(`/admin/operators/${id}/bank/verify`, {
            outcome: 'VERIFIED',
            note: 'Name matches the cancelled cheque',
          })
          .expect(200),
      );
      expect(verified.payout.bank).toMatchObject({
        status: 'VERIFIED',
        method: 'MANUAL',
        note: 'Name matches the cancelled cheque',
      });
      expect(
        (
          await call(admin).post(`/admin/operators/${id}/bank/verify`, {
            outcome: 'FAILED',
            note: 'Second try',
          })
        ).status,
      ).toBe(409);
      const audit = await auditOf(id);
      expect(audit.map((entry) => entry.action)).toContain('operator.bank-verified');
      expect((await outboxOf(id)).map((event) => event.type)).toContain('operator.bank-verified');
    });

    it('then lets payouts be automatic, and back to manual, each audited', async () => {
      const id = network.operator.id;
      const auto = dataOf<OperatorDetail>(
        await call(admin)
          .put(`/admin/operators/${id}/payout-mode`, { mode: 'AUTO_SPLIT' })
          .expect(200),
      );
      expect(auto.payout.mode).toBe('AUTO_SPLIT');
      const manual = dataOf<OperatorDetail>(
        await call(admin).put(`/admin/operators/${id}/payout-mode`, { mode: 'MANUAL' }).expect(200),
      );
      expect(manual.payout.mode).toBe('MANUAL');
      const changes = (await auditOf(id)).filter(
        (entry) => entry.action === 'operator.payout-mode-changed',
      );
      expect(changes).toHaveLength(2);
    });

    it('a failed check tells the owner why and returns an automatic operator to manual', async () => {
      const id = network.operator.id;
      await reset({ ...bankOf('123456789012'), status: 'PENDING' });
      await operators().updateOne(
        { _id: new Types.ObjectId(id) },
        { $set: { 'bank.status': 'VERIFIED', payoutMode: 'AUTO_SPLIT' } },
      );
      // a verified account cannot be failed; it is changed by the owner (step 8) first
      expect(
        (
          await call(admin).post(`/admin/operators/${id}/bank/verify`, {
            outcome: 'FAILED',
            note: 'Late',
          })
        ).status,
      ).toBe(409);
      await operators().updateOne(
        { _id: new Types.ObjectId(id) },
        { $set: { 'bank.status': 'PENDING' } },
      );
      const failed = dataOf<OperatorDetail>(
        await call(admin)
          .post(`/admin/operators/${id}/bank/verify`, {
            outcome: 'FAILED',
            note: 'Account holder name does not match',
          })
          .expect(200),
      );
      expect(failed.payout).toMatchObject({
        mode: 'MANUAL',
        bank: { status: 'FAILED', note: 'Account holder name does not match' },
      });
      const event = (await outboxOf(id)).find((entry) => entry.type === 'operator.bank-failed');
      expect(event?.payload).toMatchObject({ reason: 'Account holder name does not match' });
    });

    it('cannot verify when no account was added, and is for approvers only', async () => {
      const id = network.operator.id;
      await reset();
      expect(
        (
          await call(admin).post(`/admin/operators/${id}/bank/verify`, {
            outcome: 'VERIFIED',
            note: 'Looks fine',
          })
        ).status,
      ).toBe(409);
      for (const caller of [support, owner]) {
        expect(
          (await call(caller).put(`/admin/operators/${id}/payout-mode`, { mode: 'MANUAL' })).status,
        ).toBe(403);
        expect(
          (
            await call(caller).post(`/admin/operators/${id}/bank/verify`, {
              outcome: 'VERIFIED',
              note: 'Fine',
            })
          ).status,
        ).toBe(403);
      }
    });
  });
});
