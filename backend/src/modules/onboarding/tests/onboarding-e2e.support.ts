/* eslint-disable prefer-const -- the shared helpers refer to these before their setup code assigns them */
import { mkdtemp, rm } from 'node:fs/promises';
import { type AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { SMTPServer } from 'smtp-server';
import { EmailSettingsStore } from '../../../integrations/email/email-settings.store';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
  uniqueEmail,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type InvitationView } from '../services/invitations.service';
import { type SubmissionView } from '../services/submission-view.service';

export type Who = { tokens: Tokens } | undefined;

export interface Identified {
  id: string;
}

export const API = '/api/v1';
export const OWNER_PASSWORD = 'correct horse battery 42';
const SMTP_PASSWORD = 'smtp password for tests 9';

export const PDF = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(1500, 'a')]);
export const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(400, 1),
]);
export const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(400, 2)]);

export const inDays = (days: number): string =>
  new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

/** The whole onboarding story — real application, MongoDB, Redis, a real SMTP server and storage folder. */
/**
 * Starts the application, a real SMTP server and a storage folder, creates the staff users
 * and a known list of required documents, and returns the helpers the onboarding specs share.
 */
export async function createOnboardingWorld() {
  let context: AuthTestContext;
  let smtp: SMTPServer;
  let storageRoot: string;
  const mails: Array<{ to: string[]; data: string }> = [];

  let superAdmin: { tokens: Tokens };
  let plainAdmin: { tokens: Tokens };
  let support: { tokens: Tokens; email: string };

  let regType: Identified;
  let gstType: Identified;
  let optionalType: Identified;
  let rcType: Identified;
  let photosType: Identified;
  let busTypeId: string;

  const call = (
    who: Who,
    method: 'get' | 'post' | 'put' | 'delete',
    path: string,
    body?: object,
  ) => {
    const request = client(context)[method](`${API}${path}`);
    if (who) request.set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };

  const detail = async (who: Who, id: string): Promise<SubmissionView> =>
    dataOf<SubmissionView>(await call(who, 'get', `/onboarding/submissions/${id}`).expect(200));

  const uploadFile = async (
    who: Who,
    documentTypeId: string,
    content: Buffer,
    name = 'document.pdf',
    operatorId?: string,
  ): Promise<string> => {
    const request = client(context)
      .post(`${API}/files`)
      .set(...bearer((who as { tokens: Tokens }).tokens))
      .field('documentTypeId', documentTypeId);
    if (operatorId) request.field('operatorId', operatorId);
    const response = await request
      .attach('file', content, { filename: name, contentType: 'application/octet-stream' })
      .expect(201);
    return dataOf<Identified>(response).id;
  };

  const setDocument = (
    who: Who,
    submissionId: string,
    documentTypeId: string,
    body: { fileIds: string[]; expiryDate?: string },
  ) =>
    call(who, 'put', `/onboarding/submissions/${submissionId}/documents/${documentTypeId}`, body);

  const review = (
    submissionId: string,
    documentTypeId: string,
    decision: 'APPROVED' | 'REJECTED',
    reason?: string,
  ) =>
    call(
      superAdmin,
      'post',
      `/onboarding/submissions/${submissionId}/documents/${documentTypeId}/review`,
      {
        decision,
        ...(reason ? { reason } : {}),
      },
    );

  // The token in an invitation link, as the API returns the link (no encoding)
  const tokenIn = (link: string): string => {
    const match = /accept-invite\?token=([A-Za-z0-9_-]+)/.exec(link);
    if (!match?.[1]) throw new Error('No invitation link found');
    return match[1];
  };

  // The same, from the raw email: mail is quoted-printable on the wire, so decode it first
  const tokenInMail = (mail: string): string =>
    tokenIn(
      mail
        .replace(/=\r?\n/g, '')
        .replace(/=([0-9A-F]{2})/g, (_, hex: string) => String.fromCharCode(parseInt(hex, 16))),
    );

  const invite = async (email: string, company: string): Promise<InvitationView> =>
    dataOf<InvitationView>(
      await call(superAdmin, 'post', '/onboarding/invitations', {
        companyName: company,
        ownerName: 'Owner of ' + company,
        email,
      }).expect(201),
    );

  const tokenOf = (view: InvitationView): string => tokenIn(view.inviteUrl ?? '');

  /** Invites, accepts and signs the owner in. */
  const onboardOwner = async (
    company: string,
  ): Promise<{ tokens: Tokens; operatorId: string; email: string }> => {
    const email = uniqueEmail();
    const invitation = await invite(email, company);
    await call(undefined, 'post', '/onboarding/invitations/accept', {
      token: tokenOf(invitation),
      password: OWNER_PASSWORD,
    }).expect(200);
    const login = await call(undefined, 'post', '/auth/login', {
      identifier: email,
      password: OWNER_PASSWORD,
    }).expect(200);
    return { tokens: dataOf<Tokens>(login), operatorId: invitation.operatorId, email };
  };

  const companySubmissionId = async (operatorId: string): Promise<string> => {
    const list = await call(
      superAdmin,
      'get',
      `/onboarding/submissions?subjectType=OPERATOR&operatorId=${operatorId}`,
    ).expect(200);
    return (list.body as { data: Identified[] }).data[0]?.id ?? '';
  };

  /** Fills the three company documents, sends them, and returns the submission id. */
  const submitCompany = async (owner: { tokens: Tokens; operatorId: string }): Promise<string> => {
    const id = await companySubmissionId(owner.operatorId);
    await setDocument(owner, id, regType.id, {
      fileIds: [await uploadFile(owner, regType.id, PDF)],
    }).expect(200);
    await setDocument(owner, id, gstType.id, {
      fileIds: [await uploadFile(owner, gstType.id, PNG, 'gst.png')],
    }).expect(200);
    await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(200);
    return id;
  };

  const createBus = async (owner: { tokens: Tokens }, name: string): Promise<string> =>
    dataOf<Identified>(
      await call(owner, 'post', '/catalogue/buses', {
        registrationNumber: `KA01${String(Date.now()).slice(-8)}`.slice(0, 13),
        name,
        busTypeId,
        seatCapacity: 30,
      }).expect(201),
    ).id;

  storageRoot = await mkdtemp(join(tmpdir(), 'abra-onboarding-e2e-'));
  process.env.STORAGE_LOCAL_ROOT = storageRoot;

  smtp = new SMTPServer({
    authOptional: false,
    allowInsecureAuth: true,
    disabledCommands: ['STARTTLS'],
    onAuth(auth, _session, callback) {
      if (auth.username === 'mailer' && auth.password === SMTP_PASSWORD) {
        callback(null, { user: 'mailer' });
      } else {
        callback(new Error('Invalid login'));
      }
    },
    onData(stream, session, callback) {
      const chunks: Buffer[] = [];
      stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      stream.on('end', () => {
        mails.push({
          to: session.envelope.rcptTo.map((address) => address.address),
          data: Buffer.concat(chunks).toString('utf8'),
        });
        callback();
      });
    },
  });
  await new Promise<void>((resolve) => smtp.listen(0, '127.0.0.1', resolve));
  const port = (smtp.server.address() as AddressInfo).port;

  context = await createAuthTestApp();
  superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
  plainAdmin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
  support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });

  // Real mail server for the invitation emails
  await call(superAdmin, 'put', '/settings/integrations/email', {
    host: '127.0.0.1',
    port,
    security: 'NONE',
    username: 'mailer',
    password: SMTP_PASSWORD,
    fromAddress: 'no-reply@abratravels.test',
    reason: 'Onboarding tests',
  }).expect(200);

  // A known list of required documents
  await context.connection.collection('document_types').deleteMany({});
  const addType = async (key: string, body: object): Promise<Identified> =>
    dataOf<Identified>(
      await call(superAdmin, 'post', '/catalogue/document-types', {
        key: `${key}_${Date.now()}`,
        name: key,
        ...body,
      }).expect(201),
    );
  regType = await addType('REGISTRATION', {
    sortOrder: 10,
    appliesTo: 'OPERATOR',
    allowedMimeTypes: ['application/pdf', 'image/png'],
  });
  gstType = await addType('GST', {
    sortOrder: 20,
    appliesTo: 'OPERATOR',
    allowedMimeTypes: ['application/pdf', 'image/png'],
  });
  optionalType = await addType('PAN', { sortOrder: 30, appliesTo: 'OPERATOR', isRequired: false });
  rcType = await addType('RC', {
    sortOrder: 10,
    appliesTo: 'BUS',
    requiresExpiry: true,
    allowedMimeTypes: ['application/pdf', 'image/png'],
  });
  photosType = await addType('PHOTOS', {
    sortOrder: 20,
    appliesTo: 'BUS',
    allowedMimeTypes: ['image/jpeg', 'image/png'],
    maxFiles: 3,
  });
  busTypeId = dataOf<Identified>(
    await call(superAdmin, 'post', '/catalogue/bus-types', {
      key: `ONB_${Date.now()}`,
      name: 'AC Sleeper',
      isAc: true,
      berthType: 'SLEEPER',
    }).expect(201),
  ).id;

  const close = async (): Promise<void> => {
    context.app.get(EmailSettingsStore).invalidate();
    await context.close();
    await new Promise<void>((resolve) => smtp.close(() => resolve()));
    await rm(storageRoot, { recursive: true, force: true });
    delete process.env.STORAGE_LOCAL_ROOT;
  };

  return {
    context,
    smtp,
    mails,
    superAdmin,
    plainAdmin,
    support,
    regType,
    gstType,
    optionalType,
    rcType,
    photosType,
    busTypeId,
    call,
    detail,
    uploadFile,
    setDocument,
    review,
    tokenIn,
    tokenInMail,
    invite,
    tokenOf,
    onboardOwner,
    companySubmissionId,
    submitCompany,
    createBus,
    close,
  };
}

export type OnboardingWorld = Awaited<ReturnType<typeof createOnboardingWorld>>;
