import { Test } from '@nestjs/testing';
import { type INestApplicationContext } from '@nestjs/common';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
  uniqueEmail,
} from '../../modules/authentication/tests/auth-e2e.harness';
import { PermissionRegistry } from '../../modules/rbac/permissions/permission-registry';
import { type MyPermissions, seedUser } from '../../modules/rbac/tests/rbac-e2e.harness';
import { SuperAdminBootstrapModule } from '../super-admin-bootstrap.module';
import {
  BootstrapConfigurationError,
  SuperAdminBootstrapService,
} from '../super-admin-bootstrap.service';

const PASSWORD = 'first-admin-lantern-quartz';

const variables = (overrides: Record<string, string | undefined> = {}) => ({
  BOOTSTRAP_SUPER_ADMIN_EMAIL: uniqueEmail(),
  BOOTSTRAP_SUPER_ADMIN_NAME: 'First Administrator',
  BOOTSTRAP_SUPER_ADMIN_PASSWORD: PASSWORD,
  ...overrides,
});

/** The Super Admin bootstrap against the real MongoDB replica set. */
describe('Super Admin bootstrap e2e', () => {
  let context: AuthTestContext;
  let commandContext: INestApplicationContext;
  let bootstrap: SuperAdminBootstrapService;

  /** Ids of the accounts holding the SUPER_ADMIN role. */
  const superAdmins = async () => {
    const role = await context.connection.collection('roles').findOne({ key: 'SUPER_ADMIN' });
    return context.connection
      .collection<{ email: string; passwordHash: string }>('users')
      .find({ roleIds: role!._id })
      .toArray();
  };
  /** A fresh installation: no administrator yet. */
  const removeSuperAdmins = async () => {
    const role = await context.connection.collection('roles').findOne({ key: 'SUPER_ADMIN' });
    await context.connection.collection('users').deleteMany({ roleIds: role!._id });
    await context.connection.collection('system_markers').deleteMany({});
  };

  beforeAll(async () => {
    context = await createAuthTestApp();
    // The command's own module, as `npm run bootstrap:super-admin` builds it
    const moduleRef = await Test.createTestingModule({
      imports: [SuperAdminBootstrapModule],
    }).compile();
    commandContext = await moduleRef.init();
    bootstrap = commandContext.get(SuperAdminBootstrapService);
  }, 90_000);

  beforeEach(removeSuperAdmins);

  afterAll(async () => {
    await removeSuperAdmins();
    await commandContext.close();
    await context.close();
  }, 60_000);

  it('creates the first Super Admin, who can sign in and holds every permission', async () => {
    const input = variables();
    const outcome = await bootstrap.run(input);
    expect(outcome).toMatchObject({
      created: true,
      email: input.BOOTSTRAP_SUPER_ADMIN_EMAIL,
    });

    const [account, ...others] = await superAdmins();
    expect(others).toEqual([]);
    expect(account).toMatchObject({
      email: input.BOOTSTRAP_SUPER_ADMIN_EMAIL,
      name: 'First Administrator',
      userType: 'STAFF',
      status: 'ACTIVE',
      dataScope: { type: 'ALL', operatorIds: [] },
    });
    // Stored hashed, never as given
    expect(account!.passwordHash).toMatch(/^\$argon2id\$/);
    expect(JSON.stringify(account)).not.toContain(PASSWORD);

    const tokens = dataOf<Tokens>(
      await client(context)
        .post('/api/v1/auth/login')
        .send({ identifier: input.BOOTSTRAP_SUPER_ADMIN_EMAIL, password: PASSWORD })
        .expect(200),
    );
    const mine = dataOf<MyPermissions>(
      await client(context)
        .get('/api/v1/me/permissions')
        .set(...bearer(tokens))
        .expect(200),
    );
    expect(mine.roles.map((role) => role.key)).toEqual(['SUPER_ADMIN']);
    expect([...mine.permissions].sort()).toEqual([...PermissionRegistry.keys()].sort());
    expect(mine.dataScope.type).toBe('ALL');
    // And can use it: the catalogue is open to them
    await client(context)
      .get('/api/v1/catalogue/cities')
      .set(...bearer(tokens))
      .expect(200);
  });

  it('records the bootstrap in the audit trail without the password', async () => {
    const input = variables();
    const outcome = await bootstrap.run(input);
    if (!outcome.created) throw new Error('expected an account');
    const entries = await context.connection
      .collection('audit_logs')
      .find({ action: 'user.super-admin.bootstrapped' })
      .toArray();
    const entry = entries.find((found) => String(found.entityId) === outcome.userId);
    expect(entry).toMatchObject({
      entityType: 'user',
      actor: { userType: 'STAFF', roleKeys: ['SUPER_ADMIN'] },
      after: { email: input.BOOTSTRAP_SUPER_ADMIN_EMAIL, roleKeys: ['SUPER_ADMIN'] },
      reason: 'First administrator created by the bootstrap command',
    });
    expect(JSON.stringify(entry)).not.toContain(PASSWORD);
  });

  it('a second run creates nothing, with the same or with other details', async () => {
    const input = variables();
    await bootstrap.run(input);
    expect(await bootstrap.run(input)).toEqual({ created: false, reason: 'SUPER_ADMIN_EXISTS' });
    expect(await bootstrap.run(variables())).toEqual({
      created: false,
      reason: 'SUPER_ADMIN_EXISTS',
    });
    expect(await superAdmins()).toHaveLength(1);
  });

  it('does nothing when a Super Admin was created another way', async () => {
    await seedUser(context, { roleKeys: ['SUPER_ADMIN'] });
    expect(await bootstrap.run(variables())).toEqual({
      created: false,
      reason: 'SUPER_ADMIN_EXISTS',
    });
    expect(await superAdmins()).toHaveLength(1);
  });

  it('other administrators do not count: only the Super Admin role blocks the bootstrap', async () => {
    await seedUser(context, { roleKeys: ['ADMIN'] });
    expect((await bootstrap.run(variables())).created).toBe(true);
  });

  it('several runs at the same moment create exactly one account', async () => {
    const outcomes = await Promise.all([1, 2, 3, 4].map(() => bootstrap.run(variables())));
    expect(outcomes.filter((outcome) => outcome.created)).toHaveLength(1);
    expect(await superAdmins()).toHaveLength(1);
  }, 30_000);

  it('an email that already has an account is refused and nothing changes', async () => {
    const existing = await seedUser(context, { roleKeys: ['SUPPORT'] });
    await expect(
      bootstrap.run(variables({ BOOTSTRAP_SUPER_ADMIN_EMAIL: existing.email })),
    ).rejects.toMatchObject({ code: 'ALREADY_REGISTERED' });
    expect(await superAdmins()).toEqual([]);
    expect(
      await context.connection
        .collection('audit_logs')
        .countDocuments({ action: 'user.super-admin.bootstrapped', 'after.email': existing.email }),
    ).toBe(0);
  });

  it('missing or unacceptable configuration is rejected before anything is created', async () => {
    for (const input of [
      {},
      variables({ BOOTSTRAP_SUPER_ADMIN_PASSWORD: undefined }),
      variables({ BOOTSTRAP_SUPER_ADMIN_EMAIL: 'not-an-email' }),
      variables({ BOOTSTRAP_SUPER_ADMIN_PASSWORD: 'short' }),
    ]) {
      await expect(bootstrap.run(input)).rejects.toBeInstanceOf(BootstrapConfigurationError);
    }
    expect(await superAdmins()).toEqual([]);
  });

  it('no HTTP endpoint creates administrators', async () => {
    for (const path of ['/api/v1/bootstrap', '/api/v1/bootstrap/super-admin', '/api/v1/users']) {
      const response = await client(context).post(path).send(variables());
      expect([401, 404]).toContain(response.status);
    }
    expect(await superAdmins()).toEqual([]);
  });
});
