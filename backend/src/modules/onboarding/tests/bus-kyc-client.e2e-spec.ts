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
  errorMessageOf,
  type Identified,
  type Network,
  uniqueRegistration,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface BusKycBody {
  busId: string;
  registrationNumber: string;
  submissionId: string;
  status: string;
  hasQuestions: boolean;
  kyc: { answers: Record<string, unknown>; requirements: Array<{ key: string }> } | null;
  problems: string[];
}

interface HistoryBody {
  action: string;
  label: string;
  by: string | null;
}

/** Bus KYC from the client portal (after the company is approved) and the KYC history. */
describe('Bus KYC from the client portal e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let owner: Caller;
  let otherOwner: Caller;

  const call = (caller: Caller) => ({
    get: (path: string) =>
      client(context)
        .get(`${API}${path}`)
        .set(...bearer(caller.tokens)),
    put: (path: string, body: object) =>
      client(context)
        .put(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
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
  const newBus = async (): Promise<string> =>
    dataOf<Identified>(
      await call(owner)
        .post('/catalogue/buses', {
          registrationNumber: uniqueRegistration(),
          name: 'Owner bus',
          busTypeId: network.busType.id,
          seatCapacity: 30,
        })
        .expect(201),
    ).id;
  const setOperatorStatus = (status: string) =>
    context.connection
      .collection('operators')
      .updateOne({ _id: new Types.ObjectId(network.operator.id) }, { $set: { status } });
  const configureBusQuestions = async () => {
    const current = dataOf<{ version: number }>(
      await call(superAdmin).get('/settings/kyc-configuration').expect(200),
    );
    await call(superAdmin)
      .put('/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: current.version,
        reason: 'Bus questions',
        questions: [
          {
            key: 'interstate',
            label: 'Does this bus run between states?',
            help: '',
            appliesTo: 'BUS',
            type: 'BOOLEAN',
            options: [],
            required: true,
            active: true,
            sortOrder: 1,
          },
        ],
        rules: [
          {
            key: 'bus_rc',
            name: 'RC for every bus',
            appliesTo: 'BUS',
            documentKey: 'BUS_RC',
            required: true,
            active: true,
            match: 'ALL',
            conditions: [],
          },
          {
            key: 'bus_permit',
            name: 'Permit for interstate buses',
            appliesTo: 'BUS',
            documentKey: 'BUS_PERMIT',
            required: true,
            active: true,
            match: 'ALL',
            conditions: [{ questionKey: 'interstate', values: ['true'] }],
          },
        ],
      })
      .expect(200);
  };

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    await context.connection.collection('onboarding_submissions').deleteMany({});
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}bk`);
    owner = await signIn('OPERATOR_ADMIN', network.operator.id);
    const other = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Other ${runId} Private Limited`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${other.id}/status`, { status: 'ACTIVE', reason: 'Documents verified' })
      .expect(201);
    otherOwner = await signIn('OPERATOR_ADMIN', other.id);
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('onboarding_submissions').deleteMany({});
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('waits for the company: a company that is not approved cannot start bus KYC', async () => {
    const busId = await newBus();
    await setOperatorStatus('SUSPENDED');
    try {
      const refused = await call(owner).get(`/client/kyc/buses/${busId}`);
      expect(refused.status).toBe(409);
      expect(errorMessageOf(refused)).toMatch(/must be approved/);
      const viaFile = await call(owner).post('/onboarding/submissions', { busId });
      expect(viaFile.status).toBe(409);
    } finally {
      await setOperatorStatus('ACTIVE');
    }
  });

  it('without bus questions the bus file asks for the bus documents directly', async () => {
    const busId = await newBus();
    const view = dataOf<BusKycBody>(
      await call(owner).get(`/client/kyc/buses/${busId}`).expect(200),
    );
    expect(view).toMatchObject({ busId, status: 'DRAFT', hasQuestions: false, kyc: null });
    await call(owner).put(`/client/kyc/buses/${busId}`, { answers: {} }).expect(409);
  });

  it('with bus questions the answers decide the documents, and history records the steps', async () => {
    await configureBusQuestions();
    const busId = await newBus();
    const first = dataOf<BusKycBody>(
      await call(owner).get(`/client/kyc/buses/${busId}`).expect(200),
    );
    expect(first.hasQuestions).toBe(true);
    expect(first.problems.join(' ')).toMatch(/Answer/);

    await call(owner).put(`/client/kyc/buses/${busId}`, { answers: {} }).expect(400);
    const answered = dataOf<BusKycBody>(
      await call(owner)
        .put(`/client/kyc/buses/${busId}`, { answers: { interstate: 'true' } })
        .expect(200),
    );
    expect(answered.kyc?.requirements.map((type) => type.key).sort()).toEqual([
      'BUS_PERMIT',
      'BUS_RC',
    ]);
    const local = dataOf<BusKycBody>(
      await call(owner)
        .put(`/client/kyc/buses/${busId}`, { answers: { interstate: 'false' } })
        .expect(200),
    );
    expect(local.kyc?.requirements.map((type) => type.key)).toEqual(['BUS_RC']);

    const history = dataOf<HistoryBody[]>(
      await call(owner).get(`/onboarding/submissions/${first.submissionId}/history`).expect(200),
    );
    expect(history.map((entry) => entry.label)).toEqual(['Started']);
    // Abra staff read any file's history; another operator does not see it
    await call(superAdmin).get(`/onboarding/submissions/${first.submissionId}/history`).expect(200);
    await call(otherOwner).get(`/onboarding/submissions/${first.submissionId}/history`).expect(404);
  });

  it('keeps the answers after a rejection: only rejected documents can change', async () => {
    const busId = await newBus();
    const view = dataOf<BusKycBody>(
      await call(owner).get(`/client/kyc/buses/${busId}`).expect(200),
    );
    await call(owner)
      .put(`/client/kyc/buses/${busId}`, { answers: { interstate: 'false' } })
      .expect(200);
    await context.connection
      .collection('onboarding_submissions')
      .updateOne({ _id: new Types.ObjectId(view.submissionId) }, { $set: { status: 'REJECTED' } });
    const changed = await call(owner).put(`/client/kyc/buses/${busId}`, {
      answers: { interstate: 'true' },
    });
    expect(changed.status).toBe(409);
    expect(errorMessageOf(changed)).toMatch(/Keep your answers/);
  });

  it('is for the bus owner: another operator and Abra staff are refused', async () => {
    const busId = await newBus();
    await call(otherOwner).get(`/client/kyc/buses/${busId}`).expect(404);
    await call(superAdmin).get(`/client/kyc/buses/${busId}`).expect(403);
  });
});
