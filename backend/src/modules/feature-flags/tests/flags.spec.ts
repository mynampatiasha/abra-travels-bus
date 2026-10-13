import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import {
  appOfHeader,
  appOfUserType,
  AvailabilityGuard,
  DEFAULT_FLAGS,
  exemptFromMaintenance,
  FlagsAdminManageService,
  type Maintenance,
  maintenanceActive,
} from '../flags_admin_manage.service';

const scopes = (over: Partial<Maintenance['scopes']> = {}): Maintenance['scopes'] => ({
  global: false,
  customer: false,
  operator: false,
  partner: false,
  admin: false,
  ...over,
});
const NOW = new Date('2026-10-12T10:00:00Z');

describe('which app is it', () => {
  it('places signed-in people by their kind of account', () => {
    expect(appOfUserType('CUSTOMER')).toBe('customer');
    expect(appOfUserType('OPERATOR_STAFF')).toBe('operator');
    expect(appOfUserType('DRIVER')).toBe('operator');
    expect(appOfUserType('PARTNER_USER')).toBe('partner');
    expect(appOfUserType('STAFF')).toBe('admin');
  });

  it('places a request without a token by the X-Abra-App header', () => {
    expect(appOfHeader('customer')).toBe('customer');
    expect(appOfHeader('Website')).toBe('customer');
    expect(appOfHeader('driver')).toBe('operator');
    expect(appOfHeader('ADMIN')).toBe('admin');
    expect(appOfHeader('nonsense')).toBeUndefined();
    expect(appOfHeader(undefined)).toBeUndefined();
  });
});

describe('maintenanceActive', () => {
  it('a scope that is on stops its own app only', () => {
    const m = { scopes: scopes({ customer: true }), from: null, to: null };
    expect(maintenanceActive(m, 'customer', NOW)).toBe(true);
    expect(maintenanceActive(m, 'operator', NOW)).toBe(false);
    expect(maintenanceActive(m, 'admin', NOW)).toBe(false);
  });

  it('global stops the customer, operator and partner apps but never the admin portal', () => {
    const m = { scopes: scopes({ global: true }), from: null, to: null };
    expect(maintenanceActive(m, 'customer', NOW)).toBe(true);
    expect(maintenanceActive(m, 'operator', NOW)).toBe(true);
    expect(maintenanceActive(m, 'partner', NOW)).toBe(true);
    expect(maintenanceActive(m, 'admin', NOW)).toBe(false);
  });

  it('the admin portal has its own switch', () => {
    expect(
      maintenanceActive({ scopes: scopes({ admin: true }), from: null, to: null }, 'admin', NOW),
    ).toBe(true);
  });

  it('only counts inside the window, when there is one', () => {
    const on = scopes({ customer: true });
    const at = (from: string | null, to: string | null) => ({
      scopes: on,
      from: from ? new Date(from) : null,
      to: to ? new Date(to) : null,
    });
    expect(
      maintenanceActive(at('2026-10-12T09:00:00Z', '2026-10-12T11:00:00Z'), 'customer', NOW),
    ).toBe(true);
    expect(maintenanceActive(at('2026-10-12T11:00:00Z', null), 'customer', NOW)).toBe(false); // not started
    expect(maintenanceActive(at(null, '2026-10-12T09:00:00Z'), 'customer', NOW)).toBe(false); // ended
    expect(maintenanceActive(at(null, '2026-10-12T10:00:00Z'), 'customer', NOW)).toBe(false); // ends exactly now
    expect(maintenanceActive(at('2026-10-12T10:00:00Z', null), 'customer', NOW)).toBe(true); // starts exactly now
  });
});

describe('exemptFromMaintenance', () => {
  it.each([
    '/health/live',
    '/health/ready',
    '/maintenance/status',
    '/features',
    '/auth/login',
    '/auth/mfa/verify',
    '/auth/refresh',
    '/auth/logout',
  ])('keeps %s working', (path) => expect(exemptFromMaintenance(path)).toBe(true));
  it.each([
    '/trips/search',
    '/auth/otp/send',
    '/auth/register',
    '/admin/messages',
    '/customer/messages',
    '/health-check',
  ])('stops %s', (path) => expect(exemptFromMaintenance(path)).toBe(false));
});

