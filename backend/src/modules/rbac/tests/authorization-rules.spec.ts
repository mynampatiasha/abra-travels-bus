import { ApiException } from '../../../common/errors/api-exception';
import {
  type AuthenticatedUserActor,
  type DataScope,
} from '../../../common/request-context/request-actor';
import { findSystemRole } from '../roles/system-roles';
import {
  assertCanAdminister,
  assertDataScopeAssignable,
  assertNotSelf,
  assertOverrideAllowed,
  assertOverrideRemovable,
  assertRolesAssignable,
} from '../services/authorization-rules';
import {
  type EffectivePermissions,
  resolveEffectivePermissions,
} from '../services/effective-permissions';

const OPERATOR_A = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const OPERATOR_B = 'bbbbbbbbbbbbbbbbbbbbbbbb';

function role(key: string) {
  const found = findSystemRole(key);
  if (!found) throw new Error(`role ${key} missing`);
  return found;
}

function permissionsOf(key: string): EffectivePermissions {
  const definition = role(key);
  return resolveEffectivePermissions(definition.userType, [definition], []);
}

function actor(dataScope: DataScope, userId = 'actor-user'): AuthenticatedUserActor {
  return {
    actorType: 'USER',
    userId,
    dataScope,
    userType: 'STAFF',
    sessionId: 'session',
    permissionVersion: 1,
    roleIds: [],
    mfaEnrollmentPending: false,
  };
}

function codeOf(work: () => void): string | undefined {
  try {
    work();
    return undefined;
  } catch (error) {
    if (error instanceof ApiException) return error.code;
    throw error;
  }
}

const SUPER_ADMIN = permissionsOf('SUPER_ADMIN');
const ADMIN = permissionsOf('ADMIN');
const OPERATOR_ADMIN = permissionsOf('OPERATOR_ADMIN');
const BOOKING_STAFF = permissionsOf('BOOKING_STAFF');

