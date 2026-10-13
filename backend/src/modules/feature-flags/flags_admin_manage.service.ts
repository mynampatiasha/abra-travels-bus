import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { InjectModel } from '@nestjs/mongoose';
import { type Request } from 'express';
import { type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import {
  type AuthenticatedUserActor,
  isAuthenticatedUserActor,
  type UserType,
} from '../../common/request-context/request-actor';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { EffectivePermissionsService } from '../rbac/services/effective-permissions.service';

// ===== 0. SCHEMAS ===================================================================
// `feature_flags`: one row per switch (the list is fixed in code, DEFAULT_FLAGS). `maintenance`:
// one document. They sit in this file, the one that needs them, so the two feature files never
// import each other in a circle.

export const FEATURE_FLAG_MODEL = 'FeatureFlag';
export const MAINTENANCE_MODEL = 'Maintenance';

/** The switches of the platform. A new switch is a line here, so the guard and the screen agree. */
export const DEFAULT_FLAGS = [
  {
    key: 'live_tracking',
    name: 'Live tracking',
    description: 'Customers see the bus on a map',
    on: true,
  },
  {
    key: 'whatsapp_chatbot',
    name: 'WhatsApp chatbot',
    description: 'Booking help on WhatsApp',
    on: false,
  },
  {
    key: 'ai_support',
    name: 'AI support assistant',
    description: 'AI answers common questions',
    on: false,
  },
  { key: 'women_safety', name: 'Women safety', description: 'SOS and trip sharing', on: true },
  { key: 'partner_api', name: 'Partner API', description: 'External agents', on: false },
  {
    key: 'dynamic_pricing',
    name: 'Dynamic pricing',
    description: 'Fares change with demand',
    on: false,
  },
  {
    key: 'mobile_app',
    name: 'Mobile app booking',
    description: 'Booking in the customer app',
    on: true,
  },
  { key: 'driver_app', name: 'Driver app', description: 'Driver check-in and GPS', on: true },
  {
    key: 'advanced_analytics',
    name: 'Advanced analytics',
    description: 'Extra reports',
    on: false,
  },
] as const;
export type FeatureKey = (typeof DEFAULT_FLAGS)[number]['key'];
export const FEATURE_KEYS = DEFAULT_FLAGS.map((flag) => flag.key) as [FeatureKey, ...FeatureKey[]];

export interface FeatureFlag {
  key: FeatureKey;
  name: string;
  description: string;
  on: boolean;
  updatedByUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export const featureFlagSchema = new Schema<FeatureFlag>(
  {
    key: { type: String, required: true, enum: FEATURE_KEYS },
    name: { type: String, required: true, maxlength: 80 },
    description: { type: String, required: true, maxlength: 200 },
    on: { type: Boolean, required: true },
    updatedByUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'feature_flags', timestamps: true, versionKey: false },
);
featureFlagSchema.index({ key: 1 }, { unique: true });

export const MAINTENANCE_SCOPES = ['global', 'customer', 'operator', 'partner', 'admin'] as const;
export type MaintenanceScope = (typeof MAINTENANCE_SCOPES)[number];
export type MaintenanceApp = Exclude<MaintenanceScope, 'global'>;

export const DEFAULT_MAINTENANCE_MESSAGE = 'We are improving Abra Travels. Back soon.';

export interface Maintenance {
  key: 'default';
  scopes: Record<MaintenanceScope, boolean>;
  /** What the apps show people. */
  message: string;
  /** Optional window. Without it, a switched-on scope is active until it is switched off. */
  from?: Date | null;
  to?: Date | null;
  updatedByUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export const maintenanceSchema = new Schema<Maintenance>(
  {
    key: { type: String, required: true, enum: ['default'] },
    scopes: { type: Schema.Types.Mixed, required: true },
    message: { type: String, required: true, maxlength: 300 },
    from: { type: Date, default: null },
    to: { type: Date, default: null },
    updatedByUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'maintenance', timestamps: true, versionKey: false, minimize: false },
);
maintenanceSchema.index({ key: 1 }, { unique: true });

const NO_SCOPES: Record<MaintenanceScope, boolean> = {
  global: false,
  customer: false,
  operator: false,
  partner: false,
  admin: false,
};

// ===== 1. THE RULES (pure, so they can be tested without a server) ==================

/** Which app a signed-in person is using, by the kind of account. */
export function appOfUserType(userType: UserType): MaintenanceApp | undefined {
  switch (userType) {
    case 'CUSTOMER':
      return 'customer';
    case 'OPERATOR_STAFF':
    case 'DRIVER':
      return 'operator';
    case 'PARTNER_USER':
      return 'partner';
    case 'STAFF':
      return 'admin';
    default:
      return undefined;
  }
}

/** Which app a request without a token comes from: the `X-Abra-App` header the apps send. */
export function appOfHeader(value: unknown): MaintenanceApp | undefined {
  switch (typeof value === 'string' ? value.toLowerCase() : '') {
    case 'customer':
    case 'website':
      return 'customer';
    case 'operator':
    case 'driver':
      return 'operator';
    case 'partner':
      return 'partner';
    case 'admin':
      return 'admin';
    default:
      return undefined;
  }
}

/**
 * Is this app in maintenance right now? `global` stops the customer, operator and partner apps;
 * the admin portal has its own switch, so staff can always get in to switch maintenance off. A
 * scope that is on counts only inside the window, when there is one.
 */
export function maintenanceActive(
  maintenance: Pick<Maintenance, 'scopes' | 'from' | 'to'>,
  app: MaintenanceApp,
  now: Date,
): boolean {
  const on = maintenance.scopes[app] || (app !== 'admin' && maintenance.scopes.global);
  if (!on) return false;
  if (maintenance.from && now < maintenance.from) return false;
  if (maintenance.to && now >= maintenance.to) return false;
  return true;
}

/** Paths that keep working in maintenance: health checks, status, and the means to sign in and out. */
const EXEMPT_PATHS = [
  /^\/health(\/|$)/,
  /^\/maintenance\/status$/,
  /^\/features$/,
  /^\/auth\/(login|mfa\/verify|refresh|logout)$/,
];

export function exemptFromMaintenance(path: string): boolean {
  return EXEMPT_PATHS.some((pattern) => pattern.test(path));
}

// ===== 2. THE CURRENT STATE, KEPT FOR A FEW SECONDS =================================

export interface AvailabilitySnapshot {
  flags: Readonly<Record<string, boolean>>;
  maintenance: Pick<Maintenance, 'scopes' | 'message' | 'from' | 'to'>;
}

const CACHE_MS = 5_000;

/**
 * What every request asks first: is this app in maintenance, is this feature on. It reads the
 * two collections at most every few seconds per server, so a change made by an administrator
 * reaches every server within seconds and a request costs no database call.
 */
@Injectable()
export class AvailabilityState {
  private cached: { value: AvailabilitySnapshot; at: number } | undefined;

  constructor(
    @InjectModel(FEATURE_FLAG_MODEL) private readonly flags: Model<FeatureFlag>,
    @InjectModel(MAINTENANCE_MODEL) private readonly maintenance: Model<Maintenance>,
  ) {}

  async snapshot(): Promise<AvailabilitySnapshot> {
    if (this.cached && Date.now() - this.cached.at < CACHE_MS) return this.cached.value;
    const [rows, maintenance] = await Promise.all([
      this.flags.find().lean<FeatureFlag[]>().exec(),
      this.maintenance.findOne({ key: 'default' }).lean<Maintenance>().exec(),
    ]);
    const flags: Record<string, boolean> = Object.fromEntries(
      DEFAULT_FLAGS.map((flag) => [flag.key, flag.on]),
    );
    for (const row of rows) flags[row.key] = row.on;
    const value: AvailabilitySnapshot = {
      flags,
      maintenance: {
        scopes: { ...NO_SCOPES, ...(maintenance?.scopes ?? {}) },
        message: maintenance?.message ?? DEFAULT_MAINTENANCE_MESSAGE,
        from: maintenance?.from ?? null,
        to: maintenance?.to ?? null,
      },
    };
    this.cached = { value, at: Date.now() };
    return value;
  }

  invalidate(): void {
    this.cached = undefined;
  }

  /** For other features: is this switch on? */
  async isOn(key: FeatureKey): Promise<boolean> {
    return (await this.snapshot()).flags[key] ?? false;
  }
}

// ===== 3. THE GUARD =================================================================

export const REQUIRED_FEATURE = 'abra:requiredFeature';

/** Refuses the endpoint with a clear sentence while the switch is off. */
export const RequireFeature = (key: FeatureKey): MethodDecorator & ClassDecorator =>
  SetMetadata(REQUIRED_FEATURE, key);

/** The permission that lets staff in while the admin portal is in maintenance. */
export const MAINTENANCE_BYPASS = 'maintenance.bypass' as const;

/**
 * Global guard, last in the chain: enforces maintenance and feature switches on every request on
 * the server, whatever the apps show. Signed-in people are placed by their kind of account;
 * requests without a token by the `X-Abra-App` header. Staff with `maintenance.bypass` (and the
 * Super Admin) are never locked out of the admin portal.
 */
@Injectable()
export class AvailabilityGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly state: AvailabilityState,
    private readonly permissions: EffectivePermissionsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const request = context.switchToHttp().getRequest<Request>();
    const path = request.path.replace(/^\/api\/v1/, '');
    const snapshot = await this.state.snapshot();

    if (!exemptFromMaintenance(path)) {
      const actor = RequestContextService.actor();
      const app = isAuthenticatedUserActor(actor)
        ? appOfUserType(actor.userType)
        : appOfHeader(request.headers['x-abra-app']);
      if (app && maintenanceActive(snapshot.maintenance, app, new Date())) {
        if (!(isAuthenticatedUserActor(actor) && (await this.mayBypass(actor)))) {
          throw new ApiException('MAINTENANCE_MODE', snapshot.maintenance.message, {
            app,
            until: snapshot.maintenance.to ? snapshot.maintenance.to.toISOString() : null,
          });
        }
      }
    }

    const feature = this.reflector.getAllAndOverride<FeatureKey | undefined>(REQUIRED_FEATURE, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (feature && snapshot.flags[feature] === false) {
      throw new ApiException('SERVICE_UNAVAILABLE', 'This feature is switched off right now.', {
        feature,
      });
    }
    return true;
  }

  private async mayBypass(actor: AuthenticatedUserActor): Promise<boolean> {
    if (actor.userType !== 'STAFF') return false;
    const mine = await this.permissions.forActor(actor);
    return mine.hasWildcard || mine.permissions.has(MAINTENANCE_BYPASS);
  }
}

// ===== 4. START-UP: make sure every switch and the maintenance row exist ============

@Injectable()
export class FlagsStartupSeeder implements OnApplicationBootstrap {
  private readonly logger = new Logger(FlagsStartupSeeder.name);

  constructor(
    @InjectModel(FEATURE_FLAG_MODEL) private readonly flags: Model<FeatureFlag>,
    @InjectModel(MAINTENANCE_MODEL) private readonly maintenance: Model<Maintenance>,
  ) {}

  /** Only inserts what is missing; a switch an administrator changed is never reset. */
  async onApplicationBootstrap(): Promise<void> {
    await this.flags.createIndexes();
    await this.maintenance.createIndexes();
    for (const flag of DEFAULT_FLAGS) {
      await this.flags.updateOne(
        { key: flag.key },
        { $setOnInsert: { ...flag } },
        { upsert: true },
      );
    }
    await this.maintenance.updateOne(
      { key: 'default' },
      {
        $setOnInsert: {
          key: 'default',
          scopes: NO_SCOPES,
          message: DEFAULT_MAINTENANCE_MESSAGE,
          from: null,
          to: null,
        },
      },
      { upsert: true },
    );
    this.logger.log({ flags: DEFAULT_FLAGS.length }, 'Feature flags and maintenance ready');
  }
}

// ===== 5. VIEWS =====================================================================

export interface FlagView {
  key: FeatureKey;
  name: string;
  description: string;
  on: boolean;
  updatedAt: string | null;
}

export interface MaintenanceView {
  scopes: Record<MaintenanceScope, boolean>;
  message: string;
  from: string | null;
  to: string | null;
  /** Whether each app is stopped at this moment (a switched-on scope outside its window is not). */
  activeNow: Record<MaintenanceApp, boolean>;
  updatedAt: string | null;
}

export interface MaintenanceStatus {
  active: boolean;
  message: string | null;
  until: string | null;
}

function maintenanceViewOf(
  maintenance: Pick<Maintenance, 'scopes' | 'message' | 'from' | 'to'> & {
    updatedAt?: Date | undefined;
  },
): MaintenanceView {
  const now = new Date();
  return {
    scopes: { ...NO_SCOPES, ...maintenance.scopes },
    message: maintenance.message,
    from: maintenance.from ? maintenance.from.toISOString() : null,
    to: maintenance.to ? maintenance.to.toISOString() : null,
    activeNow: {
      customer: maintenanceActive(maintenance, 'customer', now),
      operator: maintenanceActive(maintenance, 'operator', now),
      partner: maintenanceActive(maintenance, 'partner', now),
      admin: maintenanceActive(maintenance, 'admin', now),
    },
    updatedAt: maintenance.updatedAt ? maintenance.updatedAt.toISOString() : null,
  };
}

// ===== 6. THE ADMIN PAGE ============================================================

type StoredFlag = FeatureFlag & { _id: Types.ObjectId };
type StoredMaintenance = Maintenance & { _id: Types.ObjectId };

export interface MaintenanceChange {
  scopes?: Partial<Record<MaintenanceScope, boolean>> | undefined;
  message?: string | undefined;
  from?: Date | null | undefined;
  to?: Date | null | undefined;
  reason: string;
}

/**
 * The admin "Feature flags and maintenance" page. Every change is audited with its reason and
 * reaches every server within seconds.
 */
@Injectable()
export class FlagsAdminManageService {
  constructor(
    @InjectModel(FEATURE_FLAG_MODEL) private readonly flags: Model<FeatureFlag>,
    @InjectModel(MAINTENANCE_MODEL) private readonly maintenance: Model<Maintenance>,
    private readonly state: AvailabilityState,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async listFlags(): Promise<FlagView[]> {
    const rows = await this.flags.find().lean<StoredFlag[]>().exec();
    return DEFAULT_FLAGS.map((definition) => {
      const row = rows.find((candidate) => candidate.key === definition.key);
      return {
        key: definition.key,
        name: definition.name,
        description: definition.description,
        on: row?.on ?? definition.on,
        updatedAt: row?.updatedAt ? row.updatedAt.toISOString() : null,
      };
    });
  }

  async setFlag(
    actor: AuthenticatedUserActor,
    key: FeatureKey,
    on: boolean,
    reason: string,
    client: ClientRequestInfo,
  ): Promise<FlagView> {
    const definition = DEFAULT_FLAGS.find((candidate) => candidate.key === key);
    if (!definition) throw new ApiException('RESOURCE_NOT_FOUND', 'That feature was not found');
    const before = await this.flags.findOne({ key }).lean<StoredFlag>().exec();
    const saved = await this.changes.run<StoredFlag>({
      actor,
      client,
      action: 'feature-flag.changed',
      entityType: `feature_flag:${key}`,
      before: { on: before?.on ?? definition.on },
      reason,
      apply: async (session) => {
        const row = await this.flags
          .findOneAndUpdate(
            { key },
            {
              $set: { on, updatedByUserId: new Types.ObjectId(actor.userId) },
              $setOnInsert: { key, name: definition.name, description: definition.description },
            },
            { upsert: true, returnDocument: 'after', session },
          )
          .lean<StoredFlag>()
          .exec();
        if (!row) throw new Error('Feature flag could not be saved');
        return row;
      },
      describe: (row) => ({ on: row.on }),
    });
    this.state.invalidate();
    return {
      key,
      name: definition.name,
      description: definition.description,
      on: saved.on,
      updatedAt: saved.updatedAt ? saved.updatedAt.toISOString() : null,
    };
  }

  async getMaintenance(): Promise<MaintenanceView> {
    const stored = await this.maintenance
      .findOne({ key: 'default' })
      .lean<StoredMaintenance>()
      .exec();
    return maintenanceViewOf(
      stored ?? { scopes: NO_SCOPES, message: DEFAULT_MAINTENANCE_MESSAGE, from: null, to: null },
    );
  }

  async changeMaintenance(
    actor: AuthenticatedUserActor,
    input: MaintenanceChange,
    client: ClientRequestInfo,
  ): Promise<MaintenanceView> {
    const { reason, scopes, message, from, to } = input;
    if (scopes === undefined && message === undefined && from === undefined && to === undefined) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    const before = await this.getMaintenance();
    const nextFrom = from === undefined ? (before.from ? new Date(before.from) : null) : from;
    const nextTo = to === undefined ? (before.to ? new Date(before.to) : null) : to;
    if (nextFrom && nextTo && nextTo <= nextFrom) {
      throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
        location: 'body',
        issues: [{ path: 'to', code: 'custom', message: 'End must be after start' }],
      });
    }
    const set: Record<string, unknown> = { updatedByUserId: new Types.ObjectId(actor.userId) };
    for (const [scope, on] of Object.entries(scopes ?? {})) set[`scopes.${scope}`] = on;
    if (message !== undefined) set.message = message;
    if (from !== undefined) set.from = from;
    if (to !== undefined) set.to = to;

    const saved = await this.changes.run<StoredMaintenance>({
      actor,
      client,
      action: 'maintenance.changed',
      entityType: 'maintenance',
      before: { scopes: before.scopes, from: before.from, to: before.to },
      reason,
      apply: async (session) => {
        const row = await this.maintenance
          .findOneAndUpdate(
            { key: 'default' },
            { $set: set, $setOnInsert: { key: 'default' } },
            { upsert: true, returnDocument: 'after', session },
          )
          .lean<StoredMaintenance>()
          .exec();
        if (!row) throw new Error('Maintenance could not be saved');
        return row;
      },
      describe: (row) => ({
        scopes: row.scopes,
        from: row.from ?? null,
        to: row.to ?? null,
        messageChanged: message !== undefined,
      }),
    });
    this.state.invalidate();
    return maintenanceViewOf(saved);
  }

  /** What an app asks before it shows anything: am I in maintenance, and what do I tell people? */
  async statusFor(app: MaintenanceApp): Promise<MaintenanceStatus> {
    const { maintenance } = await this.state.snapshot();
    const active = maintenanceActive(maintenance, app, new Date());
    return {
      active,
      message: active ? maintenance.message : null,
      until: active && maintenance.to ? maintenance.to.toISOString() : null,
    };
  }

  /** Every switch as a plain map, for apps to hide what is off. */
  async featureMap(): Promise<Record<string, boolean>> {
    return { ...(await this.state.snapshot()).flags };
  }
}
