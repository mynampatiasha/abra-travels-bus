import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { type CatalogueApi, signInAs } from '../../trips/tests/catalogue-e2e.support';

interface Identified {
  id: string;
}

interface FileBody extends Identified {
  operatorId: string;
  documentTypeId: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
}

const PDF = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(2000, 'a')]);
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(500, 1),
]);

/** Uploading and downloading documents — real app, MongoDB, Redis and a temporary folder. */
describe('Files e2e', () => {
  let context: AuthTestContext;
  let storageRoot: string;
  let admin: CatalogueApi;
  let operatorA: { tokens: Tokens };
  let operatorB: { tokens: Tokens };
  let support: { tokens: Tokens };
  let platformStaff: { tokens: Tokens };
  let operatorAId: string;
  let operatorBId: string;
  let companyDoc: Identified;
  let photoDoc: Identified;
  let smallDoc: Identified;
  let disabledDoc: Identified;

  const upload = (
    who: { tokens: Tokens },
    fields: Record<string, string>,
    file?: { content: Buffer; name: string; type?: string },
  ) => {
    const request = client(context)
      .post('/api/v1/files')
      .set(...bearer(who.tokens));
    for (const [name, value] of Object.entries(fields)) request.field(name, value);
    if (file) {
      request.attach('file', file.content, {
        filename: file.name,
        contentType: file.type ?? 'application/octet-stream',
      });
    }
    return request;
  };

  const get = (who: { tokens: Tokens }, path: string) =>
    client(context)
      .get(`/api/v1/files${path}`)
      .set(...bearer(who.tokens));

  const user = (roleKey: SystemRoleKey, operatorId?: string) =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });

  beforeAll(async () => {
    storageRoot = await mkdtemp(join(tmpdir(), 'abra-files-e2e-'));
    process.env.STORAGE_LOCAL_ROOT = storageRoot;
    context = await createAuthTestApp();
    admin = await signInAs(context, 'ADMIN');

    const operator = async (name: string): Promise<string> =>
      (
        await admin.create<Identified>('/operators', {
          companyName: `${name} ${Date.now()} Private Limited`,
          displayName: `${name} ${Date.now()}`,
        })
      ).id;
    operatorAId = await operator('Files A');
    operatorBId = await operator('Files B');

    const documentType = (key: string, body: object) =>
      admin.create<Identified>('/document-types', {
        key: `${key}_${Date.now()}`,
        name: key,
        ...body,
      });
    companyDoc = await documentType('F_COMPANY', {
      appliesTo: 'OPERATOR',
      allowedMimeTypes: ['application/pdf', 'image/png'],
    });
    photoDoc = await documentType('F_PHOTOS', {
      appliesTo: 'BUS',
      allowedMimeTypes: ['image/jpeg', 'image/png'],
    });
    smallDoc = await documentType('F_SMALL', {
      appliesTo: 'OPERATOR',
      allowedMimeTypes: ['application/pdf'],
      maxFileSizeMb: 1,
    });
    disabledDoc = await documentType('F_DISABLED', { appliesTo: 'OPERATOR' });
    await admin.post(`/document-types/${disabledDoc.id}/active`, { active: false }).expect(201);

    operatorA = await user('OPERATOR_ADMIN', operatorAId);
    operatorB = await user('OPERATOR_ADMIN', operatorBId);
    support = await user('SUPPORT');
    platformStaff = await user('ADMIN');
  }, 180_000);

  afterAll(async () => {
    await context.close();
    await rm(storageRoot, { recursive: true, force: true });
    delete process.env.STORAGE_LOCAL_ROOT;
  }, 60_000);

  it('is closed without a token', async () => {
    await client(context).post('/api/v1/files').expect(401);
    await client(context).get(`/api/v1/files/${new Types.ObjectId().toHexString()}`).expect(401);
  });

  it('an operator uploads a document and gets it back byte for byte', async () => {
    const response = await upload(
      operatorA,
      { documentTypeId: companyDoc.id },
      { content: PDF, name: 'GST certificate.pdf', type: 'application/pdf' },
    ).expect(201);
    const file = dataOf<FileBody>(response);
    expect(file).toMatchObject({
      operatorId: operatorAId,
      documentTypeId: companyDoc.id,
      originalName: 'GST certificate.pdf',
      mimeType: 'application/pdf',
      sizeBytes: PDF.length,
    });
    // where the bytes live is never sent to clients
    expect(JSON.stringify(response.body)).not.toMatch(/storageKey|sha256|abra-files/);

    const described = await get(operatorA, `/${file.id}`).expect(200);
    expect(dataOf<FileBody>(described).id).toBe(file.id);

    const content = await get(operatorA, `/${file.id}/content`)
      .buffer(true)
      .parse((res, done) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => done(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect((content.body as Buffer).equals(PDF)).toBe(true);
    expect(content.headers['content-type']).toContain('application/pdf');
    expect(content.headers['cache-control']).toBe('private, no-store');
    expect(content.headers['x-content-type-options']).toBe('nosniff');
    expect(content.headers['content-disposition']).toContain('attachment');
  });

  it('platform staff upload for an operator only when they say which one', async () => {
    const file = { content: PNG, name: 'owner-id.png', type: 'image/png' };
    await upload(platformStaff, { documentTypeId: companyDoc.id }, file).expect(400);
    const response = await upload(
      platformStaff,
      { documentTypeId: companyDoc.id, operatorId: operatorBId },
      file,
    ).expect(201);
    expect(dataOf<FileBody>(response).operatorId).toBe(operatorBId);
  });

  describe('the file is checked against the document type', () => {
    it('refuses a missing or empty file', async () => {
      await upload(operatorA, { documentTypeId: companyDoc.id }).expect(400);
      await upload(
        operatorA,
        { documentTypeId: companyDoc.id },
        { content: Buffer.alloc(0), name: 'empty.pdf', type: 'application/pdf' },
      ).expect(400);
    });

    it('trusts the real file, not its name or declared type', async () => {
      await upload(
        operatorA,
        { documentTypeId: companyDoc.id },
        {
          content: Buffer.from('<html><script>alert(1)</script></html>'),
          name: 'rc.pdf',
          type: 'application/pdf',
        },
      ).expect(415);
    });

    it('refuses a real file of a type this document does not accept', async () => {
      await upload(
        operatorA,
        { documentTypeId: photoDoc.id },
        { content: PDF, name: 'photo.jpg', type: 'image/jpeg' },
      ).expect(415);
    });

    it('refuses a file larger than the document type allows', async () => {
      const big = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(1.5 * 1024 * 1024, 'a')]);
      const response = await upload(
        operatorA,
        { documentTypeId: smallDoc.id },
        { content: big, name: 'big.pdf', type: 'application/pdf' },
      ).expect(413);
      expect(JSON.stringify(response.body)).toContain('1 MB');
    });

    it('refuses a disabled or unknown document type', async () => {
      const file = { content: PDF, name: 'a.pdf', type: 'application/pdf' };
      await upload(operatorA, { documentTypeId: disabledDoc.id }, file).expect(404);
      await upload(operatorA, { documentTypeId: new Types.ObjectId().toHexString() }, file).expect(
        404,
      );
    });

    it('refuses fields it does not know', async () => {
      await upload(
        operatorA,
        { documentTypeId: companyDoc.id, storageKey: '../x' },
        { content: PDF, name: 'a.pdf', type: 'application/pdf' },
      ).expect(400);
    });
  });

  describe('operators cannot reach each other’s files', () => {
    let fileOfA: FileBody;

    beforeAll(async () => {
      fileOfA = dataOf<FileBody>(
        await upload(
          operatorA,
          { documentTypeId: companyDoc.id },
          { content: PDF, name: 'private.pdf', type: 'application/pdf' },
        ).expect(201),
      );
    });

    it('operator B cannot describe or download it, and cannot tell it exists', async () => {
      await get(operatorB, `/${fileOfA.id}`).expect(404);
      await get(operatorB, `/${fileOfA.id}/content`).expect(404);
    });

    it('operator B cannot upload into operator A', async () => {
      await upload(
        operatorB,
        { documentTypeId: companyDoc.id, operatorId: operatorAId },
        { content: PDF, name: 'a.pdf', type: 'application/pdf' },
      ).expect(404);
    });

    it('platform staff can open it', async () => {
      await get(platformStaff, `/${fileOfA.id}/content`).expect(200);
    });

    it('a role without the document permissions is refused', async () => {
      await get(support, `/${fileOfA.id}`).expect(403);
      await upload(
        support,
        { documentTypeId: companyDoc.id, operatorId: operatorAId },
        { content: PDF, name: 'a.pdf', type: 'application/pdf' },
      ).expect(403);
    });

    it('an unknown or malformed id is answered as not found or invalid', async () => {
      await get(operatorA, `/${new Types.ObjectId().toHexString()}`).expect(404);
      await get(operatorA, '/not-an-id').expect(400);
    });
  });

  it('keeps no bytes for an upload that was refused', async () => {
    const before = await context.connection.collection('stored_files').countDocuments({});
    await upload(
      operatorA,
      { documentTypeId: photoDoc.id },
      { content: PDF, name: 'x.jpg', type: 'image/jpeg' },
    ).expect(415);
    expect(await context.connection.collection('stored_files').countDocuments({})).toBe(before);
  });
});