describe('authorization rules (privilege-escalation prevention)', () => {
  describe('assertNotSelf', () => {
    it('refuses changes to the actor’s own account, even for a super administrator', () => {
      expect(codeOf(() => assertNotSelf(actor({ type: 'ALL', operatorIds: [] }, 'u1'), 'u1'))).toBe(
        'PERMISSION_DENIED',
      );
      expect(
        codeOf(() => assertNotSelf(actor({ type: 'ALL', operatorIds: [] }, 'u1'), 'u2')),
      ).toBeUndefined();
    });
  });

  describe('assertCanAdminister', () => {
    it('a wildcard holder may administer anyone', () => {
      expect(codeOf(() => assertCanAdminister(SUPER_ADMIN, SUPER_ADMIN))).toBeUndefined();
      expect(codeOf(() => assertCanAdminister(SUPER_ADMIN, ADMIN))).toBeUndefined();
    });

    it('nobody else may administer a wildcard holder', () => {
      expect(codeOf(() => assertCanAdminister(ADMIN, SUPER_ADMIN))).toBe('PERMISSION_DENIED');
    });

    it('an actor may administer users with the same or less access', () => {
      expect(codeOf(() => assertCanAdminister(OPERATOR_ADMIN, BOOKING_STAFF))).toBeUndefined();
      expect(codeOf(() => assertCanAdminister(OPERATOR_ADMIN, OPERATOR_ADMIN))).toBeUndefined();
    });

    it('an actor may not administer a user who holds something the actor lacks', () => {
      expect(codeOf(() => assertCanAdminister(BOOKING_STAFF, OPERATOR_ADMIN))).toBe(
        'PERMISSION_DENIED',
      );
      expect(codeOf(() => assertCanAdminister(OPERATOR_ADMIN, ADMIN))).toBe('PERMISSION_DENIED');
    });
  });

  describe('assertRolesAssignable (unauthorized role changes)', () => {
    it('lets an operator administrator assign operator roles within their own access', () => {
      expect(
        codeOf(() =>
          assertRolesAssignable(OPERATOR_ADMIN, 'OPERATOR_STAFF', [role('BOOKING_STAFF')]),
        ),
      ).toBeUndefined();
      expect(
        codeOf(() =>
          assertRolesAssignable(OPERATOR_ADMIN, 'OPERATOR_STAFF', [role('OPERATOR_ADMIN')]),
        ),
      ).toBeUndefined();
    });

    it('refuses a role that carries a permission the actor lacks', () => {
      expect(
        codeOf(() =>
          assertRolesAssignable(BOOKING_STAFF, 'OPERATOR_STAFF', [role('OPERATOR_ADMIN')]),
        ),
      ).toBe('PERMISSION_DENIED');
      expect(codeOf(() => assertRolesAssignable(OPERATOR_ADMIN, 'STAFF', [role('ADMIN')]))).toBe(
        'PERMISSION_DENIED',
      );
    });

    it('only a wildcard holder may assign SUPER_ADMIN', () => {
      expect(codeOf(() => assertRolesAssignable(ADMIN, 'STAFF', [role('SUPER_ADMIN')]))).toBe(
        'PERMISSION_DENIED',
      );
      expect(
        codeOf(() => assertRolesAssignable(SUPER_ADMIN, 'STAFF', [role('SUPER_ADMIN')])),
      ).toBeUndefined();
    });

    it('refuses a role made for another kind of account, even for a super administrator', () => {
      expect(codeOf(() => assertRolesAssignable(SUPER_ADMIN, 'CUSTOMER', [role('ADMIN')]))).toBe(
        'VALIDATION_FAILED',
      );
      expect(
        codeOf(() => assertRolesAssignable(SUPER_ADMIN, 'OPERATOR_STAFF', [role('DRIVER')])),
      ).toBe('VALIDATION_FAILED');
    });

    it('refuses roles with different data scopes together', () => {
      const selectedOperators = {
        ...role('SUPPORT'),
        key: 'REGIONAL',
        dataScopeType: 'SELECTED_OPERATORS' as const,
      };
      expect(
        codeOf(() =>
          assertRolesAssignable(SUPER_ADMIN, 'STAFF', [role('ADMIN'), selectedOperators]),
        ),
      ).toBe('VALIDATION_FAILED');
    });

    it('accepts an empty list (removing every role)', () => {
      expect(
        codeOf(() => assertRolesAssignable(BOOKING_STAFF, 'OPERATOR_STAFF', [])),
      ).toBeUndefined();
    });
  });

  describe('assertOverrideAllowed (unauthorized permission changes)', () => {
    it('ALLOW needs the actor to hold the permission', () => {
      expect(
        codeOf(() =>
          assertOverrideAllowed(OPERATOR_ADMIN, 'OPERATOR_STAFF', 'reports.read', 'ALLOW'),
        ),
      ).toBeUndefined();
      expect(
        codeOf(() =>
          assertOverrideAllowed(BOOKING_STAFF, 'OPERATOR_STAFF', 'reports.read', 'ALLOW'),
        ),
      ).toBe('PERMISSION_DENIED');
    });

    it('ALLOW is refused when the target’s kind of account may not hold the permission', () => {
      expect(
        codeOf(() => assertOverrideAllowed(SUPER_ADMIN, 'CUSTOMER', 'settings.update', 'ALLOW')),
      ).toBe('VALIDATION_FAILED');
      expect(
        codeOf(() =>
          assertOverrideAllowed(SUPER_ADMIN, 'OPERATOR_STAFF', 'users.data-scope.manage', 'ALLOW'),
        ),
      ).toBe('VALIDATION_FAILED');
    });

    it('an unknown permission is refused for ALLOW and DENY', () => {
      for (const effect of ['ALLOW', 'DENY'] as const) {
        expect(
          codeOf(() => assertOverrideAllowed(SUPER_ADMIN, 'STAFF', 'bookings.destroy', effect)),
        ).toBe('VALIDATION_FAILED');
        expect(codeOf(() => assertOverrideAllowed(SUPER_ADMIN, 'STAFF', '*', effect))).toBe(
          'VALIDATION_FAILED',
        );
      }
    });

    it('DENY is allowed for any existing permission', () => {
      expect(
        codeOf(() =>
          assertOverrideAllowed(BOOKING_STAFF, 'OPERATOR_STAFF', 'settlements.read', 'DENY'),
        ),
      ).toBeUndefined();
    });
  });

  describe('assertOverrideRemovable', () => {
    it('removing a DENY restores a permission, so the actor must hold it', () => {
      expect(codeOf(() => assertOverrideRemovable(BOOKING_STAFF, 'settlements.read', 'DENY'))).toBe(
        'PERMISSION_DENIED',
      );
      expect(
        codeOf(() => assertOverrideRemovable(OPERATOR_ADMIN, 'settlements.read', 'DENY')),
      ).toBeUndefined();
    });

    it('removing an ALLOW only takes access away', () => {
      expect(
        codeOf(() => assertOverrideRemovable(BOOKING_STAFF, 'settlements.read', 'ALLOW')),
      ).toBeUndefined();
    });
  });

  describe('assertDataScopeAssignable (a caller cannot widen scope)', () => {
    const platform = actor({ type: 'ALL', operatorIds: [] });
    const operatorA = actor({ type: 'OWN_OPERATOR', operatorIds: [OPERATOR_A] });
    const staffTarget = { userType: 'STAFF' as const };
    const operatorTarget = { userType: 'OPERATOR_STAFF' as const, operatorId: OPERATOR_A };

    it('a platform actor may set any scope that suits the account kind', () => {
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, staffTarget, { type: 'ALL', operatorIds: [] }),
        ),
      ).toBeUndefined();
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, staffTarget, {
            type: 'SELECTED_OPERATORS',
            operatorIds: [OPERATOR_A, OPERATOR_B],
          }),
        ),
      ).toBeUndefined();
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, operatorTarget, {
            type: 'OWN_OPERATOR',
            operatorIds: [OPERATOR_A],
          }),
        ),
      ).toBeUndefined();
    });

    it.each([
      [
        'a customer cannot get ALL',
        { userType: 'CUSTOMER' as const },
        { type: 'ALL' as const, operatorIds: [] },
      ],
      [
        'a driver cannot get OWN_OPERATOR',
        { userType: 'DRIVER' as const, operatorId: OPERATOR_A },
        { type: 'OWN_OPERATOR' as const, operatorIds: [OPERATOR_A] },
      ],
      ['operator staff cannot get ALL', operatorTarget, { type: 'ALL' as const, operatorIds: [] }],
      [
        'a partner user cannot get SELECTED_OPERATORS',
        { userType: 'PARTNER_USER' as const },
        { type: 'SELECTED_OPERATORS' as const, operatorIds: [OPERATOR_A] },
      ],
    ])('%s', (_label, target, requested) => {
      expect(codeOf(() => assertDataScopeAssignable(platform, target, requested))).toBe(
        'VALIDATION_FAILED',
      );
    });

    it('checks the shape of the scope', () => {
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, staffTarget, {
            type: 'SELECTED_OPERATORS',
            operatorIds: [],
          }),
        ),
      ).toBe('VALIDATION_FAILED');
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, staffTarget, {
            type: 'ALL',
            operatorIds: [OPERATOR_A],
          }),
        ),
      ).toBe('VALIDATION_FAILED');
      // OWN_OPERATOR must be the user's own operator, not another one
      expect(
        codeOf(() =>
          assertDataScopeAssignable(platform, operatorTarget, {
            type: 'OWN_OPERATOR',
            operatorIds: [OPERATOR_B],
          }),
        ),
      ).toBe('VALIDATION_FAILED');
    });

    it('an operator-scoped actor cannot hand out an operator outside their own scope', () => {
      expect(
        codeOf(() =>
          assertDataScopeAssignable(operatorA, operatorTarget, {
            type: 'SELECTED_OPERATORS',
            operatorIds: [OPERATOR_A, OPERATOR_B],
          }),
        ),
      ).toBe('PERMISSION_DENIED');
      expect(
        codeOf(() =>
          assertDataScopeAssignable(operatorA, operatorTarget, {
            type: 'OWN_OPERATOR',
            operatorIds: [OPERATOR_A],
          }),
        ),
      ).toBeUndefined();
    });

    it('a non-platform actor can never hand out ALL', () => {
      expect(
        codeOf(() =>
          assertDataScopeAssignable(operatorA, staffTarget, { type: 'ALL', operatorIds: [] }),
        ),
      ).toBe('PERMISSION_DENIED');
      const partner = actor({ type: 'OWN_PARTNER', operatorIds: [] });
      expect(
        codeOf(() =>
          assertDataScopeAssignable(
            partner,
            { userType: 'PARTNER_USER' },
            { type: 'OWN_PARTNER', operatorIds: [] },
          ),
        ),
      ).toBe('PERMISSION_DENIED');
    });
  });
});
