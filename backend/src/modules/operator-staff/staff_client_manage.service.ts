import { createHash, randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AppConfigService } from '../../config/app-config.service';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { MessageSenderService } from '../messages/messages_admin_manage.service';
import { AUTH_SESSION_MODEL, type AuthSession } from '../sessions/schemas/auth-session.schema';
import { SessionsService } from '../sessions/services/sessions.service';
import { USER_MODEL, type User } from '../users/schemas/user.schema';
import { UsersService } from '../users/services/users.service';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { STAFF_INVITATION_MODEL, type StaffInvitation } from '../rbac/staff_admin_manage.service';
import { type AccessLevel, inferLevel, pagesFor } from '../rbac/permissions/access-pages';
import { SYSTEM_ROLES } from '../rbac/roles/system-roles';

export const CLIENT_ROLE_NAMES: Record<string, string> = {
  SUPER_ADMIN: 'Owner',
  OPERATOR_ADMIN: 'Owner',
  ADMIN: 'Manager',
  OPERATOR_MANAGER: 'Manager',
  SUPPORT: 'Booking staff',
  BOOKING_STAFF: 'Booking staff',
  ACCOUNTS: 'Accounts',
  ACCOUNT_STAFF: 'Accounts',
  OPERATIONS_STAFF: 'Operations staff',
};

export interface PortalUserView {
  id: string;
  operatorId: string;
  name: string;
  email: string;
  role: string;
  roleName: string;
  status: 'ACTIVE' | 'INVITED' | 'DEACTIVATED';
  lastSeen: string | null;
  createdAt: string | null;
  inviteUrl?: string;
}

export interface PortalUserListQuery {
  search?: string;
  role?: string;
  status?: 'ACTIVE' | 'INVITED' | 'DEACTIVATED' | 'ALL';
  page?: number;
  pageSize?: number;
}

export interface InvitePortalUserInput {
  name: string;
  email: string;
  role: string;
}

export interface UpdatePortalUserInput {
  name?: string;
  role?: string;
}

export interface PortalMatrixPageRow {
  id: string;
  title: string;
  levels: {
    owner: AccessLevel;
    manager: AccessLevel;
    booking: AccessLevel;
    accounts: AccessLevel;
  };
}

