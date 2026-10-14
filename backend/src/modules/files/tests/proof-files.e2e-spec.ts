import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Types } from 'mongoose';
import { type Response } from 'supertest';
import { systemActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { ProofFilesService, type ProofFileView } from '../files_core.service';

type Caller = SeededUser & { tokens: Tokens };

const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(500, 1),
]);
const PDF = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(800, 'a')]);
const NOTE = Buffer.from('Driver called at 10:15 and confirmed the bus broke down.\n', 'utf8');

function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** Proof files: upload rules, who can open them, and attaching them to an action. */
describe('Proof files e2e', () => {
  let context: AuthTestContext;
  let storageRoot: string;
  let staff: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  let customer: Caller;
  let otherCustomer: Caller;
  const operatorAId = new Types.ObjectId();
  const operatorBId = new Types.ObjectId();

  const user = (roleKey: SystemRoleKey, operatorId?: Types.ObjectId) =>
    seedAndSignIn(context, { roleKeys: [roleKey], ...(operatorId ? { operatorId } : {}) });
  const upload = (who: Caller, content?: Buffer, name = 'proof.bin') => {
    const request = client(context)
      .post('/api/v1/files/proofs')
      .set(...bearer(who.tokens));
    if (content) request.attach('file', content, { filename: name });
    return request;
  };
  const get = (who: Caller, path: string) =>
    client(context)
      .get(`/api/v1/files/proofs${path}`)
      .set(...bearer(who.tokens));
  const uploaded = async (who: Caller, content = PNG, name = 'photo.png') =>
    dataOf<ProofFileView>(await upload(who, content, name).expect(201));
  const service = () => context.app.get(ProofFilesService);
  const asSystem = <T>(work: () => Promise<T>) =>
    RequestContextService.run({ requestId: 'proof-test', actor: systemActor('proof test') }, work);

  beforeAll(async () => {
    storageRoot = await mkdtemp(join(tmpdir(), 'abra-proofs-e2e-'));
    process.env.STORAGE_LOCAL_ROOT = storageRoot;
    context = await createAuthTestApp();
    staff = await user('ADMIN');
    operatorA = await user('OPERATOR_ADMIN', operatorAId);
    operatorB = await user('OPERATOR_ADMIN', operatorBId);
    customer = await seedAndSignIn(context, { roleKeys: [], userType: 'CUSTOMER' });
    otherCustomer = await seedAndSignIn(context, { roleKeys: [], userType: 'CUSTOMER' });
  }, 120_000);

  afterAll(async () => {
    await context.close();
    await rm(storageRoot, { recursive: true, force: true });
  }, 60_000);

  describe('uploading', () => {
    it('takes a picture, a PDF and a text note, reading the real type from the bytes', async () => {
      // the declared type and the name are not trusted
      expect(await uploaded(staff, PNG, 'looks-like.pdf')).toMatchObject({
        mimeType: 'image/png',
        sizeBytes: PNG.length,
        originalName: 'looks-like.pdf',
        attached: false,
      });
      expect(await uploaded(staff, PDF, 'bill.pdf')).toMatchObject({ mimeType: 'application/pdf' });
      expect(await uploaded(staff, NOTE, 'note.txt')).toMatchObject({ mimeType: 'text/plain' });
    });

    it('is open to every signed-in person, and to nobody else', async () => {
      await upload(customer, PNG, 'a.png').expect(201);
      await upload(operatorA, PNG, 'a.png').expect(201);
      await client(context)
        .post('/api/v1/files/proofs')
        .attach('file', PNG, { filename: 'a.png' })
        .expect(401);
    });

    it('refuses what is not a picture, PDF or text', async () => {
      const program = Buffer.concat([Buffer.from('MZ'), Buffer.alloc(300, 0)]);
      const response = await upload(staff, program, 'tool.exe');
      expect(response.status).toBe(415);
      const withNul = Buffer.from('hello\u0000world', 'utf8');
      expect((await upload(staff, withNul, 'x.txt')).status).toBe(415);
    });

    it('refuses an empty file, no file, and a file over 600 KB', async () => {
      expect((await upload(staff, Buffer.alloc(0), 'empty.txt')).status).toBe(400);
      expect((await upload(staff)).status).toBe(400);
      const big = Buffer.concat([PNG, Buffer.alloc(601 * 1024, 2)]);
      const response = await upload(staff, big, 'big.png');
      expect(response.status).toBe(413);
      expect(errorCodeOf(response)).toBe('PAYLOAD_TOO_LARGE');
      const justFits = Buffer.concat([PNG, Buffer.alloc(600 * 1024 - PNG.length, 2)]);
      await upload(staff, justFits, 'fits.png').expect(201);
    });
  });

  describe('who can open a proof', () => {
    it('the person who uploaded it: describe, view in place and download', async () => {
      const proof = await uploaded(customer, PDF, 'receipt.pdf');
      expect((await get(customer, `/${proof.id}`).expect(200)).body).toMatchObject({
        data: { id: proof.id, originalName: 'receipt.pdf' },
      });
      const inline = await get(customer, `/${proof.id}/content?disposition=inline`)
        .buffer(true)
        .parse(binary as never)
        .expect(200);
      expect(inline.headers['content-disposition']).toMatch(/^inline;/);
      expect(inline.headers['content-type']).toBe('application/pdf');
      expect(inline.headers['x-content-type-options']).toBe('nosniff');
      expect(inline.headers['cache-control']).toBe('private, no-store');
      expect(inline.headers['content-security-policy']).toContain("default-src 'none'");
      expect((inline.body as Buffer).equals(PDF)).toBe(true);

      const download = await get(customer, `/${proof.id}/content`)
        .buffer(true)
        .parse(binary as never)
        .expect(200);
      expect(download.headers['content-disposition']).toMatch(/^attachment;/);
    });

    it('a text note is shown as UTF-8 text', async () => {
      const proof = await uploaded(staff, NOTE, 'note.txt');
      const response = await get(staff, `/${proof.id}/content?disposition=inline`)
        .buffer(true)
        .parse(binary as never)
        .expect(200);
      expect(response.headers['content-type']).toContain('text/plain; charset=utf-8');
    });

    it('Abra staff open any proof', async () => {
      const proof = await uploaded(customer);
      await get(staff, `/${proof.id}`).expect(200);
    });

    it("someone else cannot: another customer, another operator's staff", async () => {
      const proof = await uploaded(customer);
      await get(otherCustomer, `/${proof.id}`).expect(404);
      await get(otherCustomer, `/${proof.id}/content`).expect(404);
      await get(operatorA, `/${proof.id}`).expect(404);
    });

    it("an operator's staff open their operator's proofs and not another's", async () => {
      const proof = await uploaded(operatorA);
      await get(operatorA, `/${proof.id}`).expect(200);
      await get(operatorB, `/${proof.id}`).expect(404);
      await get(operatorB, `/${proof.id}/content`).expect(404);
    });

    it('refuses a bad id and an unknown one', async () => {
      await get(staff, '/not-an-id').expect(400);
      await get(staff, `/${new Types.ObjectId().toHexString()}`).expect(404);
    });
  });

  describe('attaching to an action', () => {
    it('marks the proofs, lets the people the action names open them, and lists them', async () => {
      const proof = await uploaded(staff, PNG, 'cancel.png');
      const trip = new Types.ObjectId();
      await get(customer, `/${proof.id}`).expect(404);

      await asSystem(() =>
        service().attach([proof.id], {
          type: 'trip-cancel',
          id: trip,
          shareWith: [new Types.ObjectId(customer.id)],
        }),
      );

      expect((await get(staff, `/${proof.id}`).expect(200)).body).toMatchObject({
        data: { attached: true },
      });
      // the customer the action concerns can now open it; another customer still cannot
      await get(customer, `/${proof.id}`).expect(200);
      await get(customer, `/${proof.id}/content`).expect(200);
      await get(otherCustomer, `/${proof.id}`).expect(404);
      const listed = await asSystem(() => service().listFor('trip-cancel', trip));
      expect(listed.map((item) => item.id)).toEqual([proof.id]);
    });

    it('takes at most five proofs for one action', async () => {
      const proofs = await Promise.all([1, 2, 3, 4, 5, 6].map(() => uploaded(staff)));
      const subject = { type: 'refund-reject', id: new Types.ObjectId() };
      await expect(
        asSystem(() =>
          service().attach(
            proofs.map((proof) => proof.id),
            subject,
          ),
        ),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
      await asSystem(() =>
        service().attach(
          proofs.slice(0, 5).map((proof) => proof.id),
          subject,
        ),
      );
      // a sixth added later is refused too, and nothing changed for it
      await expect(
        asSystem(() => service().attach([proofs[5]!.id], subject)),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
      expect((await get(staff, `/${proofs[5]!.id}`)).body).toMatchObject({
        data: { attached: false },
      });
    });

    it('does not let a proof serve two actions, and repeats of one id count once', async () => {
      const proof = await uploaded(staff);
      await asSystem(() =>
        service().attach([proof.id, proof.id], {
          type: 'customer-block',
          id: new Types.ObjectId(),
        }),
      );
      await expect(
        asSystem(() =>
          service().attach([proof.id], { type: 'trip-cancel', id: new Types.ObjectId() }),
        ),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it('refuses an id that is not a proof', async () => {
      await expect(
        asSystem(() =>
          service().attach([new Types.ObjectId().toHexString()], {
            type: 'trip-cancel',
            id: new Types.ObjectId(),
          }),
        ),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it('accepts an action with no proofs', async () => {
      await asSystem(() =>
        service().attach(undefined, { type: 'trip-cancel', id: new Types.ObjectId() }),
      );
    });
  });
});
