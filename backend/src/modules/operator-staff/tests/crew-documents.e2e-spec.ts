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
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  type Identified,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';
import {
  CrewDocumentsClientManageService,
  parseCsv,
  parseDay,
  crewSampleCsv,
  daysLeftOf,
} from '../crew_documents_client_manage.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }
interface DocView {
  id: string; docType: string; docName: string; validTill?: string; status: string; daysLeft?: number;
  files: Array<{ id: string; originalName: string; mimeType: string }>;
}
interface ImportResult { total: number; imported: number; skipped: number; skippedRows: Array<{ row: number; reason: string }> }

const PDF = Buffer.from('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n');
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from('fake-image-data')]);
const day = (offset: number): string => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

describe('csv and dates (unit)', () => {
  it('reads quoted cells, doubled quotes and other delimiters', () => {
    expect(parseCsv('﻿a,b\r\n"x, y","say ""hi"""\r\n')).toEqual([['a', 'b'], ['x, y', 'say "hi"']]);
    expect(parseCsv('a;b\n1;2')).toEqual([['a', 'b'], ['1', '2']]);
  });
  it('accepts only real calendar days', () => {
    expect(parseDay('2027-03-31')?.toISOString()).toBe('2027-03-31T00:00:00.000Z');
    expect(parseDay('2027-02-30')).toBeUndefined();
    expect(parseDay('31/03/2027')).toBeUndefined();
  });
  it('counts whole days from today, negative once passed', () => {
    const now = new Date('2026-10-23T15:00:00Z');
    expect(daysLeftOf(new Date('2026-10-23T00:00:00Z'), now)).toBe(0);
    expect(daysLeftOf(new Date('2026-10-30T00:00:00Z'), now)).toBe(7);
    expect(daysLeftOf(new Date('2026-10-22T00:00:00Z'), now)).toBe(-1);
  });
  it('the sample file has the star columns and example rows', () => {
    const rows = parseCsv(crewSampleCsv());
    expect(rows[0]?.slice(0, 2)).toEqual(['Name*', 'Phone*']);
    expect(rows.length).toBeGreaterThanOrEqual(4);
  });
});

