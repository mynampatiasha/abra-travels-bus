import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  type AuthenticatedUserActor,
  type DataScope,
  type RequestActor,
  systemActor,
  type UserActor,
} from '../../../common/request-context/request-actor';
import { type StoredUser } from '../../users/repositories/user.repository';
import { type UsersService } from '../../users/services/users.service';
import { type PermissionOverrideRepository } from '../repositories/permission-override.repository';
import { type RoleRepository, type StoredRole } from '../repositories/role.repository';
import { SYSTEM_ROLES } from '../roles/system-roles';
import { type OverrideEffect } from '../schemas/permission-override.schema';
import { AuthorizationService } from '../services/authorization.service';
import { EffectivePermissionsService } from '../services/effective-permissions.service';

const OPERATOR_A = new Types.ObjectId();
const OPERATOR_B = new Types.ObjectId();

const STORED_ROLES: StoredRole[] = SYSTEM_ROLES.map((role) => ({
  ...role,
  permissionKeys: [...role.permissionKeys],
  isSystemRole: true,
  _id: new Types.ObjectId(),
}));

function roleId(key: string): Types.ObjectId {
  const role = STORED_ROLES.find((candidate) => candidate.key === key);
  if (!role) throw new Error(`role ${key} missing`);
  return role._id;
}

interface Fixture {
  users: Map<string, StoredUser>;
  overrides: Array<{ userId: string; permissionKey: string; effect: OverrideEffect }>;
  lookups: { users: number };
}

function setup() {
  const fixture: Fixture = { users: new Map(), overrides: [], lookups: { users: 0 } };
  const users = {
    findById: (id: string) => {
      fixture.lookups.users++;
      return Promise.resolve(fixture.users.get(id) ?? null);
    },
  } as unknown as UsersService;
  const roles = {
    findByIds: (ids: Types.ObjectId[]) =>
      Promise.resolve(STORED_ROLES.filter((role) => ids.some((id) => id.equals(role._id)))),
    findByKeys: (keys: string[]) =>
      Promise.resolve(STORED_ROLES.filter((role) => keys.includes(role.key))),
  } as unknown as RoleRepository;
  const overrides = {
    findForUser: (userId: Types.ObjectId) =>
      Promise.resolve(
        fixture.overrides.filter((override) => override.userId === userId.toHexString()),
      ),
  } as unknown as PermissionOverrideRepository;
  const effective = new EffectivePermissionsService(users, roles, overrides);
  const authorization = new AuthorizationService(effective);

  const addUser = (
    roleKeys: string[],
    overridesOf: Partial<StoredUser> = {},
  ): { user: StoredUser; actor: AuthenticatedUserActor } => {
    const user: StoredUser = {
      _id: new Types.ObjectId(),
      userType: 'OPERATOR_STAFF',
      roleIds: roleKeys.map(roleId),
      operatorId: OPERATOR_A,
      dataScope: { type: 'OWN_OPERATOR', operatorIds: [OPERATOR_A] },
      status: 'ACTIVE',
      permissionVersion: 1,
      mfa: { enabled: false, recoveryCodeHashes: [] },
      preferredLanguage: 'en',
      ...overridesOf,
    };
    fixture.users.set(user._id.toHexString(), user);
    return { user, actor: actorOf(user) };
  };
  return { fixture, authorization, effective, addUser };
}

function actorOf(user: StoredUser, dataScope?: DataScope): AuthenticatedUserActor {
  return {
    actorType: 'USER',
    userId: user._id.toHexString(),
    dataScope: dataScope ?? {
      type: user.dataScope.type,
      operatorIds: user.dataScope.operatorIds.map((id) => id.toHexString()),
    },
    userType: user.userType,
    sessionId: 'session',
    permissionVersion: user.permissionVersion,
    roleIds: user.roleIds.map((id) => id.toHexString()),
    mfaEnrollmentPending: false,
  };
}

async function codeOf(work: Promise<unknown>): Promise<string | undefined> {
  try {
    await work;
    return undefined;
  } catch (error) {
    if (error instanceof ApiException) return error.code;
    throw error;
  }
}