describe('AvailabilityGuard', () => {
  const baseSnapshot = () => ({
    flags: Object.fromEntries(DEFAULT_FLAGS.map((f) => [f.key, f.on])) as Record<string, boolean>,
    maintenance: {
      scopes: scopes(),
      message: 'Back soon.',
      from: null as Date | null,
      to: null as Date | null,
    },
  });

  function build(
    options: {
      snapshot?: ReturnType<typeof baseSnapshot>;
      feature?: string;
      mayBypass?: boolean;
    } = {},
  ) {
    const snapshot = options.snapshot ?? baseSnapshot();
    const state = { snapshot: () => Promise.resolve(snapshot) };
    const reflector = { getAllAndOverride: () => options.feature };
    const permissions = {
      forActor: () =>
        Promise.resolve({
          hasWildcard: false,
          permissions: new Set(options.mayBypass ? ['maintenance.bypass'] : []),
        }),
    };
    const guard = new AvailabilityGuard(reflector as never, state as never, permissions as never);
    const run = (path: string, actor: { userType: string } | undefined, header?: string) => {
      const request = { path, headers: header ? { 'x-abra-app': header } : {} };
      const context = {
        getType: () => 'http',
        switchToHttp: () => ({ getRequest: () => request }),
        getHandler: () => ({}),
        getClass: () => ({}),
      };
      const withActor = actor
        ? {
            actorType: 'USER',
            userId: new Types.ObjectId().toHexString(),
            sessionId: 'sess1',
            ...actor,
          }
        : undefined;
      return RequestContextService.run(
        { requestId: 'r1', ...(withActor ? { actor: withActor as never } : {}) },
        () => guard.canActivate(context as never),
      );
    };
    return { run, snapshot };
  }

  it('lets everything through when nothing is on', async () => {
    const { run } = build();
    expect(await run('/customer/messages', { userType: 'CUSTOMER' })).toBe(true);
    expect(await run('/trips/search', undefined, 'customer')).toBe(true);
  });

  it('stops a signed-in customer with the message and the end time', async () => {
    const snapshot = baseSnapshot();
    snapshot.maintenance.scopes.customer = true;
    snapshot.maintenance.to = new Date('2099-01-01T00:00:00Z');
    const { run } = build({ snapshot });
    const error = await run('/customer/messages', { userType: 'CUSTOMER' }).catch(
      (e: unknown) => e as ApiException,
    );
    expect(error).toBeInstanceOf(ApiException);
    expect(error).toMatchObject({
      code: 'MAINTENANCE_MODE',
      message: 'Back soon.',
      details: { app: 'customer', until: '2099-01-01T00:00:00.000Z' },
    });
  });

  it('stops a request without a token by its header, and lets the exempt paths through', async () => {
    const snapshot = baseSnapshot();
    snapshot.maintenance.scopes.global = true;
    const { run } = build({ snapshot });
    await expect(run('/trips/search', undefined, 'customer')).rejects.toMatchObject({
      code: 'MAINTENANCE_MODE',
    });
    expect(await run('/health/live', undefined, 'customer')).toBe(true);
    expect(await run('/features', undefined, 'customer')).toBe(true);
    expect(await run('/auth/login', undefined, 'customer')).toBe(true);
    expect(await run('/trips/search', undefined)).toBe(true); // no header, no token: unknown app
    expect(await run('/trips/search', undefined, 'admin')).toBe(true); // admin is not in global
  });

  it('global never stops staff', async () => {
    const snapshot = baseSnapshot();
    snapshot.maintenance.scopes.global = true;
    const { run } = build({ snapshot });
    expect(await run('/admin/messages', { userType: 'STAFF' })).toBe(true);
    await expect(run('/customer/messages', { userType: 'CUSTOMER' })).rejects.toMatchObject({
      code: 'MAINTENANCE_MODE',
    });
    await expect(run('/client/trips', { userType: 'OPERATOR_STAFF' })).rejects.toMatchObject({
      code: 'MAINTENANCE_MODE',
    });
  });

  it('admin maintenance stops staff without the bypass permission, not those with it', async () => {
    const snapshot = baseSnapshot();
    snapshot.maintenance.scopes.admin = true;
    await expect(
      build({ snapshot }).run('/admin/messages', { userType: 'STAFF' }),
    ).rejects.toMatchObject({ code: 'MAINTENANCE_MODE' });
    expect(
      await build({ snapshot, mayBypass: true }).run('/admin/messages', { userType: 'STAFF' }),
    ).toBe(true);
  });

  it('a customer is never let in by the staff bypass', async () => {
    const snapshot = baseSnapshot();
    snapshot.maintenance.scopes.customer = true;
    await expect(
      build({ snapshot, mayBypass: true }).run('/customer/messages', { userType: 'CUSTOMER' }),
    ).rejects.toMatchObject({
      code: 'MAINTENANCE_MODE',
    });
  });

  it('refuses an endpoint whose feature is switched off, with a sentence', async () => {
    const snapshot = baseSnapshot();
    snapshot.flags.live_tracking = false;
    const { run } = build({ snapshot, feature: 'live_tracking' });
    await expect(run('/customer/tracking', { userType: 'CUSTOMER' })).rejects.toMatchObject({
      code: 'SERVICE_UNAVAILABLE',
      message: 'This feature is switched off right now.',
      details: { feature: 'live_tracking' },
    });
    expect(
      await build({ feature: 'live_tracking' }).run('/customer/tracking', { userType: 'CUSTOMER' }),
    ).toBe(true);
  });
});

