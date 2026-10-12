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
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface RowResult {
  row: number;
  label: string;
  status: 'OK' | 'CREATED' | 'ERROR';
  errors: string[];
}

interface ImportAnswer {
  dryRun: boolean;
  total: number;
  accepted: number;
  rejected: number;
  ignoredColumns: string[];
  rows: RowResult[];
}

function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** Import of cities and places: template, dry run, save, row-by-row answers. */
describe('Catalogue import e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
  let support: Caller;
  let superAdmin: Caller;

  const signIn = (roleKey: SystemRoleKey): Promise<Caller> =>
    seedAndSignIn(context, { roleKeys: [roleKey] });
  const get = (caller: Caller, path: string) =>
    client(context)
      .get(`${API}${path}`)
      .set(...bearer(caller.tokens));
  const download = (caller: Caller, path: string) =>
    get(caller, path)
      .buffer(true)
      .parse(binary as never);
  const upload = (caller: Caller, path: string, content: Buffer | string, name = 'rows.csv') =>
    client(context)
      .post(`${API}${path}`)
      .set(...bearer(caller.tokens))
      .attach('file', Buffer.from(content), { filename: name });
  const answerOf = (response: Response) => dataOf<ImportAnswer>(response);
  const cityCount = async () => {
    const body = (await get(admin, '/catalogue/cities?pageSize=100')).body as {
      meta: { total: number };
    };
    return body.meta.total;
  };

  const unique = (name: string) => `${name} ${runId}`;

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}imp`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('the template', () => {
    it('has the headings of the export and one example row', async () => {
      const response = await download(admin, '/catalogue/cities/import-template').expect(200);
      expect(response.headers['content-disposition']).toContain('cities-import-template.csv');
      const lines = (response.body as Buffer)
        .toString('utf8')
        .replace(CSV_BOM, '')
        .trim()
        .split('\r\n');
      expect(lines[0]).toBe(
        'City,State,Country code,Slug,Telugu name,Hindi name,Popular,Sort order,Latitude,Longitude',
      );
      expect(lines).toHaveLength(2);
    });

    it('can be an Excel file', async () => {
      const response = await download(
        admin,
        '/catalogue/locations/import-template?format=xlsx',
      ).expect(200);
      const workbook = new Workbook();
      await workbook.xlsx.load(response.body as never);
      expect((workbook.worksheets[0]!.getRow(1).values as unknown[]).slice(1, 4)).toEqual([
        'Place',
        'City',
        'Address',
      ]);
    });
  });

  describe('cities', () => {
    const file = () =>
      [
        'City,State,Popular,Latitude,Longitude',
        `${unique('Warangal')},Telangana,Yes,17.97,79.59`, // fine
        `${unique('Karimnagar')},,No,,`, // no state
        `${unique('Nizamabad')},Telangana,Maybe,,`, // popular is not Yes or No
        `${unique('Khammam')},Telangana,No,abc,`, // latitude is not a number
        `${unique('Warangal')},Telangana,No,,`, // twice in the file
        `Bengaluru ${runId}imp,Karnataka,No,,`, // exists already
        `${unique('Adilabad')},Telangana,No,,`, // fine
        `${unique('Medak')},Telangana,No,17.5,`, // a latitude without a longitude
      ].join('\n');

    it('a dry run checks every row and saves nothing', async () => {
      const before = await cityCount();
      const answer = answerOf(await upload(admin, '/catalogue/cities/import', file()).expect(200));

      expect(answer).toMatchObject({ dryRun: true, total: 8, accepted: 2, rejected: 6 });
      const byRow = new Map(answer.rows.map((row) => [row.row, row]));
      expect(byRow.get(2)).toMatchObject({ status: 'OK', errors: [] });
      expect(byRow.get(3)?.errors).toEqual(['State: is required.']);
      expect(byRow.get(4)?.errors.join(' ')).toMatch(/Popular: "Maybe" must be Yes or No/);
      expect(byRow.get(5)?.errors.join(' ')).toMatch(/Latitude: "abc" is not a number/);
      expect(byRow.get(6)?.errors.join(' ')).toMatch(/appears in row 2/);
      expect(byRow.get(7)?.errors.join(' ')).toMatch(/already exists/);
      expect(byRow.get(8)).toMatchObject({ status: 'OK' });
      expect(byRow.get(9)?.errors.join(' ')).toMatch(/Latitude and longitude go together/);
      expect(await cityCount()).toBe(before);
    });

    it('saving creates the rows that are right and says why it left the others out', async () => {
      const before = await cityCount();
      const answer = answerOf(
        await upload(admin, '/catalogue/cities/import?dryRun=false', file()).expect(200),
      );

      expect(answer).toMatchObject({ dryRun: false, accepted: 2, rejected: 6 });
      expect(answer.rows.filter((row) => row.status === 'CREATED').map((row) => row.row)).toEqual([
        2, 8,
      ]);
      expect(await cityCount()).toBe(before + 2);

      // the same file again: now everything is known
      const again = answerOf(
        await upload(admin, '/catalogue/cities/import?dryRun=false', file()).expect(200),
      );
      expect(again.accepted).toBe(0);
      expect(await cityCount()).toBe(before + 2);

      // the entries of the audit trail: one per city, and one for the import
      const entries = dataOf<{ action: string; entityType: string; after: { created?: number } }[]>(
        await get(superAdmin, '/audit-logs?pageSize=100'),
      );
      const imported = entries.filter((entry) => entry.action === 'catalogue.imported');
      expect(imported).toHaveLength(1);
      expect(imported[0]).toMatchObject({ entityType: 'cities', after: { created: 2 } });
    });

    it('reads an Excel file as well', async () => {
      const workbook = new Workbook();
      const sheet = workbook.addWorksheet('Cities');
      sheet.addRow(['City', 'State', 'Popular']);
      sheet.addRow([unique('Nalgonda'), 'Telangana', 'Yes']);
      const data = Buffer.from(await workbook.xlsx.writeBuffer());
      const answer = answerOf(
        await upload(admin, '/catalogue/cities/import?dryRun=false', data, 'rows.xlsx').expect(200),
      );
      expect(answer).toMatchObject({ accepted: 1, rejected: 0 });
    });

    it('an exported file can be imported again: its headings are understood', async () => {
      const exported = await download(admin, '/catalogue/cities/export').expect(200);
      const answer = answerOf(
        await upload(admin, '/catalogue/cities/import', exported.body as Buffer).expect(200),
      );
      // every city is known already; the Status column is the only one not read
      expect(answer.accepted).toBe(0);
      expect(answer.ignoredColumns).toEqual(['Status']);
      expect(answer.rows.every((row) => /already exists/.test(row.errors.join(' ')))).toBe(true);
    });
  });

  describe('places', () => {
    it('finds the city by name, refuses an unknown city and a place that exists', async () => {
      const csv = [
        'Place,City,Address,Landmark,Contact phone',
        `Secunderabad Stand,Bengaluru ${runId}imp,12 Main Road,Near the flyover,9876543210`,
        `Nowhere Stand,Atlantis,1 Sea Road,,`,
        `Majestic Bus Stand,Bengaluru ${runId}imp,Gandhi Nagar,,`, // exists in that city
        `Bad Phone Stand,Bengaluru ${runId}imp,3 Lane Road,,12`,
      ].join('\n');

      const dry = answerOf(await upload(admin, '/catalogue/locations/import', csv).expect(200));
      expect(dry).toMatchObject({ accepted: 1, rejected: 3 });
      const byRow = new Map(dry.rows.map((row) => [row.row, row]));
      expect(byRow.get(2)?.status).toBe('OK');
      expect(byRow.get(3)?.errors.join(' ')).toMatch(/"Atlantis" is not an active city/);
      expect(byRow.get(4)?.errors.join(' ')).toMatch(/already exists in Bengaluru/);
      expect(byRow.get(5)?.errors.join(' ')).toMatch(/Contact phone/);

      const saved = answerOf(
        await upload(admin, '/catalogue/locations/import?dryRun=false', csv).expect(200),
      );
      expect(saved.accepted).toBe(1);
      const places = dataOf<
        { name: string; contactPhone: string | null; operatorId: string | null }[]
      >(await get(admin, `/catalogue/locations?cityId=${network.bengaluru.id}&pageSize=100`));
      const created = places.find((place) => place.name === 'Secunderabad Stand');
      // a 10-digit number is stored in international form; the place is shared by every operator
      expect(created).toMatchObject({ contactPhone: '+919876543210', operatorId: null });
    });
  });

  describe('rules', () => {
    it('names the missing column, and refuses empty, oversized and over-long files', async () => {
      const missing = await upload(admin, '/catalogue/cities/import', 'City\nPune');
      expect(missing.status).toBe(400);
      expect((missing.body as { error: { message: string } }).error.message).toContain('"State"');

      expect((await upload(admin, '/catalogue/cities/import', 'City,State')).status).toBe(400);
      expect((await upload(admin, '/catalogue/cities/import', '')).status).toBe(400);

      const rows = Array.from({ length: 501 }, (_, index) => `City ${index},State`);
      const tooMany = await upload(
        admin,
        '/catalogue/cities/import',
        ['City,State', ...rows].join('\n'),
      );
      expect(tooMany.status).toBe(400);
      expect(JSON.stringify(tooMany.body)).toMatch(/at most 500/);

      const tooBig = await upload(admin, '/catalogue/cities/import', 'x'.repeat(1024 * 1024 + 10));
      expect(tooBig.status).toBe(413);
    });

    it('needs the permission to add records: support is refused', async () => {
      expect(
        (await upload(support, '/catalogue/cities/import', 'City,State\nPune,MH')).status,
      ).toBe(403);
      expect((await get(support, '/catalogue/cities/import-template')).status).toBe(403);
      await client(context).get(`${API}/catalogue/cities/import-template`).expect(401);
    });

    it('a cell that would run as a formula is stored as text, not as a formula', async () => {
      const answer = answerOf(
        await upload(
          admin,
          '/catalogue/cities/import?dryRun=false',
          `City,State\n=1+1 ${runId},Test State`,
        ).expect(200),
      );
      expect(answer.accepted).toBe(1);
      const exported = (await download(admin, `/catalogue/cities/export?query=%3D1`).expect(200))
        .body as Buffer;
      expect(exported.toString('utf8')).toContain(`'=1+1 ${runId}`);
      expect(Types.ObjectId.isValid(network.bengaluru.id)).toBe(true);
    });
  });
});