describe('AuthorizationService', () => {
  it('allows a permission the role grants and refuses one it does not', async () => {
    const { authorization, addUser } = setup();
    const { actor } = addUser(['BOOKING_STAFF']);
    await expect(authorization.can(actor, 'bookings.cancel')).resolves.toBe(true);
    await expect(authorization.can(actor, 'settlements.read')).resolves.toBe(false);
    expect(await codeOf(authorization.require(actor, 'bookings.cancel'))).toBeUndefined();
    expect(await codeOf(authorization.require(actor, 'settlements.read'))).toBe(
      'PERMISSION_DENIED',
    );
  });

  it('applies user overrides: DENY removes, ALLOW adds', async () => {
    const { authorization, addUser, fixture } = setup();
    const { actor, user } = addUser(['BOOKING_STAFF']);
    fixture.overrides.push(
      { userId: user._id.toHexString(), permissionKey: 'bookings.cancel', effect: 'DENY' },
      { userId: user._id.toHexString(), permissionKey: 'reports.read', effect: 'ALLOW' },
    );
    await expect(authorization.can(actor, 'bookings.cancel')).resolves.toBe(false);
    await expect(authorization.can(actor, 'reports.read')).resolves.toBe(true);
    await expect(authorization.can(actor, 'bookings.read')).resolves.toBe(true);
  });

  it('customers hold the CUSTOMER role implicitly', async () => {
    const { authorization, addUser } = setup();
    const { actor } = addUser([], {
      userType: 'CUSTOMER',
      dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
    });
    await expect(authorization.can(actor, 'bookings.create')).resolves.toBe(true);
    await expect(authorization.can(actor, 'users.read')).resolves.toBe(false);
  });

  describe('fail closed', () => {
    it('unknown permission key → no, for everyone including SUPER_ADMIN and SYSTEM', async () => {
      const { authorization, addUser } = setup();
      const { actor } = addUser(['SUPER_ADMIN'], {
        userType: 'STAFF',
        dataScope: { type: 'ALL', operatorIds: [] },
      });
      for (const key of ['bookings.destroy', '*', '', 'BOOKINGS.READ']) {
        await expect(authorization.can(actor, key)).resolves.toBe(false);
        await expect(authorization.can(systemActor('job'), key)).resolves.toBe(false);
        expect(await codeOf(authorization.require(actor, key))).toBe('PERMISSION_DENIED');
      }
    });

    it('no actor, or an actor that was not authenticated by a token → no', async () => {
      const { authorization } = setup();
      const plain: UserActor = {
        actorType: 'USER',
        userId: 'someone',
        dataScope: { type: 'ALL', operatorIds: [] },
      };
      for (const actor of [undefined, plain] as Array<RequestActor | undefined>) {
        await expect(authorization.can(actor, 'bookings.read')).resolves.toBe(false);
        expect(await codeOf(authorization.require(actor, 'bookings.read'))).toBe(
          'PERMISSION_DENIED',
        );
      }
    });

    it('a staff account without any role has no permissions', async () => {
      const { authorization, addUser } = setup();
      const { actor } = addUser([]);
      await expect(authorization.can(actor, 'bookings.read')).resolves.toBe(false);
    });

    it('a role id that no longer exists grants nothing', async () => {
      const { authorization, addUser, fixture } = setup();
      const { user, actor } = addUser(['BOOKING_STAFF']);
      fixture.users.set(user._id.toHexString(), { ...user, roleIds: [new Types.ObjectId()] });
      await expect(authorization.can(actor, 'bookings.read')).resolves.toBe(false);
    });

    it('a user that no longer exists has no permissions', async () => {
      const { authorization, addUser, fixture } = setup();
      const { user, actor } = addUser(['BOOKING_STAFF']);
      fixture.users.delete(user._id.toHexString());
      await expect(authorization.can(actor, 'bookings.read')).resolves.toBe(false);
    });
  });

  it('a SYSTEM actor (background job) is allowed known permissions on any resource', async () => {
    const { authorization } = setup();
    const system = systemActor('settlement job');
    await expect(authorization.can(system, 'settlements.read')).resolves.toBe(true);
    await expect(
      authorization.can(system, 'settlements.read', { operatorId: OPERATOR_B.toHexString() }),
    ).resolves.toBe(true);
  });

  describe('permission and data scope together', () => {
    it('Operator A staff may act on Operator A records only', async () => {
      const { authorization, addUser } = setup();
      const { actor } = addUser(['BOOKING_STAFF']);
      const own = { operatorId: OPERATOR_A.toHexString() };
      const other = { operatorId: OPERATOR_B.toHexString() };

      await expect(authorization.can(actor, 'bookings.read', own)).resolves.toBe(true);
      await expect(authorization.can(actor, 'bookings.read', other)).resolves.toBe(false);
      expect(await codeOf(authorization.require(actor, 'bookings.read', own))).toBeUndefined();
      // A record of another operator looks like it does not exist
      expect(await codeOf(authorization.require(actor, 'bookings.read', other))).toBe(
        'RESOURCE_NOT_FOUND',
      );
      expect(
        await codeOf(
          authorization.require(actor, 'bookings.create', other, { outOfScope: 'forbid' }),
        ),
      ).toBe('PERMISSION_DENIED');
    });

    it('being in scope does not help without the permission', async () => {
      const { authorization, addUser } = setup();
      const { actor } = addUser(['BOOKING_STAFF']);
      const own = { operatorId: OPERATOR_A.toHexString() };
      await expect(authorization.can(actor, 'settlements.read', own)).resolves.toBe(false);
      // Missing permission is always 403, never 404
      expect(await codeOf(authorization.require(actor, 'settlements.read', own))).toBe(
        'PERMISSION_DENIED',
      );
    });

    it('a resource without ownership facts is out of scope for a scoped actor', async () => {
      const { authorization, addUser } = setup();
      const { actor } = addUser(['BOOKING_STAFF']);
      await expect(authorization.can(actor, 'bookings.read', {})).resolves.toBe(false);
    });
  });

  describe('cache', () => {
    it('reuses the result for the same permission version and reloads after a change', async () => {
      const { authorization, addUser, fixture } = setup();
      const { actor, user } = addUser(['BOOKING_STAFF']);
      await authorization.can(actor, 'bookings.read');
      await authorization.can(actor, 'bookings.cancel');
      expect(fixture.lookups.users).toBe(1);

      // An administrator denies a permission: the change bumps permissionVersion
      fixture.overrides.push({
        userId: user._id.toHexString(),
        permissionKey: 'bookings.cancel',
        effect: 'DENY',
      });
      const changed = { ...user, permissionVersion: 2 };
      fixture.users.set(user._id.toHexString(), changed);
      await expect(authorization.can(actorOf(changed), 'bookings.cancel')).resolves.toBe(false);
      expect(fixture.lookups.users).toBe(2);
    });

    it('does not cache when the stored version differs from the actor’s', async () => {
      const { authorization, addUser, fixture } = setup();
      const { actor, user } = addUser(['BOOKING_STAFF']);
      fixture.users.set(user._id.toHexString(), { ...user, permissionVersion: 5 });
      await authorization.can(actor, 'bookings.read');
      await authorization.can(actor, 'bookings.read');
      expect(fixture.lookups.users).toBe(2);
    });
  });
});
