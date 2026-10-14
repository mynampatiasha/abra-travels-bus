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
import { CSV_BOM } from '../../catalogue-shared/catalogue_export_manage.service';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { runId } from '../../trips/tests/discovery-e2e.fixture';
import { type AuditEntryView, type AuditFilterChoices } from '../audit_log_admin_manage.service';

const API = '/api/v1';
/** Every entry made here has this entity type, so the tests only look at their own entries. */
const TYPE = `audit_e2e_${runId}`;

type Caller = SeededUser & { tokens: Tokens };

function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** The audit log page: filters, sorting, one entry, the operator's view and the download. */
describe('Audit log page e2e', () => {
  let context: AuthTestContext;
  let superAdmin: Caller;
  let admin: Caller;
  let support: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  const operatorAId = new Types.ObjectId();
  const operatorBId = new Types.ObjectId();
  const ids: Record<string, string> = {};

  const get = (caller: Caller, path: string) =>
    client(context)
      .get(`${API}${path}`)
      .set(...bearer(caller.tokens));
  const file = (caller: Caller, path: string) =>
    get(caller, path)
      .buffer(true)
      .parse(binary as never);
  const signIn = (roleKey: SystemRoleKey, operatorId?: Types.ObjectId): Promise<Caller> =>
    seedAndSignIn(context, { roleKeys: [roleKey], ...(operatorId ? { operatorId } : {}) });
  const rename = (caller: Caller, name: string) =>
    context.connection
      .collection('users')
      .updateOne({ _id: new Types.ObjectId(caller.id) }, { $set: { name } });
  const list = async (caller: Caller, query = '') =>
    dataOf<AuditEntryView[]>(
      await get(caller, `/audit-logs?entityType=${TYPE}${query}`).expect(200),
    );
  const actionsOf = async (caller: Caller, query = '') =>
    (await list(caller, query)).map((entry) => entry.action);

  function entry(
    actor: Caller,
    userType: string,
    roleKey: string,
    action: string,
    at: string,
    extra: Record<string, unknown> = {},
  ) {
    return {
      actor: { userId: new Types.ObjectId(actor.id), userType, roleKeys: [roleKey] },
      action,
      entityType: TYPE,
      entityId: new Types.ObjectId(),
      before: {},
      after: {},
      at: new Date(at),
      ...extra,
    };
  }

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await signIn('SUPER_ADMIN');
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    operatorA = await signIn('OPERATOR_ADMIN', operatorAId);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBId);
    await rename(superAdmin, `Priya Reddy ${runId}`);
    await rename(admin, `Anil Kumar ${runId}`);
    await rename(operatorA, `Meena Travels Owner ${runId}`);

    const rows = [
      entry(superAdmin, 'STAFF', 'SUPER_ADMIN', 'role.access.changed', '2026-01-10T10:00:00Z', {
        ip: '10.0.0.1',
        before: { level: 'View' },
        after: { name: 'Finance role', level: 'Edit' },
        reason: 'Finance needs it',
      }),
      entry(admin, 'STAFF', 'ADMIN', 'banner.created', '2026-01-12T10:00:00Z', {
        ip: '10.0.0.2',
        after: { name: 'Diwali sale' },
      }),
      entry(
        operatorA,
        'OPERATOR_STAFF',
        'OPERATOR_ADMIN',
        'place-request.created',
        '2026-01-14T10:00:00Z',
        { ip: '10.0.0.3', operatorId: operatorAId, after: { name: 'Kondapur stop' } },
      ),
      entry(superAdmin, 'STAFF', 'SUPER_ADMIN', 'catalogue.exported', '2026-01-16T10:00:00Z', {
        ip: '10.0.0.4',
        operatorId: operatorBId,
      }),
      entry(superAdmin, 'STAFF', 'SUPER_ADMIN', 'onboarding.approved', '2026-01-18T10:00:00Z', {
        ip: '10.0.0.5',
        operatorId: operatorAId,
        after: { companyName: 'Meena Travels' },
      }),
    ];
    const inserted = await context.connection.collection('audit_logs').insertMany(rows);
    ['roleChange', 'banner', 'placeRequest', 'export', 'approved'].forEach((key, index) => {
      ids[key] = (inserted.insertedIds[index] as Types.ObjectId).toHexString();
    });
  }, 120_000);

  afterAll(async () => {
    await context.connection.collection('audit_logs').deleteMany({ entityType: TYPE });
    await context.close();
  }, 60_000);

  describe('the list', () => {
    it('shows newest first, with the words a person needs on screen', async () => {
      const entries = await list(superAdmin);
      expect(entries.map((e) => e.action)).toEqual([
        'onboarding.approved',
        'catalogue.exported',
        'place-request.created',
        'banner.created',
        'role.access.changed',
      ]);
      const change = entries[4]!;
      expect(change).toMatchObject({
        actionLabel: 'Changed role access',
        sensitive: true,
        actorName: `Priya Reddy ${runId}`,
        targetLabel: `Audit e2e ${runId}: Finance role`,
        ip: '10.0.0.1',
        reason: 'Finance needs it',
        before: { level: 'View' },
        after: { name: 'Finance role', level: 'Edit' },
      });
      // The role is shown by its name, not its key
      const role = await context.connection.collection('roles').findOne({ key: 'SUPER_ADMIN' });
      expect(change.actorRoleLabel).toBe(role?.['name']);
      expect(entries[3]).toMatchObject({ sensitive: false, actionLabel: 'Added a banner' });
    });

    it('sorts oldest first and by action', async () => {
      expect((await actionsOf(superAdmin, '&sort=oldest'))[0]).toBe('role.access.changed');
      const byAction = await actionsOf(superAdmin, '&sort=action');
      expect(byAction).toEqual([...byAction].sort());
    });

    it('pages 15 at a time by default and takes another size', async () => {
      const response = await get(superAdmin, `/audit-logs?entityType=${TYPE}&pageSize=2&page=2`);
      expect(response.status).toBe(200);
      const meta = (response.body as { meta: { total: number; page: number; pageSize: number } })
        .meta;
      expect(meta).toMatchObject({ total: 5, page: 2, pageSize: 2 });
      expect(dataOf<unknown[]>(response)).toHaveLength(2);
      const defaults = await get(superAdmin, `/audit-logs?entityType=${TYPE}`);
      expect((defaults.body as { meta: { pageSize: number } }).meta.pageSize).toBe(15);
    });
  });

  describe('the filters', () => {
    it('Person: one person only', async () => {
      expect(await actionsOf(superAdmin, `&personId=${admin.id}`)).toEqual(['banner.created']);
      // an id that cannot exist matches nothing
      expect(await actionsOf(superAdmin, '&personId=000000000000000000000000')).toEqual([]);
    });

    it('Type: sensitive only', async () => {
      expect(await actionsOf(superAdmin, '&type=sensitive')).toEqual([
        'onboarding.approved',
        'role.access.changed',
      ]);
    });

    it('Action: one action, and together with sensitive', async () => {
      expect(await actionsOf(superAdmin, '&action=banner.created')).toEqual(['banner.created']);
      expect(await actionsOf(superAdmin, '&action=banner.created&type=sensitive')).toEqual([]);
      expect(await actionsOf(superAdmin, '&action=role.access.changed&type=sensitive')).toEqual([
        'role.access.changed',
      ]);
    });

    it('dates: both days are included', async () => {
      expect(await actionsOf(superAdmin, '&from=2026-01-12&to=2026-01-14')).toEqual([
        'place-request.created',
        'banner.created',
      ]);
      expect(await actionsOf(superAdmin, '&from=2026-01-17')).toEqual(['onboarding.approved']);
    });

    it('search: person, action words, record name, reason and IP address', async () => {
      expect(await actionsOf(superAdmin, `&search=Anil Kumar ${runId}`)).toEqual([
        'banner.created',
      ]);
      expect(await actionsOf(superAdmin, '&search=downloaded')).toEqual(['catalogue.exported']);
      expect(await actionsOf(superAdmin, '&search=kondapur')).toEqual(['place-request.created']);
      expect(await actionsOf(superAdmin, '&search=diwali')).toEqual(['banner.created']);
      expect(await actionsOf(superAdmin, '&search=finance needs')).toEqual(['role.access.changed']);
      expect(await actionsOf(superAdmin, '&search=10.0.0.5')).toEqual(['onboarding.approved']);
      expect(await actionsOf(superAdmin, '&search=nothing-like-this')).toEqual([]);
      // a search with regular-expression characters is only text
      expect(await actionsOf(superAdmin, '&search=.*')).toEqual([]);
    });

    it('refuses an action the trail does not know and an unknown filter', async () => {
      await get(superAdmin, '/audit-logs?action=nothing.here').expect(400);
      await get(superAdmin, '/audit-logs?sort=sideways').expect(400);
    });

    it('offers the people and the actions that appear', async () => {
      const choices = dataOf<AuditFilterChoices>(await get(superAdmin, '/audit-logs/filters'));
      const names = choices.people.map((person) => person.name);
      expect(names).toEqual(
        expect.arrayContaining([`Priya Reddy ${runId}`, `Anil Kumar ${runId}`]),
      );
      expect(names).toEqual([...names].sort((a, b) => a.localeCompare(b)));
      expect(choices.actions).toEqual(
        expect.arrayContaining([
          { key: 'banner.created', label: 'Added a banner', sensitive: false },
          { key: 'role.access.changed', label: 'Changed role access', sensitive: true },
        ]),
      );
    });
  });

  describe('one entry', () => {
    it('shows who, role, action, target, IP and the change', async () => {
      const one = dataOf<AuditEntryView>(
        await get(superAdmin, `/audit-logs/${ids['roleChange']}`).expect(200),
      );
      expect(one).toMatchObject({
        id: ids['roleChange'],
        actionLabel: 'Changed role access',
        sensitive: true,
        ip: '10.0.0.1',
        before: { level: 'View' },
        after: { level: 'Edit' },
      });
    });

    it('is not found for an unknown id, and refused for a bad one', async () => {
      await get(superAdmin, `/audit-logs/${new Types.ObjectId().toHexString()}`).expect(404);
      await get(superAdmin, '/audit-logs/not-an-id').expect(400);
    });
  });

  describe("an operator's view", () => {
    it('shows only entries about its own records', async () => {
      expect(await actionsOf(operatorA)).toEqual(['onboarding.approved', 'place-request.created']);
      expect(await actionsOf(operatorB)).toEqual(['catalogue.exported']);
    });

    it('shows the Abra team instead of the name of a platform member', async () => {
      const [approved, request] = await list(operatorA);
      expect(approved).toMatchObject({ actorName: 'Abra team', actorRoleLabel: '' });
      expect(approved?.actor.userId).toBe('');
      expect(request).toMatchObject({ actorName: `Meena Travels Owner ${runId}` });
      expect(request?.actorRoleLabel).not.toBe('');
    });

    it("cannot open another operator's entry, and sees no platform people in the filters", async () => {
      await get(operatorB, `/audit-logs/${ids['placeRequest']}`).expect(404);
      const choices = dataOf<AuditFilterChoices>(await get(operatorA, '/audit-logs/filters'));
      expect(choices.people.map((person) => person.name)).not.toContain(`Priya Reddy ${runId}`);
      expect(choices.people.map((person) => person.name)).toContain(`Meena Travels Owner ${runId}`);
    });

    it('cannot widen what it sees with a filter', async () => {
      expect(await actionsOf(operatorA, `&operatorId=${operatorBId.toHexString()}`)).toEqual([]);
    });
  });

  describe('the download', () => {
    const text = (response: Response) => (response.body as Buffer).toString('utf8');

    it('is a CSV with the page columns and the same rows as the filters', async () => {
      const response = await file(
        superAdmin,
        `/audit-logs/export?entityType=${TYPE}&type=sensitive`,
      ).expect(200);
      expect(response.headers['content-type']).toMatch(/^text\/csv/);
      expect(response.headers['content-disposition']).toMatch(
        /^attachment; filename="audit-log-\d{4}-\d{2}-\d{2}\.csv"$/,
      );
      expect(text(response).startsWith(CSV_BOM)).toBe(true);
      const lines = text(response).replace(CSV_BOM, '').trim().split('\r\n');
      expect(lines[0]).toBe('When,Who,Role,Action,Sensitive,Target,Reason,IP address');
      expect(lines).toHaveLength(3);
      expect(text(response)).toContain('Changed role access');
      expect(text(response)).toContain('Finance needs it');
      expect(text(response)).not.toContain('Added a banner');
    });

    it('can be an Excel file', async () => {
      const response = await file(
        superAdmin,
        `/audit-logs/export?entityType=${TYPE}&format=xlsx`,
      ).expect(200);
      expect(response.headers['content-type']).toContain('spreadsheetml');
      const workbook = new Workbook();
      await workbook.xlsx.load(response.body as Buffer as never);
      expect(workbook.worksheets[0]?.rowCount).toBe(6);
    });

    it('is written in the audit log itself', async () => {
      const found = await context.connection
        .collection('audit_logs')
        .countDocuments({ action: 'catalogue.exported', entityType: 'audit-log' });
      expect(found).toBeGreaterThanOrEqual(2);
    });

    it('is only for people who may export the audit log', async () => {
      await file(admin, `/audit-logs/export?entityType=${TYPE}`).expect(200);
      // The operator's administrator can read its trail but not download it
      await file(operatorA, '/audit-logs/export').expect(403);
      await file(support, '/audit-logs/export').expect(403);
    });
  });

  describe('permissions', () => {
    it('lists, filters and details need audit.read', async () => {
      await get(support, '/audit-logs').expect(403);
      await get(support, '/audit-logs/filters').expect(403);
      await get(support, `/audit-logs/${ids['banner']}`).expect(403);
      await client(context).get(`${API}/audit-logs`).expect(401);
    });
  });
});
