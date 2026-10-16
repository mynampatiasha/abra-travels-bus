import { createHash, randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AppConfigService } from '../../config/app-config.service';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { PasswordHasher } from '../authentication/services/password-hasher.service';
import { assertPasswordAcceptable } from '../authentication/services/password-policy';
import { MessageSenderService } from '../messages/messages_admin_manage.service';
import { AUTH_SESSION_MODEL, type AuthSession } from '../sessions/schemas/auth-session.schema';
import { SessionsService } from '../sessions/services/sessions.service';
import { UserRepository } from '../users/repositories/user.repository';
import { USER_MODEL, type User } from '../users/schemas/user.schema';
import { UsersService } from '../users/services/users.service';
import { PermissionOverrideRepository } from './repositories/permission-override.repository';
import { RoleRepository } from './repositories/role.repository';
import { AuditedChangeRunner } from './services/audited-change.service';

export const STAFF_INVITATION_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

export const DEMO_ROLE_NAMES: Record<string, string> = {
  SUPER_ADMIN: 'Super Admin',
  ADMIN: 'Admin',
  SUPPORT: 'Support',
  ACCOUNTS: 'Accounts',
};

export const STAFF_INVITATION_MODEL = 'StaffInvitation';

export interface StaffInvitation {
  userId: Types.ObjectId;
  email: string;
  name: string;
  roleKey: string;
  tokenHash: string;
  expiresAt: Date;
  status: 'PENDING' | 'ACCEPTED' | 'REVOKED';
  invitedBy: Types.ObjectId;
  acceptedAt?: Date | null;
  createdAt?: Date;
  updatedAt?: Date;
}

export const staffInvitationSchema = new Schema<StaffInvitation>(
  {
    userId: { type: Schema.Types.ObjectId, required: true, index: true },
    email: { type: String, lowercase: true, trim: true, required: true },
    name: { type: String, trim: true, required: true },
    roleKey: { type: String, required: true },
    tokenHash: { type: String, required: true, index: true },
    expiresAt: { type: Date, required: true },
    status: { type: String, enum: ['PENDING', 'ACCEPTED', 'REVOKED'], default: 'PENDING' },
    invitedBy: { type: Schema.Types.ObjectId, required: true },
    acceptedAt: { type: Date, default: null },
  },
  { collection: 'staff_invitations', timestamps: true, versionKey: false },
);

export interface StaffView {
  id: string;
  name: string;
  email: string;
  role: string;
  roleName: string;
  mfa: boolean;
  status: 'ACTIVE' | 'INVITED' | 'DEACTIVATED';
  overrides: number;
  lastSeen: string | null;
  createdAt: string | null;
  inviteUrl?: string;
}

export interface StaffSessionView {
  id: string;
  userId: string;
  who: string;
  device: string;
  ip: string;
  signedInAt: string;
  lastUsedAt: string;
}

export interface StaffInvitationPreview {
  name: string;
  email: string;
  roleKey: string;
  roleName: string;
}

export interface StaffListQuery {
  search?: string;
  role?: string;
  status?: 'ACTIVE' | 'INVITED' | 'DEACTIVATED' | 'ALL';
  sort?: string;
  page?: number;
  pageSize?: number;
}

export interface InviteStaffInput {
  name: string;
  email: string;
  role: string;
}

export interface UpdateStaffInput {
  name?: string;
  role?: string;
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function invalidLink(): ApiException {
  return new ApiException(
    'RESOURCE_NOT_FOUND',
    'This invitation link is not valid or has expired.',
  );
}

@Injectable()
export class StaffAdminManageService {
  private readonly logger = new Logger(StaffAdminManageService.name);