export interface PortalMatrixView {
  roles: Array<{ key: string; name: string }>;
  pages: PortalMatrixPageRow[];
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

const INVITATION_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class StaffClientManageService {
  private readonly logger = new Logger(StaffClientManageService.name);

  constructor(
    @InjectModel(USER_MODEL) private readonly userModel: Model<User>,
    @InjectModel(STAFF_INVITATION_MODEL) private readonly invitationModel: Model<StaffInvitation>,
    @InjectModel(AUTH_SESSION_MODEL) private readonly sessionModel: Model<AuthSession>,
    private readonly usersService: UsersService,
    private readonly roleRepo: RoleRepository,
    private readonly sessionsService: SessionsService,
    private readonly messageSender: MessageSenderService,
    private readonly config: AppConfigService,
    private readonly transactions: TransactionRunner,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private get clientBaseUrl(): string {
    return process.env.CLIENT_PORTAL_URL || 'http://localhost:5000';
  }

  private resolveRoleKey(requested: string): string {
    const norm = requested.trim().toUpperCase();
    if (norm === 'ADMIN' || norm === 'OPERATOR_MANAGER' || norm === 'MANAGER') {
      return 'OPERATOR_MANAGER';
    }
    if (norm === 'SUPPORT' || norm === 'BOOKING_STAFF' || norm === 'BOOKING STAFF') {
      return 'BOOKING_STAFF';
    }
    if (norm === 'ACCOUNTS' || norm === 'ACCOUNT_STAFF') {
      return 'ACCOUNT_STAFF';
    }
    return norm;
  }

  roles(): Promise<Array<{ key: string; name: string }>> {
    return Promise.resolve([
      { key: 'ADMIN', name: 'Manager' },
      { key: 'SUPPORT', name: 'Booking staff' },
      { key: 'ACCOUNTS', name: 'Accounts' },
    ]);
  }

  async permissionMatrix(): Promise<PortalMatrixView> {
    const roleKeys = ['OPERATOR_ADMIN', 'OPERATOR_MANAGER', 'BOOKING_STAFF', 'ACCOUNT_STAFF'] as const;
    const operatorPages = pagesFor('OPERATOR');

    const roleDefs: Record<
      (typeof roleKeys)[number],
      { keys: ReadonlySet<string>; wildcard: boolean }
    > = {
      OPERATOR_ADMIN: { keys: new Set(), wildcard: false },
      OPERATOR_MANAGER: { keys: new Set(), wildcard: false },
      BOOKING_STAFF: { keys: new Set(), wildcard: false },
      ACCOUNT_STAFF: { keys: new Set(), wildcard: false },
    };

    for (const key of roleKeys) {
      const stored = await this.roleRepo.findByKey(key);
      const systemDef = SYSTEM_ROLES.find((r) => r.key === key);
      const permissionKeys =
        (stored?.permissionKeys?.length ?? 0) > 0
          ? stored!.permissionKeys
          : systemDef
            ? [...systemDef.permissionKeys]
            : [];
      const wildcard = permissionKeys.includes('*');
      roleDefs[key] = {
        keys: new Set(permissionKeys),
        wildcard,
      };
    }

    const pages: PortalMatrixPageRow[] = operatorPages.map((page) => ({
      id: page.id,
      title: page.title,
      levels: {
        owner: inferLevel(page, roleDefs.OPERATOR_ADMIN.keys, roleDefs.OPERATOR_ADMIN.wildcard).level,
        manager: inferLevel(page, roleDefs.OPERATOR_MANAGER.keys, roleDefs.OPERATOR_MANAGER.wildcard).level,
        booking: inferLevel(page, roleDefs.BOOKING_STAFF.keys, roleDefs.BOOKING_STAFF.wildcard).level,
        accounts: inferLevel(page, roleDefs.ACCOUNT_STAFF.keys, roleDefs.ACCOUNT_STAFF.wildcard).level,
      },
    }));

    return {
      roles: [
        { key: 'OPERATOR_ADMIN', name: 'Owner' },
        { key: 'OPERATOR_MANAGER', name: 'Manager' },
        { key: 'BOOKING_STAFF', name: 'Booking staff' },
        { key: 'ACCOUNT_STAFF', name: 'Accounts' },
      ],
      pages,
    };
  }

  async list(actor: AuthenticatedUserActor, query: PortalUserListQuery): Promise<PaginatedResult<PortalUserView>> {
    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can access portal users');
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.max(1, Math.min(100, query.pageSize ?? 20));

    const filter: Record<string, unknown> = {
      operatorId: new Types.ObjectId(operatorId),
      userType: 'OPERATOR_STAFF',
    };

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status;
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

    // Map roles
    const allRoleIds = Array.from(new Set(users.flatMap((u) => u.roleIds || [])));
    const roles = await this.roleRepo.findByIds(allRoleIds);
    const roleMap = new Map<string, { key: string; name: string }>();
    for (const r of roles) {
      roleMap.set(r._id.toHexString(), { key: r.key, name: r.name });
    }

    const items: PortalUserView[] = users.map((u) => {
      const firstRoleId = u.roleIds?.[0]?.toHexString();
      const roleInfo = firstRoleId ? roleMap.get(firstRoleId) : undefined;
      const roleKey = roleInfo?.key ?? 'BOOKING_STAFF';
      const roleName = CLIENT_ROLE_NAMES[roleKey] ?? roleInfo?.name ?? roleKey;

      return {
        id: u._id.toHexString(),
        operatorId,
        name: u.name ?? '',
        email: u.email ?? '',
        role: roleKey,
        roleName,
        status: (u.status as 'ACTIVE' | 'INVITED' | 'DEACTIVATED') ?? 'ACTIVE',
        lastSeen: u.lastLoginAt ? u.lastLoginAt.toISOString() : null,
        createdAt: u.createdAt ? u.createdAt.toISOString() : null,
      };
    });

    return new PaginatedResult(items, page, pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<PortalUserView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can view portal users');
    }

    const user = await this.userModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(operatorId),
      userType: 'OPERATOR_STAFF',
    }).lean().exec();

    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const roleIds = user.roleIds || [];
    const roles = await this.roleRepo.findByIds(roleIds);
    const roleKey = roles[0]?.key ?? 'BOOKING_STAFF';
    const roleName = CLIENT_ROLE_NAMES[roleKey] ?? roles[0]?.name ?? roleKey;

    return {
      id: user._id.toHexString(),
      operatorId,
      name: user.name ?? '',
      email: user.email ?? '',
      role: roleKey,
      roleName,
      status: (user.status as 'ACTIVE' | 'INVITED' | 'DEACTIVATED') ?? 'ACTIVE',
      lastSeen: user.lastLoginAt ? user.lastLoginAt.toISOString() : null,
      createdAt: user.createdAt ? user.createdAt.toISOString() : null,
    };
  }

  async invite(
    actor: AuthenticatedUserActor,
    input: InvitePortalUserInput,
    _reqInfo: ClientRequestInfo,
  ): Promise<PortalUserView> {
    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can invite portal users');
    }

    const email = input.email.trim().toLowerCase();
    const existing = await this.userModel.findOne({ email }).lean().exec();
    if (existing) {
      throw new ApiException('ALREADY_REGISTERED', `A user with email ${email} already exists`);
    }

