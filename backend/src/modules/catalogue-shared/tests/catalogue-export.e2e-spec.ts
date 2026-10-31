import { Workbook } from 'exceljs';
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
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { CSV_BOM } from '../catalogue_export_manage.service';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  type Identified,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

/** Collects a file answer as bytes instead of letting the test client read it as text. */
function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** Server-side export of the admin lists: files, filters, permissions, audit. */
describe('Catalogue export e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
  let support: Caller;
  let operator: Caller;
  let superAdmin: Caller;

  const file = (caller: Caller, path: string) =>
    client(context)
      .get(`${API}${path}`)
      .set(...bearer(caller.tokens))
      .buffer(true)
      .parse(binary as never);
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
  const textOf = (response: Response) => (response.body as Buffer).toString('utf8');
  const linesOf = (response: Response) =>
    textOf(response).replace(CSV_BOM, '').trim().split('\r\n');

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}exp`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    operator = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('a CSV file', () => {
    it('has the columns of the list and a row for every record', async () => {
      const response = await file(admin, '/catalogue/cities/export').expect(200);
      expect(response.headers['content-type']).toMatch(/^text\/csv/);
      expect(response.headers['content-disposition']).toMatch(
        /^attachment; filename="cities-\d{4}-\d{2}-\d{2}\.csv"$/,
      );
      expect(response.headers['cache-control']).toBe('no-store');
      // The byte order mark lets Excel read Telugu and Hindi names
      expect(textOf(response).startsWith(CSV_BOM)).toBe(true);
      const lines = linesOf(response);
      expect(lines[0]).toBe(
        'City,State,Country code,Slug,Telugu name,Hindi name,Popular,Sort order,Latitude,Longitude,Status',
      );
      // the network has three cities
      expect(lines.length - 1).toBeGreaterThanOrEqual(3);
      expect(textOf(response)).toContain(`Bengaluru ${runId}exp`);
    });

    it('uses the filters of the list and gives the same rows', async () => {
      const inactive = dataOf<Identified>(
        await call(admin).post('/catalogue/cities', { name: `Dormant ${runId}`, state: 'Test' }),
      );
      await call(admin).post(`/catalogue/cities/${inactive.id}/active`, { active: false });

      const listed = dataOf<{ name: string }[]>(
        await call(admin).get('/catalogue/cities?active=false&pageSize=100'),
      );
      const exported = linesOf(await file(admin, '/catalogue/cities/export?active=false')).slice(1);
      expect(exported).toHaveLength(listed.length);
      expect(exported.join('\n')).toContain(`Dormant ${runId}`);
      expect(exported.join('\n')).toContain('Inactive');

      const byName = linesOf(await file(admin, `/catalogue/cities/export?query=Dormant`)).slice(1);
      expect(byName).toHaveLength(1);
    });

    it('quotes values with commas, quotes or line breaks, and defuses formulas', async () => {
      await call(admin)
        .post('/catalogue/cities', { name: `=SUM(1,2) ${runId}`, state: 'He said "hi", twice' })
        .expect(201);
      const text = textOf(await file(admin, `/catalogue/cities/export?query=%3DSUM`).expect(200));
      // a leading = would run as a formula in a spreadsheet: it gets a quote in front
      expect(text).toContain(`"'=SUM(1,2) ${runId}"`);
      expect(text).toContain('"He said ""hi"", twice"');
    });
  });

  describe('an Excel file', () => {
    it('holds the same table on one sheet with a header row', async () => {
      const response = await file(admin, '/catalogue/bus-types/export?format=xlsx').expect(200);
      expect(response.headers['content-type']).toBe(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(response.headers['content-disposition']).toMatch(/bus-types-\d{4}-\d{2}-\d{2}\.xlsx/);
      const workbook = new Workbook();
      await workbook.xlsx.load(response.body as never);
      const sheet = workbook.worksheets[0];
      if (!sheet) throw new Error('no sheet');
      expect((sheet.getRow(1).values as unknown[]).slice(1)).toEqual([
        'Bus type',
        'Key',
        'Air conditioned',
        'Seating',
        'Status',
      ]);
      expect(sheet.rowCount).toBeGreaterThanOrEqual(2);
      expect(sheet.getRow(2).getCell(1).text).toBe('AC Sleeper');
    });
  });

  describe('the other lists', () => {
    const lists: ReadonlyArray<[path: string, header: string]> = [
      [
        '/catalogue/locations/export',
        'Place,City,Address,Landmark,Used for,Instructions,Contact phone,Latitude,Longitude,Added by,Trips using it,Status',
      ],
      ['/catalogue/bus-types/export', 'Bus type,Key,Air conditioned,Seating,Status'],
      [
        '/catalogue/document-types/export',
        'Document,Key,For,Required,Has expiry,File types,Max size (MB),Max files,Instructions,Status',
      ],
      ['/catalogue/operators/export', 'Operator,Display name,Status,Updated'],
      [
        '/onboarding/invitations/export',
        'Company,Owner,Email,Phone,Status,Email sent,Link valid until,Invited on',
      ],
      [
        '/onboarding/submissions/export',
        'Operator,Type,Bus,Status,Times sent,Sent on,Decided on',
      ],
      [
        '/admin/banners/export',
        'Banner,Subtitle,Status,Starts,Ends,Shown to,Opens,Link value,Colour style,Order,Created',
      ],
    ];

    it.each(lists)('%s answers with its header row', async (path, header) => {
      const response = await file(superAdmin, path).expect(200);
      expect(linesOf(response)[0]).toBe(header);
    });

    it('shows the name of the city in the places file', async () => {
      const text = textOf(await file(admin, '/catalogue/locations/export').expect(200));
      expect(text).toContain(`Majestic Bus Stand,Bengaluru ${runId}exp,`);
    });
  });

  describe('rules', () => {
    it('needs the export permission: support and operators are refused', async () => {
      for (const caller of [support, operator]) {
        expect((await file(caller, '/catalogue/cities/export')).status).toBe(403);
        expect((await file(caller, '/admin/banners/export')).status).toBe(403);
      }
      await client(context).get(`${API}/catalogue/cities/export`).expect(401);
    });

    it('refuses a filter the list does not have, a paging parameter and an unknown format', async () => {
      expect((await call(admin).get('/catalogue/cities/export?colour=red')).status).toBe(400);
      expect((await call(admin).get('/catalogue/cities/export?page=2')).status).toBe(400);
      expect((await call(admin).get('/catalogue/cities/export?format=pdf')).status).toBe(400);
    });

    it('writes an audit entry with the format, the number of rows and the filters', async () => {
      await file(admin, '/catalogue/cities/export?active=false&format=csv').expect(200);
      const entries = dataOf<
        {
          action: string;
          entityType: string;
          after: { format: string; rows: number; filters: object };
        }[]
      >(await call(superAdmin).get('/audit-logs?pageSize=50'));
      const entry = entries.find(
        (candidate) =>
          candidate.action === 'catalogue.exported' && candidate.entityType === 'cities',
      );
      expect(entry).toBeDefined();
      expect(entry?.after.format).toBe('csv');
      expect(entry?.after.filters).toEqual({ active: false });
      expect(entry?.after.rows).toBeGreaterThanOrEqual(1);
    });
  });
});
