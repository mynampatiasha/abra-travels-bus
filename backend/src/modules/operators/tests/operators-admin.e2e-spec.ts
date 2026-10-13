import { Types } from 'mongoose';
import { type Response } from 'supertest';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { CSV_BOM } from '../../catalogue-shared/catalogue_export_manage.service';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';
import { OperatorNotificationHandler } from '../operators_admin_manage.service';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
  email?: string;
}

interface OperatorRow {
  id: string;
  companyName: string;
  displayName: string | null;
  status: string;
  kycStatus: string | null;
  owner: { name: string | null; email: string | null; phone: string | null };
  buses: number;
  trips: number;
  joinedAt: string | null;
}

interface OperatorDetail extends OperatorRow {
  numbers: { buses: number; trips: number; bookings: number; salesPaise: number };
  impact: { upcomingTrips: number; confirmedBookings: number };
  suspension: {
    reason: string;
    proofNote: string | null;
    proofFileIds: string[];
    at: string;
    reactivatedAt: string | null;
  } | null;
}

function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** The admin Operators list and the operator detail page: read, suspend, reactivate, message. */
describe('Operators admin e2e', () => {
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
  });
  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });
  const detail = async (id: string) =>
    dataOf<OperatorDetail>(await call(admin).get(`/admin/operators/${id}`).expect(200));
  const outboxOf = (aggregateId: string) =>
    context.connection.collection('outbox_events').find({ aggregateId }).toArray();
  const auditOf = async (id: string) =>
    dataOf<{ action: string; reason?: string; after: Record<string, unknown> }[]>(
      await call(superAdmin).get(`/audit-logs?entityId=${id}&pageSize=50`).expect(200),
    );

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}op`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    owner = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('the list', () => {
    it('shows each operator with its owner, KYC state and numbers', async () => {
      const rows = dataOf<OperatorRow[]>(
        await call(admin).get('/admin/operators?pageSize=100').expect(200),
      );
      const row = rows.find((candidate) => candidate.id === network.operator.id);
      expect(row).toMatchObject({
        status: 'ACTIVE',
        buses: 1,
        trips: 0,
        kycStatus: null,
        owner: { email: owner.email },
      });
      expect(row?.joinedAt).not.toBeNull();
    });

    it('filters by status and by name', async () => {
      const active = dataOf<OperatorRow[]>(
        await call(admin).get('/admin/operators?status=ACTIVE&pageSize=100').expect(200),
      );
      expect(active.map((entry) => entry.id)).toContain(network.operator.id);
      const suspended = dataOf<OperatorRow[]>(
        await call(admin).get('/admin/operators?status=SUSPENDED&pageSize=100').expect(200),
      );
      expect(suspended.map((entry) => entry.id)).not.toContain(network.operator.id);
      const byName = dataOf<OperatorRow[]>(
        await call(admin).get(`/admin/operators?query=Test%20Operator%20${runId}op`).expect(200),
      );
      expect(byName.map((entry) => entry.id)).toContain(network.operator.id);
    });

    it('is for Abra staff: an operator administrator is refused, support can look', async () => {
      expect((await call(owner).get('/admin/operators')).status).toBe(403);
      expect((await call(owner).get(`/admin/operators/${network.operator.id}`)).status).toBe(403);
      expect((await call(support).get('/admin/operators')).status).toBe(200);
      await client(context).get(`${API}/admin/operators`).expect(401);
    });
  });

  describe('the detail page', () => {
    it('has the numbers and what a suspension would leave running', async () => {
      const operator = await detail(network.operator.id);
      expect(operator.numbers).toEqual({ buses: 1, trips: 0, bookings: 0, salesPaise: 0 });
      expect(operator.impact).toEqual({ upcomingTrips: 0, confirmedBookings: 0 });
      expect(operator.suspension).toBeNull();
    });

    it('answers 404 for an operator that does not exist', async () => {
      await call(admin).get(`/admin/operators/${new Types.ObjectId().toHexString()}`).expect(404);
      expect((await call(admin).get('/admin/operators/not-an-id')).status).toBe(400);
    });
  });

  describe('suspend and reactivate', () => {
    it('needs a reason and the approve permission', async () => {
      const id = network.operator.id;
      expect((await call(admin).post(`/admin/operators/${id}/suspend`, {})).status).toBe(400);
      expect(
        (await call(admin).post(`/admin/operators/${id}/suspend`, { reason: 'no' })).status,
      ).toBe(400);
      for (const caller of [support, owner]) {
        expect(
          (await call(caller).post(`/admin/operators/${id}/suspend`, { reason: 'Not allowed' }))
            .status,
        ).toBe(403);
        expect((await call(caller).post(`/admin/operators/${id}/reactivate`)).status).toBe(403);
        expect(
          (await call(caller).post(`/admin/operators/${id}/messages`, { message: 'Hello' })).status,
        ).toBe(403);
      }
      expect((await detail(id)).status).toBe('ACTIVE');
    });

    it('suspends an active operator, audits it and tells the owner; only once', async () => {
      const id = network.operator.id;
      const proofFile = new Types.ObjectId().toHexString();
      const suspended = dataOf<OperatorDetail>(
        await call(admin)
          .post(`/admin/operators/${id}/suspend`, {
            reason: 'Documents found to be forged',
            proofNote: 'Checked with the RTO on 12 Oct',
            proofFileIds: [proofFile],
          })
          .expect(200),
      );
      expect(suspended.status).toBe('SUSPENDED');
      expect(suspended.suspension).toMatchObject({
        reason: 'Documents found to be forged',
        proofNote: 'Checked with the RTO on 12 Oct',
        proofFileIds: [proofFile],
        reactivatedAt: null,
      });

      const entries = await auditOf(id);
      const entry = entries.find((candidate) => candidate.action === 'operator.suspended');
      expect(entry?.reason).toBe('Documents found to be forged');
      expect((await outboxOf(id)).map((event) => String(event.type))).toContain(
        'operator.suspended',
      );

      const again = await call(admin).post(`/admin/operators/${id}/suspend`, {
        reason: 'A second time',
      });
      expect(again.status).toBe(409);
    });

    it('a suspended operator is not active in the list, and reactivating brings it back', async () => {
      const id = network.operator.id;
      const suspended = dataOf<OperatorRow[]>(
        await call(admin).get('/admin/operators?status=SUSPENDED&pageSize=100').expect(200),
      );
      expect(suspended.map((entry) => entry.id)).toContain(id);

      const reactivated = dataOf<OperatorDetail>(
        await call(admin)
          .post(`/admin/operators/${id}/reactivate`, { note: 'Documents are in order now' })
          .expect(200),
      );
      expect(reactivated.status).toBe('ACTIVE');
      // the last suspension stays on the record, with when it ended
      expect(reactivated.suspension?.reason).toBe('Documents found to be forged');
      expect(reactivated.suspension?.reactivatedAt).not.toBeNull();

      const actions = (await auditOf(id)).map((candidate) => candidate.action);
      expect(actions).toContain('operator.reactivated');
      expect((await outboxOf(id)).map((event) => String(event.type))).toContain(
        'operator.reactivated',
      );

      expect((await call(admin).post(`/admin/operators/${id}/reactivate`)).status).toBe(409);
    });

    it('only an active operator can be suspended', async () => {
      const pending = await context.connection.collection('operators').insertOne({
        companyName: `Pending ${runId}`,
        status: 'PENDING_APPROVAL',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      const refused = await call(admin).post(
        `/admin/operators/${pending.insertedId.toHexString()}/suspend`,
        {
          reason: 'Too early',
        },
      );
      expect(refused.status).toBe(409);
    });
  });

  describe('message the owner', () => {
    it('is audited with its text and sent as an event', async () => {
      const id = network.operator.id;
      const sent = dataOf<{ sent: boolean }>(
        await call(admin)
          .post(`/admin/operators/${id}/messages`, { message: 'Please renew your insurance.' })
          .expect(200),
      );
      expect(sent.sent).toBe(true);
      const entry = (await auditOf(id)).find(
        (candidate) => candidate.action === 'operator.messaged',
      );
      expect(entry?.after).toMatchObject({ message: 'Please renew your insurance.' });
      expect((await outboxOf(id)).map((event) => String(event.type))).toContain(
        'operator.messaged',
      );
    });

    it('the owner is told in the portal and by email and WhatsApp when the event is handled', async () => {
      const id = network.operator.id;
      const ownerId = new Types.ObjectId(owner.tokens.user.id);
      const stored = await context.connection
        .collection('outbox_events')
        .findOne({ aggregateId: id, type: 'operator.messaged' });
      expect(stored).not.toBeNull();
      await context.app.get(OperatorNotificationHandler).handle({
        eventId: String(stored?.eventId),
        type: 'operator.messaged',
        aggregateType: 'operator',
        aggregateId: id,
        payload: stored?.payload as Record<string, unknown>,
        occurredAt: new Date().toISOString(),
      });

      const inbox = await context.connection
        .collection('notifications')
        .find({ userId: ownerId })
        .toArray();
      expect(inbox.map((entry) => String(entry.title))).toContain('Message from Abra Travels');
      expect(inbox.map((entry) => String(entry.body))).toContain('Please renew your insurance.');
      const sent = await context.connection
        .collection('messages')
        .find({ userId: ownerId, eventId: String(stored?.eventId) })
        .toArray();
      expect(sent.map((entry) => String(entry.channel)).sort()).toEqual(['EMAIL', 'WHATSAPP']);
    });

    it('refuses an empty message and an unknown operator', async () => {
      expect(
        (
          await call(admin).post(`/admin/operators/${network.operator.id}/messages`, {
            message: ' ',
          })
        ).status,
      ).toBe(400);
      expect(
        (
          await call(admin).post(
            `/admin/operators/${new Types.ObjectId().toHexString()}/messages`,
            { message: 'Hello there' },
          )
        ).status,
      ).toBe(404);
    });
  });

  describe('export', () => {
    it('is the list as a file with the demo columns, for staff with operators.export', async () => {
      const response = await client(context)
        .get(`${API}/admin/operators/export`)
        .set(...bearer(admin.tokens))
        .buffer(true)
        .parse(binary as never)
        .expect(200);
      const lines = (response.body as Buffer)
        .toString('utf8')
        .replace(CSV_BOM, '')
        .trim()
        .split('\r\n');
      expect(lines[0]).toBe('Operator,Company,Owner,Email,Status,KYC,Buses,Trips,Joined');
      expect(lines.join('\n')).toContain(`Test Operator ${runId}op`);
      expect((await call(support).get('/admin/operators/export')).status).toBe(403);
      expect((await call(owner).get('/admin/operators/export')).status).toBe(403);
    });
  });
});