    const targetKey = this.resolveRoleKey(input.role);
    let role = await this.roleRepo.findByKey(targetKey);
    if (!role) {
      role = await this.roleRepo.findByKey(input.role.trim().toUpperCase());
    }
    if (!role) {
      role = await this.roleRepo.findByKey('BOOKING_STAFF');
    }
    if (!role) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Role ${input.role} does not exist`);
    }

    const token = randomBytes(32).toString('base64url');
    const tokenHash = hashToken(token);
    const expiresAt = new Date(Date.now() + INVITATION_DAYS * DAY_MS);
    const actorId = new Types.ObjectId(actor.userId);
    const opObjectId = new Types.ObjectId(operatorId);

    const created = await this.transactions.run(async (session) => {
      const [user] = await this.userModel.create(
        [
          {
            name: input.name.trim(),
            email,
            userType: 'OPERATOR_STAFF',
            operatorId: opObjectId,
            roleIds: [role._id],
            dataScope: { type: 'OWN_OPERATOR', operatorIds: [opObjectId] },
            status: 'INVITED',
            permissionVersion: 1,
            mfa: { enabled: false, recoveryCodeHashes: [] },
            preferredLanguage: 'en',
          },
        ],
        { session },
      );
      if (!user) {
        throw new ApiException('INTERNAL_ERROR', 'Failed to create portal user document');
      }

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

    const inviteUrl = `${this.clientBaseUrl}/accept-invite?token=${token}`;

    try {
      await this.messageSender.send({
        channel: 'EMAIL',
        kind: 'GENERAL',
        recipientName: input.name.trim(),
        address: email,
        subject: 'Invitation to Abra Travels Operator Portal',
        body:
          `Hello ${input.name.trim()},\n\n` +
          `You have been invited to join the operator portal as ${CLIENT_ROLE_NAMES[role.key] ?? role.name}.\n\n` +
          `Please set your password using this link (valid for 7 days):\n${inviteUrl}\n\n` +
          `Abra Travels Team`,
        userId: created._id,
      });
    } catch (err) {
      this.logger.warn({ email, err }, 'Failed to deliver portal user invitation email');
    }

    return {
      id: created._id.toHexString(),
      operatorId,
      name: created.name ?? '',
      email: created.email ?? '',
      role: role.key,
      roleName: CLIENT_ROLE_NAMES[role.key] ?? role.name,
      status: 'INVITED',
      lastSeen: null,
      createdAt: created.createdAt ? created.createdAt.toISOString() : new Date().toISOString(),
      inviteUrl,
    };
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdatePortalUserInput,
    client: ClientRequestInfo,
  ): Promise<PortalUserView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can update portal users');
    }

    const user = await this.userModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(operatorId),
      userType: 'OPERATOR_STAFF',
    });

    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    let nextRole: { _id: Types.ObjectId; key: string; name: string } | null = null;
    if (input.role) {
      const targetKey = this.resolveRoleKey(input.role);
      let role = await this.roleRepo.findByKey(targetKey);
      if (!role) {
        role = await this.roleRepo.findByKey(input.role.trim().toUpperCase());
      }
      if (role) {
        nextRole = role;
      }
    }

    const beforeState = {
      name: user.name,
      roleIds: user.roleIds.map((r) => r.toHexString()),
    };

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'portal-user.updated',
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
        if (!res) throw new ApiException('RESOURCE_NOT_FOUND', 'Portal user not found.');
        return res;
      },
    });

    return this.get(actor, updated._id.toHexString());
  }

  async deactivate(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<PortalUserView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can deactivate portal users');
    }

    if (actor.userId === id) {
      throw new ApiException('PERMISSION_DENIED', 'You cannot deactivate your own account');
    }

    const user = await this.userModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(operatorId),
      userType: 'OPERATOR_STAFF',
    });

    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'portal-user.deactivated',
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
        if (!res) throw new ApiException('RESOURCE_NOT_FOUND', 'Portal user not found.');
        return res;
      },
    });

    await this.sessionsService.revokeAllForUser(user._id.toHexString(), 'ACCOUNT_DISABLED');

    return this.get(actor, updated._id.toHexString());
  }

  async activate(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<PortalUserView> {
    if (!isValidObjectId(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const operatorId = actor.operatorId;
    if (!operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only operator staff can activate portal users');
    }

    const user = await this.userModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(operatorId),
      userType: 'OPERATOR_STAFF',
    });

    if (!user) {
      throw new ApiException('RESOURCE_NOT_FOUND', `Portal user ${id} not found`);
    }

    const updated = await this.auditedChanges.run<User & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'portal-user.activated',
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
        if (!res) throw new ApiException('RESOURCE_NOT_FOUND', 'Portal user not found.');
        return res;
      },
    });

    return this.get(actor, updated._id.toHexString());
  }
}
