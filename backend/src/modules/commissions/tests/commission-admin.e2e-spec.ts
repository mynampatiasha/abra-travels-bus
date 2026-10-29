import { Types } from 'mongoose';
import { client, dataOf, errorCodeOf } from '../../authentication/tests/auth-e2e.harness';
import {
  type CommissionDefaultView,
  type CommissionHistoryView,
  type CommissionRuleView,
  todayIst,
} from '../commission_admin_manage.service';
import { API, commissionFixture, inDays } from './commission-e2e.harness';

/** The commission page: who can use it, the default, and the rules with their versions. */
describe('Commission admin e2e', () => {
  const fx = commissionFixture();
  const { send, rule, created, calculate, resetRules, operator, otherOperator, route, busType } =
    fx;

  describe('who can use it', () => {
    it('Super Admin and Admin use it; Support and a signed-out caller do not', async () => {
      await send(fx.superAdmin, 'get', '/rules').expect(200);
      await send(fx.admin, 'get', '/rules').expect(200);
      await send(fx.support, 'get', '/rules').expect(403);
      await send(fx.support, 'post', '/rules', rule()).expect(403);
      await send(fx.support, 'get', '/history').expect(403);
      await client(fx.context).get(`${API}/rules`).expect(401);
    });
  });

  describe('the default commission', () => {
    it('is not saved until someone saves it, and nothing is assumed meanwhile', async () => {
      const view = dataOf<CommissionDefaultView>(
        await send(fx.superAdmin, 'get', '/default').expect(200),
      );
      expect(view).toMatchObject({ configured: false, mode: null, value: null });
      await fx.context.connection
        .collection('payout_settings')
        .insertOne({ gstPct: 18, convenienceFee: 4900 });
      const refused = await calculate({ operatorId: undefined });
      expect(refused.status).toBe(400);
      expect(JSON.stringify(refused.body)).toMatch(/default commission/i);
    });

    it('takes 0 to 40 per cent and a flat amount, and keeps a history row', async () => {
      await send(fx.superAdmin, 'put', '/default', { mode: 'PERCENT', value: 4100 }).expect(400);
      await send(fx.superAdmin, 'put', '/default', { mode: 'PERCENT', value: 4000 }).expect(200);
      const saved = dataOf<CommissionDefaultView>(
        await send(fx.superAdmin, 'put', '/default', { mode: 'PERCENT', value: 1000 }).expect(200),
      );
      expect(saved).toMatchObject({
        configured: true,
        mode: 'PERCENT',
        value: 1000,
        commission: '10%',
      });
      const history = dataOf<CommissionHistoryView[]>(
        await send(fx.superAdmin, 'get', '/history').expect(200),
      );
      expect(history.filter((row) => row.ruleId === 'Default')).toHaveLength(2);
    });

    it('only staff who may manage can change it', async () => {
      await send(fx.support, 'put', '/default', { mode: 'PERCENT', value: 1000 }).expect(403);
    });
  });

  describe('rules', () => {
    beforeEach(resetRules);

    it('a new rule is Active, version 1, with an id like CR-1', async () => {
      const made = await created();
      expect(made).toMatchObject({
        scope: 'OPERATOR',
        targetName: operator.name,
        commission: '12%',
        version: 1,
        status: 'ACTIVE',
        agreedNote: 'Agreed on a call',
      });
      expect(made.id).toMatch(/^CR-\d+$/);
      expect(made.effectiveFrom).toBe(todayIst());
    });

    it('refuses a value out of range, a past date, a long note and an unknown target', async () => {
      expect((await send(fx.superAdmin, 'post', '/rules', rule({ value: 4001 }))).status).toBe(400);
      expect(
        (await send(fx.superAdmin, 'post', '/rules', rule({ effectiveFrom: inDays(-1) }))).status,
      ).toBe(400);
      expect(
        (await send(fx.superAdmin, 'post', '/rules', rule({ agreedNote: 'x'.repeat(301) }))).status,
      ).toBe(400);
      const unknown = await send(
        fx.superAdmin,
        'post',
        '/rules',
        rule({ targetId: new Types.ObjectId().toHexString() }),
      );
      expect(unknown.status).toBe(400);
      expect((await send(fx.superAdmin, 'post', '/rules', rule({ scope: 'REGION' }))).status).toBe(
        400,
      );
    });

    it('allows one active rule for a target: a second is refused with a sentence', async () => {
      const first = await created();
      const second = await send(fx.superAdmin, 'post', '/rules', rule({ value: 900 }));
      expect(second.status).toBe(409);
      expect(errorCodeOf(second)).toBe('ALREADY_REGISTERED');
      expect(JSON.stringify(second.body)).toContain(first.id);
      // another operator is a different target
      await created({ targetId: otherOperator.id.toHexString() });
    });

    it('two admins pressing Save at the same moment get one rule and one refusal', async () => {
      const results = await Promise.all([
        send(fx.superAdmin, 'post', '/rules', rule()),
        send(fx.admin, 'post', '/rules', rule()),
      ]);
      expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    });

    it('a change is a new version: the table shows v2, the old version is kept', async () => {
      const made = await created();
      const changed = dataOf<CommissionRuleView>(
        await send(fx.superAdmin, 'post', `/rules/${made.id}/versions`, {
          mode: 'PERCENT',
          value: 1400,
          effectiveFrom: inDays(7),
          agreedNote: 'Renewed',
        }).expect(201),
      );
      expect(changed).toMatchObject({ version: 2, commission: '14%', effectiveFrom: inDays(7) });
      const one = dataOf<CommissionRuleView>(
        await send(fx.superAdmin, 'get', `/rules/${made.id}`).expect(200),
      );
      expect(one.versions?.map((item) => item.version)).toEqual([2, 1]);
      expect(
        (
          await send(fx.superAdmin, 'post', `/rules/${made.id}/versions`, {
            mode: 'PERCENT',
            value: 1400,
            effectiveFrom: inDays(-1),
          })
        ).status,
      ).toBe(400);
    });

    it('switches off and on; switching on is refused while another rule is active for the target', async () => {
      const first = await created();
      await send(fx.superAdmin, 'patch', `/rules/${first.id}/active`, { active: false }).expect(
        200,
      );
      const second = await created({ value: 800 });
      const refused = await send(fx.superAdmin, 'patch', `/rules/${first.id}/active`, {
        active: true,
      });
      expect(refused.status).toBe(409);
      await send(fx.superAdmin, 'patch', `/rules/${second.id}/active`, { active: false }).expect(
        200,
      );
      const on = dataOf<CommissionRuleView>(
        await send(fx.superAdmin, 'patch', `/rules/${first.id}/active`, { active: true }).expect(
          200,
        ),
      );
      expect(on.status).toBe('ACTIVE');
    });

    it('deletes and undoes; the undo does not push out a rule that took its place', async () => {
      const first = await created();
      await send(fx.superAdmin, 'delete', `/rules/${first.id}`).expect(200);
      expect((await send(fx.superAdmin, 'get', `/rules/${first.id}`)).status).toBe(404);
      const list = dataOf<CommissionRuleView[]>(
        await send(fx.superAdmin, 'get', '/rules').expect(200),
      );
      expect(list).toHaveLength(0);

      const back = dataOf<{ status: string; restoredInactive: boolean }>(
        await send(fx.superAdmin, 'post', `/rules/${first.id}/restore`).expect(201),
      );
      expect(back).toMatchObject({ status: 'ACTIVE', restoredInactive: false });

      await send(fx.superAdmin, 'delete', `/rules/${first.id}`).expect(200);
      const replacement = await created({ value: 700 });
      const second = dataOf<{ status: string; restoredInactive: boolean }>(
        await send(fx.superAdmin, 'post', `/rules/${first.id}/restore`).expect(201),
      );
      expect(second).toMatchObject({ status: 'INACTIVE', restoredInactive: true });
      expect(
        dataOf<CommissionRuleView>(await send(fx.superAdmin, 'get', `/rules/${replacement.id}`))
          .status,
      ).toBe('ACTIVE');
    });

    it('Delete and Undo need the delete permission, which Admin has and Support lacks', async () => {
      const made = await created();
      await send(fx.support, 'delete', `/rules/${made.id}`).expect(403);
      await send(fx.admin, 'delete', `/rules/${made.id}`).expect(200);
    });

    it('lists with filters, search and paging', async () => {
      await created();
      await created({
        scope: 'ROUTE',
        targetId: route.id.toHexString(),
        value: 1100,
        agreedNote: 'High demand',
      });
      const bus = await created({
        scope: 'BUS_TYPE',
        targetId: busType.id.toHexString(),
        mode: 'FLAT',
        value: 6000,
      });
      await send(fx.superAdmin, 'patch', `/rules/${bus.id}/active`, { active: false }).expect(200);

      const ids = async (query: string) =>
        dataOf<CommissionRuleView[]>(
          await send(fx.superAdmin, 'get', `/rules${query}`).expect(200),
        ).map((item) => item.scope);
      expect(await ids('')).toEqual(['OPERATOR', 'ROUTE', 'BUS_TYPE']);
      expect(await ids('?scope=ROUTE')).toEqual(['ROUTE']);
      expect(await ids('?status=INACTIVE')).toEqual(['BUS_TYPE']);
      expect(await ids('?search=high%20demand')).toEqual(['ROUTE']);
      expect(await ids('?search=kaveri')).toEqual(['OPERATOR']);
      expect(await ids('?search=.*')).toEqual([]);
      const paged = await send(fx.superAdmin, 'get', '/rules?pageSize=2&page=2').expect(200);
      expect(dataOf<unknown[]>(paged)).toHaveLength(1);
      expect((paged.body as { meta: { total: number } }).meta.total).toBe(3);
      await send(fx.superAdmin, 'get', '/rules?scope=NOPE').expect(400);
    });

    it('reads one rule by its id, and says no for a missing or malformed id', async () => {
      await send(fx.superAdmin, 'get', '/rules/CR-999999').expect(404);
      await send(fx.superAdmin, 'get', '/rules/not-an-id').expect(400);
    });
  });
});