describe('FlagsAdminManageService', () => {
  const actor = { userId: new Types.ObjectId().toHexString() } as never;
  const client = {} as never;
  function build(stored: Partial<Maintenance> | null = null) {
    const maintenance = {
      findOne: () => ({ lean: () => ({ exec: () => Promise.resolve(stored) }) }),
    };
    const changes = { run: jest.fn() };
    const service = new FlagsAdminManageService(
      {} as never,
      maintenance as never,
      { invalidate: jest.fn() } as never,
      changes as never,
    );
    return { service, changes };
  }

  it('refuses an empty change and an end before the start, before touching anything', async () => {
    const { service, changes } = build();
    await expect(service.changeMaintenance(actor, { reason: 'x y z' }, client)).rejects.toThrow(
      'Nothing to change',
    );
    await expect(
      service.changeMaintenance(
        actor,
        {
          from: new Date('2026-10-12T12:00:00Z'),
          to: new Date('2026-10-12T11:00:00Z'),
          reason: 'test',
        },
        client,
      ),
    ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    expect(changes.run).not.toHaveBeenCalled();
  });

  it('checks a new end against the stored start', async () => {
    const { service } = build({
      scopes: scopes(),
      message: 'm',
      from: new Date('2026-10-12T12:00:00Z'),
      to: null,
    });
    await expect(
      service.changeMaintenance(
        actor,
        { to: new Date('2026-10-12T11:00:00Z'), reason: 'test' },
        client,
      ),
    ).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
    });
  });

  it('refuses a feature that does not exist', async () => {
    const { service } = build();
    await expect(
      service.setFlag(actor, 'nonsense' as never, true, 'test', client),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
  });

  it('the defaults are the nine switches of the demo', () => {
    expect(DEFAULT_FLAGS.map((f) => f.key)).toEqual([
      'live_tracking',
      'whatsapp_chatbot',
      'ai_support',
      'women_safety',
      'partner_api',
      'dynamic_pricing',
      'mobile_app',
      'driver_app',
      'advanced_analytics',
    ]);
    expect(DEFAULT_FLAGS.filter((f) => f.on).map((f) => f.key)).toEqual([
      'live_tracking',
      'women_safety',
      'mobile_app',
      'driver_app',
    ]);
  });
});