describe('Crew documents e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let operatorA: Caller;
  let operatorB: Caller;
  let service: CrewDocumentsClientManageService;
  let driverId: string;
  let docId: string;
  let firstFileId: string;

  const auth = (caller: Caller) => bearer(caller.tokens);

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    await clearCatalogue(context);
    service = context.app.get(CrewDocumentsClientManageService);
    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}cdoc`);
    operatorA = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(network.operator.id) });
    const other = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Docs Pvt Ltd`,
      displayName: `Operator B ${runId} Docs`,
    });
    await catalogueApi(context, superAdmin).post(`/operators/${other.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' }).expect(201);
    operatorB = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(other.id) });
    const created = await client(context).post(`${API}/client/crew`).set(...auth(operatorA)).send({
      name: 'Doc Driver', role: 'DRIVER', phone: `+9198${String(Date.now()).slice(-8)}`,
    }).expect(201);
    driverId = dataOf<{ id: string }>(created).id;
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('adds a document with two files and a validity date', async () => {
    const res = await client(context).post(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorA))
      .field('docType', 'DRIVING_LICENCE').field('validTill', day(20))
      .attach('files', PDF, 'licence-front.pdf').attach('files', PNG, 'licence-back.png')
      .expect(201);
    const doc = dataOf<DocView>(res);
    docId = doc.id;
    firstFileId = doc.files[0]?.id ?? '';
    expect(doc.docName).toBe('Driving licence');
    expect(doc.files.map((f) => f.mimeType).sort()).toEqual(['application/pdf', 'image/png']);
    expect(doc.status).toBe('EXPIRING');
  });

  it('keeps the licence date of the person in step with the licence document', async () => {
    const res = await client(context).get(`${API}/client/crew`).set(...auth(operatorA)).expect(200);
    const person = dataOf<Array<{ id: string; licenseExpiryDate?: string; documentsCount?: number; documentsExpiring?: number }>>(res)
      .find((p) => p.id === driverId);
    expect(person?.licenseExpiryDate).toBe(day(20));
    expect(person?.documentsCount).toBe(1);
    expect(person?.documentsExpiring).toBe(1);
  });

  it('needs a typed name for "Other" and a real file type', async () => {
    await client(context).post(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorA))
      .field('docType', 'OTHER').attach('files', PDF, 'x.pdf').expect(400);
    await client(context).post(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorA))
      .field('docType', 'AADHAAR').attach('files', Buffer.from('MZ not a document'), 'virus.pdf').expect(415);
  });

  it('adds an "Other" document without a validity date', async () => {
    const res = await client(context).post(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorA))
      .field('docType', 'OTHER').field('docName', 'Hill driving certificate')
      .attach('files', PDF, 'hill.pdf').expect(201);
    const doc = dataOf<DocView>(res);
    expect(doc.docName).toBe('Hill driving certificate');
    expect(doc.status).toBe('NO_DATE');
  });

  it('views and downloads a file, and another operator cannot', async () => {
    const url = `${API}/client/crew/${driverId}/documents/${docId}/files/${firstFileId}`;
    const download = await client(context).get(url).set(...auth(operatorA)).buffer(true).expect(200);
    expect(download.headers['content-disposition']).toContain('attachment');
    const inline = await client(context).get(`${url}?disposition=inline`).set(...auth(operatorA)).expect(200);
    expect(inline.headers['content-disposition']).toContain('inline');
    await client(context).get(url).set(...auth(operatorB)).expect(404);
    await client(context).get(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorB)).expect(404);
  });

  it('adds a file, changes the date, removes a file', async () => {
    const more = await client(context).post(`${API}/client/crew/${driverId}/documents/${docId}/files`).set(...auth(operatorA))
      .attach('files', PNG, 'extra.png').expect(201);
    expect(dataOf<DocView>(more).files).toHaveLength(3);
    const patched = await client(context).patch(`${API}/client/crew/${driverId}/documents/${docId}`).set(...auth(operatorA))
      .send({ validTill: day(400) }).expect(200);
    expect(dataOf<DocView>(patched).status).toBe('VALID');
    const less = await client(context).delete(`${API}/client/crew/${driverId}/documents/${docId}/files/${firstFileId}`).set(...auth(operatorA)).expect(200);
    expect(dataOf<DocView>(less).files).toHaveLength(2);
  });

  it('sends one reminder per stage and never repeats it', async () => {
    await client(context).patch(`${API}/client/crew/${driverId}/documents/${docId}`).set(...auth(operatorA))
      .send({ validTill: day(5) }).expect(200);
    const first = await service.scanExpiries();
    expect(first.sent).toBeGreaterThanOrEqual(1);
    const second = await service.scanExpiries();
    expect(second.sent).toBe(0);
    const reminders = context.app.get<import('mongoose').Connection>(
      (await import('@nestjs/mongoose')).getConnectionToken(),
    ).collection('crew_expiry_reminders');
    expect(await reminders.countDocuments({ key: new RegExp(`^DOC:${docId}:${day(5)}:7$`) })).toBe(1);
  });

  it('imports people from CSV and reports rejected rows', async () => {
    const stamp = String(Date.now()).slice(-7);
    const csv = [
      'Name*,Phone*,Role,Licence Number,Licence Valid Till,Badge Number,Status',
      `Imp One,98${stamp}1,DRIVER,DL1,${day(100)},B1,ACTIVE`,
      `Imp Two,98${stamp}2,CONDUCTOR,,,,ACTIVE`,
      `Imp One Again,98${stamp}1,DRIVER,,,,ACTIVE`,
      ',9811111111,DRIVER,,,,ACTIVE',
      'Bad Phone,12,DRIVER,,,,ACTIVE',
      `Bad Role,98${stamp}3,PILOT,,,,ACTIVE`,
      `Bad Date,98${stamp}4,DRIVER,,31/12/2027,,ACTIVE`,
    ].join('\n');
    const res = await client(context).post(`${API}/client/crew/import`).set(...auth(operatorA))
      .attach('file', Buffer.from(csv), 'people.csv').expect(201);
    const result = dataOf<ImportResult>(res);
    expect(result.total).toBe(7);
    expect(result.imported).toBe(2);
    expect(result.skipped).toBe(5);
    expect(result.skippedRows.map((r) => r.row)).toEqual([4, 5, 6, 7, 8]);
    await client(context).post(`${API}/client/crew/import`).set(...auth(operatorA))
      .attach('file', Buffer.from('x'), 'people.txt').expect(400);
  });

  it('serves the sample file and deletes a document', async () => {
    const sample = await client(context).get(`${API}/client/crew/import/sample`).set(...auth(operatorA)).expect(200);
    expect(sample.headers['content-type']).toContain('text/csv');
    await client(context).delete(`${API}/client/crew/${driverId}/documents/${docId}`).set(...auth(operatorA)).expect(200);
    const list = await client(context).get(`${API}/client/crew/${driverId}/documents`).set(...auth(operatorA)).expect(200);
    expect(dataOf<DocView[]>(list).map((d) => d.id)).not.toContain(docId);
  });
});
