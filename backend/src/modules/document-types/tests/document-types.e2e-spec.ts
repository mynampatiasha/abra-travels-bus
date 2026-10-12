import {
  type AuthTestContext,
  client,
  createAuthTestApp,
} from '../../authentication/tests/auth-e2e.harness';
import { type CatalogueApi, CATALOGUE, signInAs } from '../../trips/tests/catalogue-e2e.support';
import { STARTER_DOCUMENT_TYPES } from '../services/document-type-seeder.service';

interface DocumentTypeBody {
  id: string;
  key: string;
  appliesTo: string;
  isActive: boolean;
  requiresExpiry: boolean;
  maxFiles: number;
}

const PATH = '/document-types';

interface ListBody {
  data: DocumentTypeBody[];
}

/** Document types managed by platform staff and read by operators — real app, MongoDB, Redis. */
describe('Document types e2e', () => {
  let context: AuthTestContext;
  let admin: CatalogueApi;
  let operator: CatalogueApi;
  let support: CatalogueApi;

  beforeAll(async () => {
    context = await createAuthTestApp();
    await context.connection.collection('document_types').deleteMany({});
    admin = await signInAs(context, 'ADMIN');
    operator = await signInAs(context, 'OPERATOR_ADMIN', '64b000000000000000000001');
    support = await signInAs(context, 'SUPPORT');
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('document_types').deleteMany({});
    await context.close();
  }, 60_000);

  const keys = (response: { body: unknown }) =>
    (response.body as ListBody).data.map((item) => item.key);

  it('is closed without a token', async () => {
    await client(context).get(`${CATALOGUE}${PATH}`).expect(401);
    await client(context).post(`${CATALOGUE}${PATH}`).send({}).expect(401);
  });

  it('only platform administrators may change the list', async () => {
    const body = { key: 'X_TEST', appliesTo: 'BUS', name: 'Test' };
    await operator.post(PATH, body).expect(403);
    await support.post(PATH, body).expect(403);
  });

  it('adds a type, with defaults, and refuses a repeated key', async () => {
    const created = await admin.create<DocumentTypeBody>(PATH, {
      key: 'DRIVER_LICENCE',
      appliesTo: 'BUS',
      name: 'Driver licence',
      requiresExpiry: true,
      maxFiles: 2,
      instructions: 'Licence of the regular driver.',
    });
    expect(created).toMatchObject({
      key: 'DRIVER_LICENCE',
      appliesTo: 'BUS',
      isActive: true,
      requiresExpiry: true,
      maxFiles: 2,
    });
    await admin.post(PATH, { key: 'DRIVER_LICENCE', appliesTo: 'BUS', name: 'Again' }).expect(409);
  });

  it('refuses invalid input', async () => {
    await admin.post(PATH, { key: 'lower', appliesTo: 'BUS', name: 'Bad key' }).expect(400);
    await admin.post(PATH, { key: 'BAD_SUBJECT', appliesTo: 'DRIVER', name: 'Bad' }).expect(400);
    await admin
      .post(PATH, {
        key: 'BAD_FILE',
        appliesTo: 'BUS',
        name: 'Bad',
        allowedMimeTypes: ['text/html'],
      })
      .expect(400);
    await admin
      .post(PATH, { key: 'BAD_SIZE', appliesTo: 'BUS', name: 'Bad', maxFileSizeMb: 500 })
      .expect(400);
  });

  it('edits a type but never its key or subject', async () => {
    const created = await admin.create<DocumentTypeBody>(PATH, {
      key: 'EDIT_ME',
      appliesTo: 'OPERATOR',
      name: 'Edit me',
    });
    // The key and what the type applies to are permanent: asking to change them is refused.
    await admin.put(`${PATH}/${created.id}`, { name: 'Edited', key: 'NEW' }).expect(400);
    await admin.put(`${PATH}/${created.id}`, { name: 'Edited', appliesTo: 'BUS' }).expect(400);
    const response = await admin
      .put(`${PATH}/${created.id}`, { name: 'Edited', maxFiles: 3 })
      .expect(200);
    expect((response.body as { data: DocumentTypeBody }).data).toMatchObject({
      key: 'EDIT_ME',
      appliesTo: 'OPERATOR',
      name: 'Edited',
      maxFiles: 3,
    });
    await admin.put(`${PATH}/${created.id}`, {}).expect(400);
  });

  it('disabled types leave the operator checklist but stay visible to staff', async () => {
    const created = await admin.create<DocumentTypeBody>(PATH, {
      key: 'TO_DISABLE',
      appliesTo: 'BUS',
      name: 'To disable',
    });
    await admin.post(`${PATH}/${created.id}/active`, { active: false }).expect(201);

    const forOperator = await operator.get(PATH).expect(200);
    expect(keys(forOperator)).not.toContain('TO_DISABLE');
    expect(keys(forOperator)).toContain('DRIVER_LICENCE');

    const forStaff = await admin.get(`${PATH}?active=false`).expect(200);
    expect(keys(forStaff)).toContain('TO_DISABLE');
  });

  it('an operator sees only active types even when asking for inactive ones', async () => {
    const response = await operator.get(`${PATH}?active=false`).expect(200);
    const items = (response.body as ListBody).data;
    expect(items.every((item) => item.isActive)).toBe(true);
  });

  it('filters by what the document applies to', async () => {
    const response = await admin.get(`${PATH}?appliesTo=OPERATOR`).expect(200);
    const items = (response.body as ListBody).data;
    expect(items.length).toBeGreaterThan(0);
    expect(items.every((item) => item.appliesTo === 'OPERATOR')).toBe(true);
  });

  it('writes an audit entry for each change', async () => {
    const entries = await context.connection
      .collection('audit_logs')
      .countDocuments({ entityType: 'document_type' });
    expect(entries).toBeGreaterThanOrEqual(4);
  });

  it('starter list covers the operator and bus documents with unique keys', () => {
    const starterKeys = STARTER_DOCUMENT_TYPES.map((item) => item.key);
    expect(new Set(starterKeys).size).toBe(starterKeys.length);
    expect(STARTER_DOCUMENT_TYPES.some((item) => item.appliesTo === 'OPERATOR')).toBe(true);
    expect(STARTER_DOCUMENT_TYPES.some((item) => item.appliesTo === 'BUS')).toBe(true);
    for (const item of STARTER_DOCUMENT_TYPES) {
      expect(item.allowedMimeTypes.length).toBeGreaterThan(0);
    }
  });
});
