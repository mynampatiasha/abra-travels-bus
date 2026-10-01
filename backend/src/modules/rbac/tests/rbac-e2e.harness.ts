import { Types } from 'mongoose';
import { type DataScopeType } from '../../../common/request-context/request-actor';
import {
  type AuthTestContext,
  client,
  dataOf,
  DEFAULT_TEST_PASSWORD,
  type Tokens,
  uniqueEmail,
  uniquePhone,
} from '../../authentication/tests/auth-e2e.harness';
import { PasswordHasher } from '../../authentication/services/password-hasher.service';
import { type User } from '../../users/schemas/user.schema';
import { findSystemRole, type SystemRoleKey } from '../roles/system-roles';

/**
 * Helpers for the authorization e2e suites. Users are inserted directly into the disposable test
 * database with real role references (the roles are synchronised by the application at start-up);
 * everything else goes through the HTTP API.
 */
export interface SeededUser {
  id: string;
  email: string;
  password: string;
}

export interface SeedUserInput {
  roleKeys: SystemRoleKey[];
  userType?: User['userType'];
  operatorId?: Types.ObjectId;
  partnerId?: Types.ObjectId;
  dataScope?: { type: DataScopeType; operatorIds: Types.ObjectId[] };
}

export async function roleIds(context: AuthTestContext, keys: string[]): Promise<Types.ObjectId[]> {
  const roles = await context.connection
    .collection<{ _id: Types.ObjectId; key: string }>('roles')
    .find({ key: { $in: keys } })
    .toArray();
  if (roles.length !== keys.length) throw new Error(`Roles not synchronised: ${keys.join(', ')}`);
  return roles.map((role) => role._id);
}

/** Inserts a password account holding the given system roles, scoped like those roles. */
export async function seedUser(
  context: AuthTestContext,
  input: SeedUserInput,
): Promise<SeededUser> {
  const firstRole = input.roleKeys[0] ? findSystemRole(input.roleKeys[0]) : undefined;
  const userType = input.userType ?? firstRole?.userType;
  if (!userType) throw new Error('seedUser needs a role or an explicit userType');

  const scopeType = firstRole?.dataScopeType ?? (userType === 'CUSTOMER' ? 'OWN_RECORDS' : 'ALL');
  const dataScope = input.dataScope ?? {
    type: scopeType,
    operatorIds: scopeType === 'OWN_OPERATOR' && input.operatorId ? [input.operatorId] : [],
  };

  const email = uniqueEmail();
  const [created] = await context.users.create([
    {
      name: `Test ${input.roleKeys.join('+') || userType}`,
      email,
      phone: uniquePhone(),
      passwordHash: await context.app.get(PasswordHasher).hash(DEFAULT_TEST_PASSWORD),
      passwordChangedAt: new Date(),
      userType,
      roleIds: await roleIds(context, input.roleKeys),
      ...(input.operatorId ? { operatorId: input.operatorId } : {}),
      ...(input.partnerId ? { partnerId: input.partnerId } : {}),
      dataScope,
      status: 'ACTIVE',
      permissionVersion: 1,
      mfa: { enabled: false, recoveryCodeHashes: [] },
      preferredLanguage: 'en',
    },
  ]);
  if (!created) throw new Error('User was not created');
  return { id: created._id.toHexString(), email, password: DEFAULT_TEST_PASSWORD };
}

export async function signIn(context: AuthTestContext, user: SeededUser): Promise<Tokens> {
  const response = await client(context)
    .post('/api/v1/auth/login')
    .send({ identifier: user.email, password: user.password })
    .expect(200);
  return dataOf<Tokens>(response);
}

/** Seeds a user and signs in. */
export async function seedAndSignIn(
  context: AuthTestContext,
  input: SeedUserInput,
): Promise<SeededUser & { tokens: Tokens }> {
  const user = await seedUser(context, input);
  return { ...user, tokens: await signIn(context, user) };
}

/** New tokens after the account's access changed (the old access token answers 401). */
export async function refresh(context: AuthTestContext, tokens: Tokens): Promise<Tokens> {
  const response = await client(context)
    .post('/api/v1/auth/refresh')
    .send({ refreshToken: tokens.refreshToken })
    .expect(200);
  return dataOf<Tokens>(response);
}

export interface MyPermissions {
  userId: string;
  userType: string;
  roles: Array<{ key: string; name: string }>;
  permissionVersion: number;
  dataScope: { type: string; operatorIds: string[] };
  operatorId: string | null;
  partnerId: string | null;
  permissions: string[];
  permissionsByModule: Record<string, string[]>;
}

export interface UserAuthorization {
  userId: string;
  permissionVersion: number;
  roles: Array<{ key: string }>;
  dataScope: { type: string; operatorIds: string[] };
  overrides: Array<{ permissionKey: string; effect: string; reason: string; grantedBy: string }>;
  effectivePermissions: Array<{ key: string; source: string }>;
  deniedPermissions: string[];
}

export interface DirectoryUser {
  id: string;
  operatorId: string | null;
  partnerId: string | null;
  userType: string;
}

export interface AuditEntry {
  action: string;
  actor: { userId: string; userType: string; roleKeys: string[] };
  entityType: string;
  entityId: string;
  operatorId: string | null;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  reason: string | null;
  requestId: string | null;
  ip: string | null;
}

export function newId(): Types.ObjectId {
  return new Types.ObjectId();
}
