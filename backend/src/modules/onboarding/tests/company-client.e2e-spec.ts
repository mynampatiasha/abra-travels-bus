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

interface Company {
  id: string;
  companyName: string;
  ownerName: string;
  email: string;
  supportPhone: string;
  city: string;
  gstin: string;
  payoutMode: string;
  bank: {
    holderName: string;
    accountLast4: string;
    ifsc: string;
    status: string;
    note: string | null;
  } | null;
}

const PROFILE = {
  companyName: 'Kaveri Express',
  ownerName: 'Ravi Kumar',
  email: 'Ravi@Kaveri.example',
  supportPhone: '+91 9876543210',
  city: 'Hyderabad',
  gstin: '36abcde1234f1z5',
};
const BANK = {
  holderName: 'Kaveri Express Pvt Ltd',
  accountNumber: '123456789012',
  ifsc: 'hdfc0001234',
};

/** The Company profile page of the client portal (Phase 1 step 8). */
describe('Company profile (client portal) e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
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
  const operators = () => context.connection.collection('operators');
  const stored = () =>
    operators().findOne<{ bank: { accountNumberEncrypted: string; verifiedAt?: Date } }>({
      _id: new Types.ObjectId(network.operator.id),
    });
  const auditOf = async (id: string) =>
    dataOf<{ action: string; after: Record<string, unknown> }[]>(
      await call(superAdmin).get(`/audit-logs?entityId=${id}&pageSize=50`).expect(200),
    );

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}co`);
    admin = await signIn('ADMIN');
    owner = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('shows the company with the owner account as the starting contact, and no bank', async () => {
    const company = dataOf<Company>(await call(owner).get('/client/company').expect(200));
    expect(company).toMatchObject({
      id: network.operator.id,
      payoutMode: 'MANUAL',
      bank: null,
      email: owner.email,
    });
  });

  it('is for the operator’s own staff: Abra staff and strangers are refused', async () => {
    expect((await call(admin).get('/client/company')).status).toBe(403);
    expect((await call(admin).put('/client/company', PROFILE)).status).toBe(403);
    await client(context).get(`${API}/client/company`).expect(401);
  });

  describe('the profile', () => {
    it('is checked before it is saved', async () => {
      for (const bad of [
        { ...PROFILE, companyName: '' },
        { ...PROFILE, email: 'not-an-email' },
        { ...PROFILE, gstin: '123' },
      ]) {
        expect((await call(owner).put('/client/company', bad)).status).toBe(400);
      }
    });

    it('saves, tidies the email and GSTIN, and is audited', async () => {
      const saved = dataOf<Company>(await call(owner).put('/client/company', PROFILE).expect(200));
      expect(saved).toMatchObject({
        companyName: 'Kaveri Express',
        ownerName: 'Ravi Kumar',
        email: 'ravi@kaveri.example',
        supportPhone: '+91 9876543210',
        city: 'Hyderabad',
        gstin: '36ABCDE1234F1Z5',
      });
      expect(dataOf<Company>(await call(owner).get('/client/company').expect(200))).toMatchObject({
        companyName: 'Kaveri Express',
        city: 'Hyderabad',
      });
      expect((await auditOf(network.operator.id)).map((entry) => entry.action)).toContain(
        'operator.profile-updated',
      );
    });

    it('lets the optional details be cleared', async () => {
      const saved = dataOf<Company>(
        await call(owner)
          .put('/client/company', { ...PROFILE, supportPhone: '', city: '', gstin: '' })
          .expect(200),
      );
      expect(saved).toMatchObject({ supportPhone: '', city: '', gstin: '' });
    });
  });

  describe('the bank account', () => {
    it('is checked before it is saved', async () => {
      for (const bad of [
        { ...BANK, accountNumber: '12ab' },
        { ...BANK, accountNumber: '1'.repeat(19) },
        { ...BANK, ifsc: 'WRONG' },
        { ...BANK, holderName: '' },
      ]) {
        expect((await call(owner).put('/client/company/bank', bad)).status).toBe(400);
      }
    });

    it('is stored encrypted, shown by its last four digits, pending, and Abra is told', async () => {
      const saved = dataOf<Company>(
        await call(owner).put('/client/company/bank', BANK).expect(200),
      );
      expect(saved.bank).toEqual({
        holderName: 'Kaveri Express Pvt Ltd',
        accountLast4: '9012',
        ifsc: 'HDFC0001234',
        status: 'PENDING',
        note: null,
      });
      expect(JSON.stringify(saved)).not.toContain('123456789012');
      const row = await stored();
      expect(row?.bank.accountNumberEncrypted).toMatch(/^v1\./);
      expect(JSON.stringify(row)).not.toContain('123456789012');
      const audit = await auditOf(network.operator.id);
      expect(audit.map((entry) => entry.action)).toContain('operator.bank-changed');
      expect(JSON.stringify(audit)).not.toContain('123456789012');
      const events = await context.connection
        .collection('outbox_events')
        .find({ aggregateId: network.operator.id, type: 'operator.bank-changed' })
        .toArray();
      expect(events).toHaveLength(1);
    });

    it('goes back to pending, and payouts to manual, when the account is replaced', async () => {
      const id = network.operator.id;
      await call(admin)
        .post(`/admin/operators/${id}/bank/verify`, { outcome: 'VERIFIED', note: 'Checked' })
        .expect(200);
      await call(admin)
        .put(`/admin/operators/${id}/payout-mode`, { mode: 'AUTO_SPLIT' })
        .expect(200);
      const replaced = dataOf<Company>(
        await call(owner)
          .put('/client/company/bank', { ...BANK, accountNumber: '998877665544' })
          .expect(200),
      );
      expect(replaced.payoutMode).toBe('MANUAL');
      expect(replaced.bank).toMatchObject({ accountLast4: '5544', status: 'PENDING' });
      const row = await stored();
      expect(row?.bank.verifiedAt).toBeUndefined();
    });

    it('shows the owner why Abra could not verify it', async () => {
      const id = network.operator.id;
      await call(admin)
        .post(`/admin/operators/${id}/bank/verify`, {
          outcome: 'FAILED',
          note: 'Holder name does not match',
        })
        .expect(200);
      const company = dataOf<Company>(await call(owner).get('/client/company').expect(200));
      expect(company.bank).toMatchObject({
        status: 'FAILED',
        note: 'Holder name does not match',
      });
    });
  });
});
