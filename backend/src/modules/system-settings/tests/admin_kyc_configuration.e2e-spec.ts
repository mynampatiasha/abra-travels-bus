import { Types } from 'mongoose';
import {
  createAuthTestApp,
  client,
  bearer,
  dataOf,
  type AuthTestContext,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type KycConfiguration } from '../admin_kyc_configuration';

const PATH = '/api/v1/settings/kyc-configuration';
type SignedIn = Awaited<ReturnType<typeof seedAndSignIn>>;

describe('Admin KYC configuration HTTP / MongoDB integration', () => {
  let context: AuthTestContext;
  let admin: SignedIn;
  let operator: SignedIn;
  let customer: SignedIn;
  let documentKey: string;
  beforeAll(async () => {
    context = await createAuthTestApp();
    admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    operator = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: new Types.ObjectId(),
    });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    const first = await context.connection
      .collection<{ key: string }>('document_types')
      .findOne({ appliesTo: 'OPERATOR', isActive: true });
    if (!first) throw new Error('The document type seeder did not create company documents');
    documentKey = first.key;
  }, 90_000);
  beforeEach(async () => {
    await context.connection.collection('kyc_configuration').deleteMany({});
  });
  afterAll(async () => {
    if (context) await context.close();
  }, 60_000);
  const api = () => client(context);
  const read = async () =>
    dataOf<{ version: number; questions: unknown[]; rules: unknown[] }>(
      await api()
        .get(PATH)
        .set(...bearer(admin.tokens))
        .expect(200),
    );
  const config = (): KycConfiguration => ({
    schemaVersion: 1,
    questions: [
      {
        key: 'company_type',
        label: 'Company or individual?',
        help: '',
        appliesTo: 'OPERATOR',
        type: 'SINGLE_CHOICE',
        options: [
          { value: 'company', label: 'Company' },
          { value: 'individual', label: 'Individual' },
        ],
        required: true,
        active: true,
        sortOrder: 0,
      },
    ],
    rules: [
      {
        key: 'company_document',
        name: 'Company registration',
        appliesTo: 'OPERATOR',
        documentKey,
        required: true,
        active: true,
        match: 'ALL',
        conditions: [{ questionKey: 'company_type', values: ['company'] }],
      },
    ],
  });
  const save = (body: object) =>
    api()
      .put(PATH)
      .set(...bearer(admin.tokens))
      .send(body);

  it('requires authentication and refuses customers and operator staff', async () => {
    await api().get(PATH).expect(401);
    await api()
      .get(PATH)
      .set(...bearer(customer.tokens))
      .expect(403);
    // Operators can read document types, but cannot read platform configuration.
    await api()
      .get(PATH)
      .set(...bearer(operator.tokens))
      .expect(403);
    await api()
      .put(PATH)
      .set(...bearer(operator.tokens))
      .send({ ...config(), expectedVersion: 0, reason: 'Try to change admin configuration' })
      .expect(403);
  });
  it('creates the first configuration, persists it and audits the same version', async () => {
    expect((await read()).version).toBe(0);
    const view = dataOf<{ version: number }>(
      await save({ ...config(), expectedVersion: 0, reason: 'Initial KYC configuration' }).expect(
        200,
      ),
    );
    expect(view.version).toBe(1);
    expect(await read()).toMatchObject({
      version: 1,
      questions: config().questions,
      rules: config().rules,
    });
    const audit = await context.connection
      .collection('audit_logs')
      .findOne({ entityType: 'kyc_configuration', reason: 'Initial KYC configuration' });
    expect(audit?.after).toMatchObject({ version: 1 });
  });
  it('evaluates the checklist from answers on the backend', async () => {
    await save({ ...config(), expectedVersion: 0, reason: 'Configure test questions' }).expect(200);
    const preview = async (answer: string) =>
      dataOf<{ documents: { key: string; isRequired: boolean }[] }>(
        await api()
          .post(`${PATH}/preview`)
          .set(...bearer(admin.tokens))
          .send({ appliesTo: 'OPERATOR', answers: { company_type: answer } })
          .expect(200),
      );
    expect((await preview('individual')).documents).toHaveLength(0);
    expect((await preview('company')).documents).toEqual([
      expect.objectContaining({ key: documentKey, isRequired: true }),
    ]);
    await api()
      .post(`${PATH}/preview`)
      .set(...bearer(admin.tokens))
      .send({ appliesTo: 'OPERATOR', answers: { company_type: 'injected' } })
      .expect(400);
  });
  it('rejects invalid imports without changing the saved configuration', async () => {
    await save({ ...config(), expectedVersion: 0, reason: 'Configure test questions' }).expect(200);
    const invalid = {
      ...config(),
      questions: [],
      expectedVersion: 1,
      reason: 'Try dangling rule import',
    };
    await api()
      .post(`${PATH}/validate-import`)
      .set(...bearer(admin.tokens))
      .send(invalid)
      .expect(400);
    await save(invalid).expect(400);
    expect((await read()).version).toBe(1);
    expect((await read()).questions).toHaveLength(1);
  });
  it('allows exactly one simultaneous edit of the same version', async () => {
    await save({ ...config(), expectedVersion: 0, reason: 'Configure concurrency test' }).expect(
      200,
    );
    const results = await Promise.all([
      save({ ...config(), expectedVersion: 1, reason: 'Concurrent admin edit A' }),
      save({ ...config(), expectedVersion: 1, reason: 'Concurrent admin edit B' }),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    expect((await read()).version).toBe(2);
  });
  it('supports atomic replacement and deletion of configuration entries', async () => {
    await save({ ...config(), expectedVersion: 0, reason: 'Configure delete test' }).expect(200);
    await save({
      schemaVersion: 1,
      questions: [],
      rules: [],
      expectedVersion: 1,
      reason: 'Remove questions and rules',
    }).expect(200);
    expect(await read()).toMatchObject({ version: 2, questions: [], rules: [] });
  });
});