  constructor(
    @InjectModel(USER_MODEL) private readonly userModel: Model<User>,
    @InjectModel(STAFF_INVITATION_MODEL) private readonly invitationModel: Model<StaffInvitation>,
    @InjectModel(AUTH_SESSION_MODEL) private readonly sessionModel: Model<AuthSession>,
    private readonly userRepo: UserRepository,
    private readonly usersService: UsersService,
    private readonly roleRepo: RoleRepository,
    private readonly overrideRepo: PermissionOverrideRepository,
    private readonly sessionsService: SessionsService,
    private readonly messageSender: MessageSenderService,
    private readonly hasher: PasswordHasher,
    private readonly config: AppConfigService,
    private readonly transactions: TransactionRunner,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private get adminBaseUrl(): string {
    return process.env.ADMIN_PORTAL_URL || 'http://localhost:4200';
  }

  async roles(): Promise<Array<{ key: string; name: string }>> {
    const defaultRoles: Array<{ key: string; name: string }> = [
      { key: 'SUPER_ADMIN', name: 'Super Admin' },
      { key: 'ADMIN', name: 'Admin' },
      { key: 'SUPPORT', name: 'Support' },
      { key: 'ACCOUNTS', name: 'Accounts' },
    ];

    try {
      const dbRoles = await this.roleRepo['model'].find({ userType: 'STAFF' }).lean().exec();
      const existingKeys = new Set(defaultRoles.map((r) => r.key));
      for (const r of dbRoles) {
        if (!existingKeys.has(r.key)) {
          defaultRoles.push({
            key: r.key,
            name: r.name ?? r.key,
          });
          existingKeys.add(r.key);
        }
      }
    } catch {
      // Return default list if db collection query is unavailable
    }

    return defaultRoles;
  }

  async list(query: StaffListQuery): Promise<PaginatedResult<StaffView>> {
    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.max(1, Math.min(100, query.pageSize ?? 15));

    const filter: Record<string, unknown> = {
      userType: 'STAFF',
    };

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status;
    }

    if (query.role && query.role !== 'ALL') {
      const role = await this.roleRepo.findByKey(query.role);
      if (role) {
        filter.roleIds = role._id;
      } else {
        return new PaginatedResult([], page, pageSize, 0);
      }
    }

    if (query.search && query.search.trim().length > 0) {
      const regex = new RegExp(escapeRegExp(query.search.trim()), 'i');
      filter.$or = [{ name: regex }, { email: regex }];
    }

    const total = await this.userModel.countDocuments(filter);
    const skip = skipOf({ page, pageSize });

    const users = await this.userModel
      .find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(pageSize)
      .lean()
      .exec();

    const userIds = users.map((u) => u._id);

    // Aggregate overrides count per user
    const overrideCounts = await this.overrideRepo['model'].aggregate<{ _id: Types.ObjectId; count: number }>([
      { $match: { userId: { $in: userIds } } },
      { $group: { _id: '$userId', count: { $sum: 1 } } },
    ]);
    const overrideMap = new Map<string, number>();
    for (const entry of overrideCounts) {
      overrideMap.set(entry._id.toHexString(), entry.count);
    }

    // Load roles map
    const allRoleIds = Array.from(new Set(users.flatMap((u) => u.roleIds || [])));
    const roles = await this.roleRepo.findByIds(allRoleIds);
    const roleMap = new Map<string, { key: string; name: string }>();
    for (const r of roles) {
      roleMap.set(r._id.toHexString(), { key: r.key, name: r.name });
    }

    const items: StaffView[] = users.map((u) => {
      const uId = u._id.toHexString();
      const firstRoleId = u.roleIds?.[0]?.toHexString();
      const roleInfo = firstRoleId ? roleMap.get(firstRoleId) : undefined;
      const roleKey = roleInfo?.key ?? 'SUPPORT';
      const roleName = DEMO_ROLE_NAMES[roleKey] ?? roleInfo?.name ?? roleKey;

      return {
        id: uId,
        name: u.name ?? '',
        email: u.email ?? '',
        role: roleKey,
        roleName,
        mfa: u.mfa?.enabled ?? false,
        status: (u.status as 'ACTIVE' | 'INVITED' | 'DEACTIVATED') ?? 'ACTIVE',
        overrides: overrideMap.get(uId) ?? 0,
        lastSeen: u.lastLoginAt ? u.lastLoginAt.toISOString() : null,
        createdAt: u.createdAt ? u.createdAt.toISOString() : null,
      };
    });

    return new PaginatedResult(items, page, pageSize, total);
  }

  async get(id: string): Promise<StaffView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    const user = await this.userModel.findOne({ _id: id, userType: 'STAFF' }).lean().exec();
    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }

    const firstRoleId = user.roleIds?.[0];
    let roleKey = 'SUPPORT';
    let roleName = 'Support';
    if (firstRoleId) {
      const [role] = await this.roleRepo.findByIds([firstRoleId]);
      if (role) {
        roleKey = role.key;
        roleName = DEMO_ROLE_NAMES[roleKey] ?? role.name;
      }
    }

    const overrides = await this.overrideRepo.findForUser(user._id);

    return {
      id: user._id.toHexString(),
      name: user.name ?? '',
      email: user.email ?? '',
      role: roleKey,
      roleName,
      mfa: user.mfa?.enabled ?? false,
      status: (user.status as 'ACTIVE' | 'INVITED' | 'DEACTIVATED') ?? 'ACTIVE',
      overrides: overrides.length,
      lastSeen: user.lastLoginAt ? user.lastLoginAt.toISOString() : null,
      createdAt: user.createdAt ? user.createdAt.toISOString() : null,
    };
  }

  async invite(
    actor: AuthenticatedUserActor,
    input: InviteStaffInput,
    _client: ClientRequestInfo,
  ): Promise<StaffView> {
    const email = input.email.trim().toLowerCase();
    const existing = await this.userRepo.findByEmail(email);
    if (existing) {
      throw new ApiException('ALREADY_REGISTERED', 'This email already has an account.');
    }

    let role = await this.roleRepo.findByKey(input.role);
    if (!role && input.role === 'ACCOUNTS') {
      try {
        await this.roleRepo.upsertSystemRole({
          key: 'ACCOUNTS',
          name: 'Accounts',
          description: 'Handles financial commissions, payouts and audit reporting.',
          userType: 'STAFF',
          dataScopeType: 'ALL',
          permissionKeys: ['commissions.read', 'commissions.export', 'audit.read'],
        });
        role = await this.roleRepo.findByKey('ACCOUNTS');
      } catch {
        role = await this.roleRepo.findByKey('ACCOUNTS');
      }
    }
    if (!role) {
      throw new ApiException('VALIDATION_FAILED', `Role '${input.role}' does not exist.`);
    }

    const token = randomBytes(32).toString('base64url');
    const tokenHash = hashToken(token);
    const expiresAt = new Date(Date.now() + STAFF_INVITATION_DAYS * DAY_MS);
    const actorId = new Types.ObjectId(actor.userId);

    const created = await this.transactions.run(async (session) => {
      const user = await this.userRepo.insert(
        {
          name: input.name.trim(),
          email,
          userType: 'STAFF',
          roleIds: [role._id],
          dataScope: { type: 'ALL', operatorIds: [] },
          status: 'INVITED',
          permissionVersion: 1,
          mfa: { enabled: false, recoveryCodeHashes: [] },
          preferredLanguage: 'en',
        },
        { session },
      );

      await this.invitationModel.create(
        [
          {
            userId: user._id,
            email,
            name: input.name.trim(),
            roleKey: role.key,
            tokenHash,
            expiresAt,
            status: 'PENDING',
            invitedBy: actorId,
          },
        ],
        { session },
      );

      return user;
    });

    const inviteUrl = `${this.adminBaseUrl}/staff-invitation?token=${token}`;

    try {
      await this.messageSender.send({
        channel: 'EMAIL',
        kind: 'GENERAL',
        recipientName: input.name.trim(),
        address: email,
        subject: 'Your Abra Travels staff invitation',
        body:
          `Hello ${input.name.trim()},\n\n` +
          `You have been invited to join the Abra Travels admin portal as ${role.name}.\n\n` +
          `Please set your password using this link (valid for 7 days):\n${inviteUrl}\n\n` +
          `Abra Travels Team`,
        userId: created._id,
      });
    } catch (err) {
      this.logger.warn({ email, err }, 'Failed to deliver staff invitation email');
    }

    const view: StaffView = {
      id: created._id.toHexString(),
      name: created.name ?? '',
      email: created.email ?? '',
      role: role.key,
      roleName: DEMO_ROLE_NAMES[role.key] ?? role.name,
      mfa: false,
      status: 'INVITED',
      overrides: 0,
      lastSeen: null,
      createdAt: created.createdAt ? created.createdAt.toISOString() : new Date().toISOString(),
      ...(!this.config.isProduction ? { inviteUrl } : {}),
    };

    return view;
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateStaffInput,
    client: ClientRequestInfo,
  ): Promise<StaffView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    const user = await this.userModel.findOne({ _id: id, userType: 'STAFF' }).exec();
    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }

    let nextRole = undefined;
    if (input.role) {
      if (actor.userId === id) {
        throw new ApiException('PERMISSION_DENIED', 'You cannot change your own role');
      }
      nextRole = await this.roleRepo.findByKey(input.role);
      if (!nextRole && input.role === 'ACCOUNTS') {
        try {
          await this.roleRepo.upsertSystemRole({
            key: 'ACCOUNTS',
            name: 'Accounts',
            description: 'Handles financial commissions, payouts and audit reporting.',
            userType: 'STAFF',
            dataScopeType: 'ALL',
            permissionKeys: ['commissions.read', 'commissions.export', 'audit.read'],
          });
          nextRole = await this.roleRepo.findByKey('ACCOUNTS');
        } catch {
          nextRole = await this.roleRepo.findByKey('ACCOUNTS');
        }
      }
      if (!nextRole) {
        throw new ApiException('VALIDATION_FAILED', `Role '${input.role}' does not exist.`);
      }

      // Check if current user is SUPER_ADMIN and new role is different
      const superAdminRole = await this.roleRepo.findByKey('SUPER_ADMIN');
      if (
        superAdminRole &&
        user.roleIds.some((r) => r.equals(superAdminRole._id)) &&
        input.role !== 'SUPER_ADMIN'
      ) {
        const count = await this.userModel.countDocuments({
          roleIds: superAdminRole._id,
          status: 'ACTIVE',
        });
        if (count <= 1) {
          throw new ApiException('INVALID_STATE_TRANSITION', 'There must be at least one Super Admin');
        }
      }
    }

    const beforeState = {
      name: user.name,
      roleIds: user.roleIds.map((r) => r.toHexString()),
    };

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'staff.updated',
      entityType: 'staff',
      before: beforeState,
      describe: (record) => ({
        name: record.name,
        roleIds: record.roleIds.map((r) => r.toHexString()),
      }),
      apply: async (session) => {
        const updates: Partial<User> = {};
        if (input.name) updates.name = input.name.trim();
        if (nextRole) {
          updates.roleIds = [nextRole._id];
          updates.permissionVersion = (user.permissionVersion || 1) + 1;
        }
        const res = await this.userModel
          .findByIdAndUpdate(user._id, { $set: updates }, { new: true, session })
          .exec();
        if (!res) throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
        return res;
      },
    });

    return this.get(updated._id.toHexString());
  }

  async resend(
    actor: AuthenticatedUserActor,
    id: string,
    _client: ClientRequestInfo,
  ): Promise<{ resent: boolean; inviteUrl?: string }> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    const user = await this.userModel.findOne({ _id: id, userType: 'STAFF' }).exec();
    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    if (user.status !== 'INVITED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Invitation can only be resent for invited staff.');
    }

    const token = randomBytes(32).toString('base64url');
    const tokenHash = hashToken(token);
    const expiresAt = new Date(Date.now() + STAFF_INVITATION_DAYS * DAY_MS);

    const [role] = await this.roleRepo.findByIds(user.roleIds || []);
    const roleKey = role?.key ?? 'SUPPORT';
    const roleName = role?.name ?? roleKey;

    await this.transactions.run(async (session) => {
      // Invalidate old pending invitations
      await this.invitationModel.updateMany(
        { userId: user._id, status: 'PENDING' },
        { $set: { status: 'REVOKED' } },
        { session },
      );

      await this.invitationModel.create(
        [
          {
            userId: user._id,
            email: user.email!,
            name: user.name ?? '',
            roleKey,
            tokenHash,
            expiresAt,
            status: 'PENDING',
            invitedBy: new Types.ObjectId(actor.userId),
          },
        ],
        { session },
      );
    });

    const inviteUrl = `${this.adminBaseUrl}/staff-invitation?token=${token}`;

    try {
      await this.messageSender.send({
        channel: 'EMAIL',
        kind: 'GENERAL',
        recipientName: user.name ?? 'Staff member',
        address: user.email!,
        subject: 'Your Abra Travels staff invitation (resent)',
        body:
          `Hello ${user.name ?? ''},\n\n` +
          `Your invitation to join the Abra Travels admin portal as ${roleName} has been resent.\n\n` +
          `Please set your password using this link (valid for 7 days):\n${inviteUrl}\n\n` +
          `Abra Travels Team`,
        userId: user._id,
      });
    } catch (err) {
      this.logger.warn({ email: user.email, err }, 'Failed to deliver resent invitation email');
    }

    return {
      resent: true,
      ...(!this.config.isProduction ? { inviteUrl } : {}),
    };
  }

  async deactivate(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<StaffView> {
    if (actor.userId === id) {
      throw new ApiException('PERMISSION_DENIED', 'You cannot deactivate your own account');
    }
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    const user = await this.userModel.findOne({ _id: id, userType: 'STAFF' }).exec();
    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }

    // Check if last active Super Admin
    const superAdminRole = await this.roleRepo.findByKey('SUPER_ADMIN');
    if (superAdminRole && user.roleIds.some((r) => r.equals(superAdminRole._id))) {
      const activeSuperAdmins = await this.userModel.countDocuments({
        roleIds: superAdminRole._id,
        status: 'ACTIVE',
      });
      if (activeSuperAdmins <= 1) {
        throw new ApiException('INVALID_STATE_TRANSITION', 'Keep at least one active Super Admin');
      }
    }

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'staff.deactivated',
      entityType: 'staff',
      reason,
      before: { status: user.status },
      describe: (record) => ({ status: record.status }),
      apply: async (session) => {
        const res = await this.userModel
          .findByIdAndUpdate(
            user._id,
            {
              $set: { status: 'DEACTIVATED' },
              $inc: { permissionVersion: 1 },
            },
            { new: true, session },
          )
          .exec();
        if (!res) {
          throw new ApiException('RESOURCE_NOT_FOUND', 'User not found');
        }
        return res;
      },
    });

    // Revoke every active session
    await this.sessionsService.revokeAllForUser(user._id.toHexString(), 'ACCOUNT_DISABLED');

    return this.get(updated._id.toHexString());
  }

  async activate(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<StaffView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }
    const user = await this.userModel.findOne({ _id: id, userType: 'STAFF' }).exec();
    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Staff member not found.');
    }

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'staff.activated',
      entityType: 'staff',
      reason,
      before: { status: user.status },
      describe: (record) => ({ status: record.status }),
      apply: async (session) => {
        const res = await this.userModel
          .findByIdAndUpdate(
            user._id,
            {
              $set: { status: 'ACTIVE' },
              $inc: { permissionVersion: 1 },
            },
            { new: true, session },
          )
          .exec();
        return res as User & { _id: Types.ObjectId };
      },
    });

    return this.get(updated._id.toHexString());
  }

  async inspectInvitation(token: string): Promise<StaffInvitationPreview> {
    const tokenHash = hashToken(token);
    const invitation = await this.invitationModel
      .findOne({
        tokenHash,
        status: 'PENDING',
        expiresAt: { $gt: new Date() },
      })
      .lean()
      .exec();

    if (!invitation) {
      throw invalidLink();
    }

    const role = await this.roleRepo.findByKey(invitation.roleKey);

    return {
      name: invitation.name,
      email: invitation.email,
      roleKey: invitation.roleKey,
      roleName: role?.name ?? invitation.roleKey,
    };
  }

  async acceptInvitation(input: { token: string; password: string }): Promise<{ email: string }> {
    const tokenHash = hashToken(input.token);
    const invitation = await this.invitationModel
      .findOne({
        tokenHash,
        status: 'PENDING',
        expiresAt: { $gt: new Date() },
      })
      .exec();

    if (!invitation) {
      throw invalidLink();
    }

    const user = await this.userModel.findById(invitation.userId).exec();
    if (!user) {
      throw invalidLink();
    }

    assertPasswordAcceptable(input.password, { email: invitation.email, name: invitation.name });
    const passwordHash = await this.hasher.hash(input.password);

    await this.transactions.run(async (session) => {
      invitation.status = 'ACCEPTED';
      invitation.acceptedAt = new Date();
      await invitation.save({ session });

      user.passwordHash = passwordHash;
      user.status = 'ACTIVE';
      user.emailVerifiedAt = new Date();
      user.permissionVersion = (user.permissionVersion || 1) + 1;
      await user.save({ session });
    });

    return { email: invitation.email };
  }
}
