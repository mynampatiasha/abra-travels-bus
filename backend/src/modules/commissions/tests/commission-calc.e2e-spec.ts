import { bearer, client, dataOf } from '../../authentication/tests/auth-e2e.harness';
import { CSV_BOM } from '../../catalogue-shared/catalogue_export_manage.service';
import { CommissionService, type CommissionHistoryView } from '../commission_admin_manage.service';
import { API, binary, commissionFixture, inDays } from './commission-e2e.harness';

/** The commission page: the price calculator, the history and the audit trail, pick-lists and the download. */
describe('Commission calculator and history e2e', () => {
  const fx = commissionFixture();
  const { send, created, calculate, resetRules, operator, otherOperator, route, busType } = fx;

  // The calculator needs a default commission and the Payout and fees settings, as in real use
  beforeAll(async () => {
    await send(fx.superAdmin, 'put', '/default', { mode: 'PERCENT', value: 1000 }).expect(200);
    await fx.context.connection
      .collection('payout_settings')
      .insertOne({ gstPct: 18, convenienceFee: 4900 });
  });

  describe('the price calculator', () => {
    beforeEach(resetRules);

    it('uses the operator rule and works out all seven amounts', async () => {
      const made = await created();
      const result = dataOf<{
        rule: { ruleId: string; scope: string; commission: string };
        amounts: Record<string, number>;
        ruleCopy: { ruleId: string; version: number; value: number };
      }>(await calculate().expect(201));
      expect(result.rule).toMatchObject({ ruleId: made.id, scope: 'OPERATOR', commission: '12%' });
      expect(result.amounts).toEqual({
        operatorFare: 240_000,
        commission: 28_800,
        fareShown: 268_800,
        gst: 48_384,
        convenienceFee: 4900,
        customerPays: 322_084,
        operatorReceives: 240_000,
      });
      expect(result.ruleCopy).toMatchObject({ ruleId: made.id, version: 1, value: 1200 });
    });

    it('goes operator, then route, then bus type, then the default', async () => {
      const ids = {
        operatorId: operator.id.toHexString(),
        routeId: route.id.toHexString(),
        busTypeId: busType.id.toHexString(),
      };
      const used = async (body: Record<string, unknown>) =>
        dataOf<{ rule: { scope: string } }>(await calculate(body).expect(201)).rule.scope;
      expect(await used(ids)).toBe('DEFAULT');
      const bus = await created({ scope: 'BUS_TYPE', targetId: ids.busTypeId, value: 1100 });
      expect(await used(ids)).toBe('BUS_TYPE');
      const routeRule = await created({ scope: 'ROUTE', targetId: ids.routeId, value: 1300 });
      expect(await used(ids)).toBe('ROUTE');
      const operatorRule = await created({ value: 900 });
      expect(await used(ids)).toBe('OPERATOR');
      // a rule that is switched off is skipped
      await send(fx.superAdmin, 'patch', `/rules/${operatorRule.id}/active`, {
        active: false,
      }).expect(200);
      expect(await used(ids)).toBe('ROUTE');
      await send(fx.superAdmin, 'delete', `/rules/${routeRule.id}`).expect(200);
      expect(await used(ids)).toBe('BUS_TYPE');
      expect(bus.id).toMatch(/^CR-/);
    });

    it('a version dated later is not used before its day, and a rule not started is skipped', async () => {
      const made = await created();
      await send(fx.superAdmin, 'post', `/rules/${made.id}/versions`, {
        mode: 'PERCENT',
        value: 2000,
        effectiveFrom: inDays(7),
      }).expect(201);
      const service = fx.context.app.get(CommissionService);
      const input = { farePerSeatPaise: 100_000, seats: 1, operatorId: operator.id.toHexString() };
      expect((await service.calculate(input)).rule).toMatchObject({ version: 1, value: 1200 });
      expect((await service.calculate({ ...input, onDay: inDays(8) })).rule).toMatchObject({
        version: 2,
        value: 2000,
      });

      await resetRules();
      await created({ effectiveFrom: inDays(3) });
      // the only rule starts in 3 days: today the default applies
      expect((await service.calculate(input)).rule.scope).toBe('DEFAULT');
    });

    it('checks its input', async () => {
      expect((await calculate({ seats: 7 })).status).toBe(400);
      expect((await calculate({ seats: 0 })).status).toBe(400);
      expect((await calculate({ farePerSeatPaise: -1 })).status).toBe(400);
      expect((await calculate({ operatorId: 'nope' })).status).toBe(400);
    });

    it('refuses until the Payout and fees settings exist', async () => {
      await fx.context.connection.collection('payout_settings').deleteMany({});
      const refused = await calculate();
      expect(refused.status).toBe(400);
      expect(JSON.stringify(refused.body)).toMatch(/Payout and fees/);
      await fx.context.connection
        .collection('payout_settings')
        .insertOne({ gstPct: 18, convenienceFee: 4900 });
    });
  });

  describe('history, audit, pick-lists and the download', () => {
    beforeAll(resetRules);

    it('lists who changed what, newest first, and writes sensitive audit entries', async () => {
      const made = await created();
      await send(fx.superAdmin, 'post', `/rules/${made.id}/versions`, {
        mode: 'PERCENT',
        value: 1500,
        effectiveFrom: inDays(2),
      }).expect(201);
      await send(fx.admin, 'patch', `/rules/${made.id}/active`, { active: false }).expect(200);
      const history = dataOf<CommissionHistoryView[]>(
        await send(fx.superAdmin, 'get', '/history').expect(200),
      );
      const mine = history.filter((row) => row.ruleId === made.id).map((row) => row.label);
      expect(mine).toEqual([
        `${made.id}: Deactivated`,
        `${made.id}: Edited to v2`,
        `${made.id}: Created`,
      ]);
      expect(history[0]?.who).toBeTruthy();

      const audit = await client(fx.context)
        .get('/api/v1/audit-logs?entityType=commission-rule&type=sensitive&pageSize=100')
        .set(...bearer(fx.superAdmin.tokens))
        .expect(200);
      const entries =
        dataOf<Array<{ action: string; actionLabel: string; sensitive: boolean }>>(audit);
      expect(entries.map((entry) => entry.action)).toEqual(
        expect.arrayContaining([
          'commission.rule.created',
          'commission.rule.versioned',
          'commission.rule.deactivated',
        ]),
      );
      expect(entries.every((entry) => entry.sensitive)).toBe(true);
      expect(entries.find((entry) => entry.action === 'commission.rule.created')?.actionLabel).toBe(
        'Created a commission rule',
      );
    });

    it('lists the operators, routes and bus types to pick from', async () => {
      const names = async (scope: string, search = '') =>
        dataOf<Array<{ id: string; name: string }>>(
          await send(fx.superAdmin, 'get', `/targets?scope=${scope}${search}`).expect(200),
        ).map((item) => item.name);
      expect(await names('OPERATOR')).toEqual(
        expect.arrayContaining([operator.name, otherOperator.name]),
      );
      expect(await names('OPERATOR', '&search=kaveri')).toEqual([operator.name]);
      expect(await names('ROUTE')).toContain(route.name);
      expect(await names('BUS_TYPE')).toContain(busType.name);
      await send(fx.superAdmin, 'get', '/targets?scope=NOPE').expect(400);
    });

    it('downloads the rules the filters show, as CSV, and records the download', async () => {
      await resetRules();
      const made = await created();
      const response = await client(fx.context)
        .get(`${API}/rules/export?scope=OPERATOR`)
        .set(...bearer(fx.superAdmin.tokens))
        .buffer(true)
        .parse(binary as never)
        .expect(200);
      expect(response.headers['content-type']).toMatch(/^text\/csv/);
      const text = (response.body as Buffer).toString('utf8');
      expect(text.startsWith(CSV_BOM)).toBe(true);
      const lines = text.replace(CSV_BOM, '').trim().split('\r\n');
      expect(lines[0]).toBe(
        'ID,Applies to,Target,Commission,Effective from,Version,Status,Agreed note',
      );
      expect(lines[1]).toContain(`${made.id},Operator,${operator.name},12%`);
      expect(lines).toHaveLength(2);
      const recorded = await fx.context.connection
        .collection('audit_logs')
        .countDocuments({ action: 'catalogue.exported', entityType: 'commission-rules' });
      expect(recorded).toBeGreaterThanOrEqual(1);
      await client(fx.context)
        .get(`${API}/rules/export`)
        .set(...bearer(fx.support.tokens))
        .expect(403);
    });
  });
});
