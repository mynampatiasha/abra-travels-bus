import { Inject, Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';

/*
 * Commission rules (admin): what Abra earns on each booking. A rule belongs to one operator, one
 * route or one bus type, is a percentage or a flat amount per seat, and is versioned: changing a
 * rule adds a version with its own start date, so a booking already made keeps what it was sold
 * with. The one function that turns a rule and a fare into money is `computePrice`; the booking
 * code calls `CommissionService.calculate`, so the customer price is always worked out on the server.
 *
 * Money is whole numbers: PERCENT value = percent x 100 (1000 is 10%); FLAT value = paise per seat.
 */

export const COMMISSION_RULE_MODEL = 'CommissionRule';
export const COMMISSION_HISTORY_MODEL = 'CommissionHistory';
export const COMMISSION_DEFAULT_MODEL = 'CommissionDefault';

export const COMMISSION_SCOPES = ['OPERATOR', 'ROUTE', 'BUS_TYPE'] as const;
export type CommissionScope = (typeof COMMISSION_SCOPES)[number];
export const COMMISSION_MODES = ['PERCENT', 'FLAT'] as const;
export type CommissionMode = (typeof COMMISSION_MODES)[number];
export const COMMISSION_STATUSES = ['ACTIVE', 'INACTIVE'] as const;
export type CommissionStatus = (typeof COMMISSION_STATUSES)[number];

/** 40%, as the demo allows. */
export const MAX_PERCENT_X100 = 4000;
export const MAX_NOTE_LENGTH = 300;
export const MIN_SEATS = 1;
export const MAX_SEATS = 6;

/** Where the Payout and fees feature stores its settings: read here, never written. */
export const PAYOUT_SETTINGS_COLLECTION = 'payout_settings';

/** The model names the pick-lists and name lookups read, so this module imports no other module. */
const TARGET_MODELS: Readonly<Record<CommissionScope, string>> = {
  OPERATOR: 'Operator',
  ROUTE: 'Route',
  BUS_TYPE: 'BusType',
};

// ===== 1. STORED DOCUMENTS =====

export interface CommissionVersion {
  version: number;
  mode: CommissionMode;
  value: number;
  /** `YYYY-MM-DD`, an India date. */
  effectiveFrom: string;
  agreedNote: string;
  createdAt: Date;
  createdBy: Types.ObjectId;
}

export interface CommissionRule {
  /** `CR-1`: the id staff read and say. */
  shortId: string;
  seq: number;
  scope: CommissionScope;
  targetId: Types.ObjectId;
  targetName: string;
  /** The latest version, so a list reads one flat document. */
  mode: CommissionMode;
  value: number;
  effectiveFrom: string;
  agreedNote: string;
  version: number;
  status: CommissionStatus;
  versions: CommissionVersion[];
  /** `SCOPE:targetId`, present only while ACTIVE and not deleted: a unique index keeps one active rule per target. */
  activeKey?: string | null;
  createdBy: Types.ObjectId;
  deletedAt: Date | null;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredCommissionRule = CommissionRule & { _id: Types.ObjectId };

export const HISTORY_ACTIONS = [
  'Created',
  'Edited',
  'Activated',
  'Deactivated',
  'Deleted',
  'Restored',
  'Changed',
] as const;
export type HistoryAction = (typeof HISTORY_ACTIONS)[number];

export interface CommissionHistory {
  /** `CR-1`, or `Default` for the default rule. */
  ruleId: string;
  version: number | null;
  action: HistoryAction;
  who: Types.ObjectId;
  whoName: string;
  at: Date;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
}
export type StoredCommissionHistory = CommissionHistory & { _id: Types.ObjectId };

/** The fallback rule, used when no rule applies. A single document. */
export interface CommissionDefault {
  mode: CommissionMode;
  value: number;
  updatedBy: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredCommissionDefault = CommissionDefault & { _id: Types.ObjectId };

const modeAndValue = {
  mode: { type: String, enum: COMMISSION_MODES, required: true },
  value: { type: Number, required: true, min: 0 },
};

const versionSchema = new Schema<CommissionVersion>(
  {
    version: { type: Number, required: true },
    ...modeAndValue,
    effectiveFrom: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
    agreedNote: { type: String, default: '', maxlength: MAX_NOTE_LENGTH },
    createdAt: { type: Date, required: true },
    createdBy: { type: Schema.Types.ObjectId, required: true },
  },
  { _id: false },
);

/** `commission_rules`. */
export const commissionRuleSchema = new Schema<CommissionRule>(
  {
    shortId: { type: String, required: true },
    seq: { type: Number, required: true },
    scope: { type: String, enum: COMMISSION_SCOPES, required: true },
    targetId: { type: Schema.Types.ObjectId, required: true },
    targetName: { type: String, required: true, maxlength: 160 },
    ...modeAndValue,
    effectiveFrom: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
    agreedNote: { type: String, default: '', maxlength: MAX_NOTE_LENGTH },
    version: { type: Number, required: true },
    status: { type: String, enum: COMMISSION_STATUSES, required: true },
    versions: { type: [versionSchema], default: [] },
    activeKey: { type: String },
    createdBy: { type: Schema.Types.ObjectId, required: true },
    deletedAt: { type: Date, default: null },
  },
  { collection: 'commission_rules', timestamps: true, versionKey: false },
);
commissionRuleSchema.index({ shortId: 1 }, { unique: true });
commissionRuleSchema.index({ seq: 1 }, { unique: true });
commissionRuleSchema.index(
  { activeKey: 1 },
  { unique: true, partialFilterExpression: { activeKey: { $type: 'string' } } },
);
commissionRuleSchema.index({ scope: 1, targetId: 1, status: 1 });

/** `commission_history`. */
export const commissionHistorySchema = new Schema<CommissionHistory>(
  {
    ruleId: { type: String, required: true, maxlength: 20 },
    version: { type: Number, default: null },
    action: { type: String, enum: HISTORY_ACTIONS, required: true },
    who: { type: Schema.Types.ObjectId, required: true },
    whoName: { type: String, required: true, maxlength: 120 },
    at: { type: Date, required: true },
    before: { type: Schema.Types.Mixed, default: null },
    after: { type: Schema.Types.Mixed, default: null },
  },
  { collection: 'commission_history', minimize: false, versionKey: false },
);
commissionHistorySchema.index({ at: -1 });
commissionHistorySchema.index({ ruleId: 1, at: -1 });

/** `commission_default`: holds at most one document. */
export const commissionDefaultSchema = new Schema<CommissionDefault>(
  { ...modeAndValue, updatedBy: { type: Schema.Types.ObjectId, required: true } },
  { collection: 'commission_default', timestamps: true, versionKey: false },
);

// ===== 2. PURE RULES (no database) =====

/** Today's date in India (`YYYY-MM-DD`): effective dates are India dates. */
export function todayIst(now: Date = new Date()): string {
  return new Date(now.getTime() + 330 * 60 * 1000).toISOString().slice(0, 10);
}

export function isValidDay(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const day = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(day.getTime()) && day.toISOString().slice(0, 10) === value;
}

/** The version of a rule that is in force on a day, or undefined while none has started. */
export function versionInEffect(
  versions: readonly CommissionVersion[],
  onDay: string,
): CommissionVersion | undefined {
  let best: CommissionVersion | undefined;
  for (const candidate of versions) {
    if (candidate.effectiveFrom > onDay) continue;
    if (
      !best ||
      candidate.effectiveFrom > best.effectiveFrom ||
      (candidate.effectiveFrom === best.effectiveFrom && candidate.version > best.version)
    ) {
      best = candidate;
    }
  }
  return best;
}

export interface PriceAmounts {
  operatorFare: number;
  commission: number;
  fareShown: number;
  gst: number;
  convenienceFee: number;
  customerPays: number;
  operatorReceives: number;
}

/**
 * The one place that turns a rule and a fare into money (paise). Commission is added on top of the
 * operator fare; GST is charged on the fare shown to the customer; the operator always receives the
 * fare they set. A percentage is rounded once on the whole fare (all seats); flat is value x seats.
 */
export function computePrice(input: {
  farePerSeatPaise: number;
  seats: number;
  mode: CommissionMode;
  value: number;
  gstPct: number;
  convenienceFeePaise: number;
}): PriceAmounts {
  const operatorFare = input.farePerSeatPaise * input.seats;
  const commission =
    input.mode === 'PERCENT'
      ? Math.round((operatorFare * input.value) / 10_000)
      : input.value * input.seats;
  const fareShown = operatorFare + commission;
  const gst = Math.round((fareShown * input.gstPct) / 100);
  return {
    operatorFare,
    commission,
    fareShown,
    gst,
    convenienceFee: input.convenienceFeePaise,
    customerPays: fareShown + gst + input.convenienceFeePaise,
    operatorReceives: operatorFare,
  };
}

/** "10%" or "Rs 60 per seat". */
export function formatCommission(mode: CommissionMode, value: number): string {
  const trimmed = (number: number) =>
    Number.isInteger(number) ? String(number) : number.toFixed(2).replace(/0+$/, '');
  return mode === 'PERCENT' ? `${trimmed(value / 100)}%` : `Rs ${trimmed(value / 100)} per seat`;
}

function fieldError(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

/** Checks a commission and returns it; the messages are the demo's own words. */
export function checkCommission(
  mode: CommissionMode,
  value: number,
): { mode: CommissionMode; value: number } {
  if (!Number.isSafeInteger(value) || value < 0)
    throw fieldError('value', 'Enter a value of zero or more');
  if (mode === 'PERCENT' && value > MAX_PERCENT_X100) {
    throw fieldError('value', 'Percentage must be 0 to 40');
  }
  return { mode, value };
}

function activeKeyOf(scope: CommissionScope, targetId: Types.ObjectId | string): string {
  return `${scope}:${String(targetId)}`;
}

// ===== 3. VIEWS =====

export interface CommissionRuleView {
  id: string;
  _id: string;
  scope: CommissionScope;
  targetId: string;
  targetName: string;
  mode: CommissionMode;
  value: number;
  /** "10%" or "Rs 60 per seat", as the table shows it. */
  commission: string;
  effectiveFrom: string;
  agreedNote: string;
  version: number;
  status: CommissionStatus;
  updatedAt: string;
  versions?: Array<{
    version: number;
    mode: CommissionMode;
    value: number;
    effectiveFrom: string;
    agreedNote: string;
    createdAt: string;
  }>;
}

export function ruleViewOf(rule: StoredCommissionRule, withVersions = false): CommissionRuleView {
  return {
    id: rule.shortId,
    _id: rule._id.toHexString(),
    scope: rule.scope,
    targetId: rule.targetId.toHexString(),
    targetName: rule.targetName,
    mode: rule.mode,
    value: rule.value,
    commission: formatCommission(rule.mode, rule.value),
    effectiveFrom: rule.effectiveFrom,
    agreedNote: rule.agreedNote,
    version: rule.version,
    status: rule.status,
    updatedAt: (rule.updatedAt ?? new Date()).toISOString(),
    ...(withVersions
      ? {
          versions: [...rule.versions]
            .sort((a, b) => b.version - a.version)
            .map((item) => ({
              version: item.version,
              mode: item.mode,
              value: item.value,
              effectiveFrom: item.effectiveFrom,
              agreedNote: item.agreedNote,
              createdAt: item.createdAt.toISOString(),
            })),
        }
      : {}),
  };
}

export interface CommissionDefaultView {
  configured: boolean;
  mode: CommissionMode | null;
  value: number | null;
  commission: string | null;
  updatedAt: string | null;
}

export interface CommissionHistoryView {
  id: string;
  ruleId: string;
  version: number | null;
  action: HistoryAction;
  /** "CR-1: Edited to v2", as the timeline reads. */
  label: string;
  who: string;
  at: string;
}

export interface TargetChoice {
  id: string;
  name: string;
}

export interface ResolvedRule {
  ruleId: string;
  scope: CommissionScope | 'DEFAULT';
  targetName: string;
  version: number | null;
  mode: CommissionMode;
  value: number;
}

/** The copy every booking stores of the rule that applied to it. */
export interface BookingRuleCopy {
  ruleId: string;
  version: number | null;
  mode: CommissionMode;
  value: number;
}

export interface CalculationResult {
  rule: ResolvedRule & { commission: string };
  amounts: PriceAmounts;
  /** What the booking stores next to the booking. */
  ruleCopy: BookingRuleCopy;
  gstPct: number;
}

/** The GST and convenience fee the customer is charged on, from the Payout and fees settings. */
export interface PayoutFees {
  gstPct: number;
  convenienceFeePaise: number;
}
export const PAYOUT_FEES_PROVIDER = Symbol('COMMISSION_PAYOUT_FEES_PROVIDER');
export type PayoutFeesProvider = () => Promise<PayoutFees | undefined>;

/** The columns of the Rules table a person can sort by (the demo sorts every column). */
export const RULE_SORTS = [
  'id',
  'scope',
  'target',
  'commission',
  'from',
  'version',
  'status',
  'note',
] as const;
export type RuleSort = (typeof RULE_SORTS)[number];

const RULE_SORT_FIELDS: Readonly<Record<RuleSort, string>> = {
  id: 'seq',
  scope: 'scope',
  target: 'targetName',
  commission: 'value',
  from: 'effectiveFrom',
  version: 'version',
  status: 'status',
  note: 'agreedNote',
};

export interface RuleListQuery {
  search?: string | undefined;
  scope?: CommissionScope | undefined;
  status?: CommissionStatus | undefined;
  /** Column to sort by; the rule number when not given. */
  sort?: RuleSort | undefined;
  dir?: 'asc' | 'desc' | undefined;
  page: number;
  pageSize: number;
}

export interface RuleInput {
  scope: CommissionScope;
  targetId: string;
  mode: CommissionMode;
  value: number;
  effectiveFrom: string;
  agreedNote?: string | undefined;
}

export interface VersionInput {
  mode: CommissionMode;
  value: number;
  effectiveFrom: string;
  agreedNote?: string | undefined;
}

export interface CalculateInput {
  farePerSeatPaise: number;
  seats: number;
  operatorId?: string | undefined;
  routeId?: string | undefined;
  busTypeId?: string | undefined;
  /** Defaults to today; the booking may pass the day of booking. */
  onDay?: string | undefined;
}

// ===== 4. THE SERVICE =====

type Described = Record<string, unknown>;

@Injectable()
export class CommissionService {
  constructor(
    @InjectModel(COMMISSION_RULE_MODEL) private readonly rules: Model<CommissionRule>,
    @InjectModel(COMMISSION_HISTORY_MODEL) private readonly history: Model<CommissionHistory>,
    @InjectModel(COMMISSION_DEFAULT_MODEL) private readonly defaults: Model<CommissionDefault>,
    @InjectConnection() private readonly connection: Connection,
    @Inject(PAYOUT_FEES_PROVIDER) private readonly payoutFees: PayoutFeesProvider,
    private readonly changes: AuditedChangeRunner,
    private readonly users: UsersService,
  ) {}

  // ----- reading -----

  async list(query: RuleListQuery): Promise<PaginatedResult<CommissionRuleView>> {
    const filter = this.filterOf(query);
    const direction = query.dir === 'desc' ? -1 : 1;
    const field = RULE_SORT_FIELDS[query.sort ?? 'id'];
    const [items, total] = await Promise.all([
      this.rules
        .find(filter)
        // The rule number breaks ties, so the order is the same on every page
        .sort(field === 'seq' ? { seq: direction } : { [field]: direction, seq: 1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredCommissionRule[]>()
        .exec(),
      this.rules.countDocuments(filter).exec(),
    ]);
    return new PaginatedResult(
      items.map((rule) => ruleViewOf(rule)),
      query.page,
      query.pageSize,
      total,
    );
  }

  async get(shortId: string): Promise<CommissionRuleView> {
    return ruleViewOf(await this.live(shortId), true);
  }

  async getDefault(): Promise<CommissionDefaultView> {
    const stored = await this.defaults.findOne().lean<StoredCommissionDefault>().exec();
    if (!stored) {
      return { configured: false, mode: null, value: null, commission: null, updatedAt: null };
    }
    return {
      configured: true,
      mode: stored.mode,
      value: stored.value,
      commission: formatCommission(stored.mode, stored.value),
      updatedAt: (stored.updatedAt ?? new Date()).toISOString(),
    };
  }

  async listHistory(
    page: number,
    pageSize: number,
  ): Promise<PaginatedResult<CommissionHistoryView>> {
    const [items, total] = await Promise.all([
      this.history
        .find()
        .sort({ at: -1, _id: -1 })
        .skip((page - 1) * pageSize)
        .limit(pageSize)
        .lean<StoredCommissionHistory[]>()
        .exec(),
      this.history.estimatedDocumentCount().exec(),
    ]);
    return new PaginatedResult(
      items.map((row) => ({
        id: row._id.toHexString(),
        ruleId: row.ruleId,
        version: row.version,
        action: row.action,
        label: `${row.ruleId}: ${row.action}${
          row.action === 'Edited' && row.version ? ` to v${row.version}` : ''
        }`,
        who: row.whoName,
        at: row.at.toISOString(),
      })),
      page,
      pageSize,
      total,
    );
  }

  /** The operators, routes or bus types a rule can be about, for the "Which one" list. */
  async targets(scope: CommissionScope, search: string | undefined): Promise<TargetChoice[]> {
    const model = this.connection.model<Record<string, unknown>>(TARGET_MODELS[scope]);
    const text = search?.trim();
    const nameField = scope === 'OPERATOR' ? 'companyName' : 'name';
    const found = await model
      .find(text ? { [nameField]: { $regex: escapeRegExp(text), $options: 'i' } } : {})
      .sort({ [nameField]: 1 })
      .limit(100)
      .lean<Array<Record<string, unknown> & { _id: Types.ObjectId }>>()
      .exec();
    return found.map((record) => ({ id: record._id.toHexString(), name: nameOf(scope, record) }));
  }

  // ----- the price (also used by the booking) -----

  /**
   * The rule that applies and the money for a fare. Order: operator, route, bus type, the default.
   * A rule that is inactive, deleted or whose first version has not started is skipped; the version
   * in force on the day is used. Refuses, with a clear sentence, until a default rule and the
   * Payout and fees settings exist: nothing is guessed.
   */
  async calculate(input: CalculateInput): Promise<CalculationResult> {
    if (!Number.isSafeInteger(input.farePerSeatPaise) || input.farePerSeatPaise < 0) {
      throw fieldError('farePerSeatPaise', 'Enter the fare per seat');
    }
    if (!Number.isInteger(input.seats) || input.seats < MIN_SEATS || input.seats > MAX_SEATS) {
      throw fieldError('seats', `Seats must be ${MIN_SEATS} to ${MAX_SEATS}`);
    }
    const day = input.onDay ?? todayIst();
    const fees = await this.payoutFees();
    if (!fees) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'Save the Payout and fees settings (GST and convenience fee) before calculating a price.',
      );
    }
    const rule = await this.resolve(input, day);
    const amounts = computePrice({
      farePerSeatPaise: input.farePerSeatPaise,
      seats: input.seats,
      mode: rule.mode,
      value: rule.value,
      gstPct: fees.gstPct,
      convenienceFeePaise: fees.convenienceFeePaise,
    });
    return {
      rule: { ...rule, commission: formatCommission(rule.mode, rule.value) },
      amounts,
      ruleCopy: { ruleId: rule.ruleId, version: rule.version, mode: rule.mode, value: rule.value },
      gstPct: fees.gstPct,
    };
  }

  private async resolve(
    input: {
      operatorId?: string | undefined;
      routeId?: string | undefined;
      busTypeId?: string | undefined;
    },
    day: string,
  ): Promise<ResolvedRule> {
    const wanted: Array<[CommissionScope, string | undefined]> = [
      ['OPERATOR', input.operatorId],
      ['ROUTE', input.routeId],
      ['BUS_TYPE', input.busTypeId],
    ];
    for (const [scope, targetId] of wanted) {
      if (!targetId || !Types.ObjectId.isValid(targetId)) continue;
      const rule = await this.rules
        .findOne({
          scope,
          targetId: new Types.ObjectId(targetId),
          status: 'ACTIVE',
          deletedAt: null,
        })
        .lean<StoredCommissionRule>()
        .exec();
      const version = rule ? versionInEffect(rule.versions, day) : undefined;
      if (rule && version) {
        return {
          ruleId: rule.shortId,
          scope,
          targetName: rule.targetName,
          version: version.version,
          mode: version.mode,
          value: version.value,
        };
      }
    }
    const fallback = await this.defaults.findOne().lean<StoredCommissionDefault>().exec();
    if (!fallback) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'No commission rule applies and no default is saved. Save the default commission first.',
      );
    }
    return {
      ruleId: 'Default',
      scope: 'DEFAULT',
      targetName: 'Default rule',
      version: null,
      mode: fallback.mode,
      value: fallback.value,
    };
  }

  // ----- changing -----

  async create(
    actor: AuthenticatedUserActor,
    input: RuleInput,
    client: ClientRequestInfo,
  ): Promise<CommissionRuleView> {
    const { mode, value } = checkCommission(input.mode, input.value);
    this.assertDay(input.effectiveFrom);
    const note = this.cleanNote(input.agreedNote);
    const target = await this.target(input.scope, input.targetId);
    const who = await this.whoIs(actor);

    for (let attempt = 0; attempt < 4; attempt += 1) {
      const seq =
        ((await this.rules.findOne().sort({ seq: -1 }).lean<StoredCommissionRule>().exec())?.seq ??
          0) + 1;
      try {
        const created = await this.changes.run({
          actor,
          client,
          action: 'commission.rule.created',
          entityType: 'commission-rule',
          before: {},
          apply: async (session) => {
            const now = new Date();
            const [rule] = await this.rules.create(
              [
                {
                  shortId: `CR-${seq}`,
                  seq,
                  scope: input.scope,
                  targetId: target.id,
                  targetName: target.name,
                  mode,
                  value,
                  effectiveFrom: input.effectiveFrom,
                  agreedNote: note,
                  version: 1,
                  status: 'ACTIVE',
                  versions: [
                    {
                      version: 1,
                      mode,
                      value,
                      effectiveFrom: input.effectiveFrom,
                      agreedNote: note,
                      createdAt: now,
                      createdBy: who.id,
                    },
                  ],
                  activeKey: activeKeyOf(input.scope, target.id),
                  createdBy: who.id,
                  deletedAt: null,
                },
              ],
              { session },
            );
            if (!rule) throw new Error('Commission rule was not created');
            const stored = rule.toObject() as StoredCommissionRule;
            await this.writeHistory(session, who, stored, 'Created', null, this.snapshot(stored));
            return stored;
          },
          describe: (rule) => this.describe(rule),
        });
        return ruleViewOf(created);
      } catch (error) {
        if (!isDuplicateKeyError(error)) throw error;
        const holder = await this.rules
          .findOne({ activeKey: activeKeyOf(input.scope, target.id) })
          .lean<StoredCommissionRule>()
          .exec();
        if (holder) throw this.alreadyActive(holder);
        // the number was taken by someone else at the same moment: try the next one
      }
    }
    throw new ApiException(
      'ALREADY_REGISTERED',
      'Another rule was saved at the same time. Try again.',
    );
  }

  /** A rule changed: a new version with its own start date; past bookings keep their old commission. */
  async newVersion(
    actor: AuthenticatedUserActor,
    shortId: string,
    input: VersionInput,
    client: ClientRequestInfo,
  ): Promise<CommissionRuleView> {
    const { mode, value } = checkCommission(input.mode, input.value);
    this.assertDay(input.effectiveFrom);
    const note = this.cleanNote(input.agreedNote);
    const before = await this.live(shortId);
    const who = await this.whoIs(actor);
    const updated = await this.changes.run({
      actor,
      client,
      action: 'commission.rule.versioned',
      entityType: 'commission-rule',
      before: this.describe(before),
      apply: async (session) => {
        const now = new Date();
        const version = before.version + 1;
        const saved = await this.rules
          .findOneAndUpdate(
            { _id: before._id, version: before.version, deletedAt: null },
            {
              $set: { mode, value, effectiveFrom: input.effectiveFrom, agreedNote: note, version },
              $push: {
                versions: {
                  version,
                  mode,
                  value,
                  effectiveFrom: input.effectiveFrom,
                  agreedNote: note,
                  createdAt: now,
                  createdBy: who.id,
                },
              },
            },
            { returnDocument: 'after', session },
          )
          .lean<StoredCommissionRule>()
          .exec();
        if (!saved) {
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'This rule was changed by someone else. Reload it and try again.',
          );
        }
        await this.writeHistory(
          session,
          who,
          saved,
          'Edited',
          this.snapshot(before),
          this.snapshot(saved),
        );
        return saved;
      },
      describe: (rule) => this.describe(rule),
    });
    return ruleViewOf(updated);
  }

  async setActive(
    actor: AuthenticatedUserActor,
    shortId: string,
    active: boolean,
    client: ClientRequestInfo,
  ): Promise<CommissionRuleView> {
    const before = await this.live(shortId);
    if ((before.status === 'ACTIVE') === active) return ruleViewOf(before);
    const who = await this.whoIs(actor);
    try {
      const updated = await this.changes.run({
        actor,
        client,
        action: active ? 'commission.rule.activated' : 'commission.rule.deactivated',
        entityType: 'commission-rule',
        before: this.describe(before),
        apply: async (session) => {
          const saved = await this.rules
            .findOneAndUpdate(
              { _id: before._id, deletedAt: null },
              active
                ? {
                    $set: {
                      status: 'ACTIVE',
                      activeKey: activeKeyOf(before.scope, before.targetId),
                    },
                  }
                : { $set: { status: 'INACTIVE' }, $unset: { activeKey: '' } },
              { returnDocument: 'after', session },
            )
            .lean<StoredCommissionRule>()
            .exec();
          if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'This rule no longer exists');
          await this.writeHistory(
            session,
            who,
            saved,
            active ? 'Activated' : 'Deactivated',
            null,
            null,
          );
          return saved;
        },
        describe: (rule) => this.describe(rule),
      });
      return ruleViewOf(updated);
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      const holder = await this.rules
        .findOne({ activeKey: activeKeyOf(before.scope, before.targetId) })
        .lean<StoredCommissionRule>()
        .exec();
      throw this.alreadyActive(holder ?? before);
    }
  }

  async remove(
    actor: AuthenticatedUserActor,
    shortId: string,
    client: ClientRequestInfo,
  ): Promise<CommissionRuleView> {
    const before = await this.live(shortId);
    const who = await this.whoIs(actor);
    const deleted = await this.changes.run({
      actor,
      client,
      action: 'commission.rule.deleted',
      entityType: 'commission-rule',
      before: this.describe(before),
      apply: async (session) => {
        const saved = await this.rules
          .findOneAndUpdate(
            { _id: before._id, deletedAt: null },
            { $set: { deletedAt: new Date() }, $unset: { activeKey: '' } },
            { returnDocument: 'after', session },
          )
          .lean<StoredCommissionRule>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'This rule no longer exists');
        await this.writeHistory(session, who, saved, 'Deleted', null, null);
        return saved;
      },
      describe: (rule) => ({ ...this.describe(rule), deleted: true }),
    });
    return ruleViewOf(deleted);
  }

  /**
   * Undo of a delete. If another active rule took the place meanwhile, the rule comes back switched
   * off (`restoredInactive`), never replacing the new one.
   */
  async restore(
    actor: AuthenticatedUserActor,
    shortId: string,
    client: ClientRequestInfo,
  ): Promise<CommissionRuleView & { restoredInactive: boolean }> {
    const found = await this.rules
      .findOne({ shortId, deletedAt: { $ne: null } })
      .lean<StoredCommissionRule>()
      .exec();
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This rule is not deleted');
    const who = await this.whoIs(actor);
    const taken =
      found.status === 'ACTIVE'
        ? await this.rules.exists({ activeKey: activeKeyOf(found.scope, found.targetId) }).exec()
        : null;
    const restoredInactive = Boolean(taken);
    const restored = await this.changes.run({
      actor,
      client,
      action: 'commission.rule.restored',
      entityType: 'commission-rule',
      before: { ...this.describe(found), deleted: true },
      apply: async (session) => {
        const keepsActive = found.status === 'ACTIVE' && !restoredInactive;
        const saved = await this.rules
          .findOneAndUpdate(
            { _id: found._id, deletedAt: { $ne: null } },
            {
              $set: {
                deletedAt: null,
                status: keepsActive ? 'ACTIVE' : 'INACTIVE',
                ...(keepsActive ? { activeKey: activeKeyOf(found.scope, found.targetId) } : {}),
              },
            },
            { returnDocument: 'after', session },
          )
          .lean<StoredCommissionRule>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'This rule is not deleted');
        await this.writeHistory(session, who, saved, 'Restored', null, null);
        return saved;
      },
      describe: (rule) => this.describe(rule),
    });
    return { ...ruleViewOf(restored), restoredInactive };
  }

  async setDefault(
    actor: AuthenticatedUserActor,
    input: { mode: CommissionMode; value: number },
    client: ClientRequestInfo,
  ): Promise<CommissionDefaultView> {
    const { mode, value } = checkCommission(input.mode, input.value);
    const who = await this.whoIs(actor);
    const existing = await this.defaults.findOne().lean<StoredCommissionDefault>().exec();
    await this.changes.run({
      actor,
      client,
      action: 'commission.default.changed',
      entityType: 'commission-default',
      before: existing ? { mode: existing.mode, value: existing.value } : {},
      apply: async (session) => {
        const saved = await this.defaults
          .findOneAndUpdate(
            {},
            { $set: { mode, value, updatedBy: who.id } },
            { returnDocument: 'after', upsert: true, session },
          )
          .lean<StoredCommissionDefault>()
          .exec();
        if (!saved) throw new Error('Default commission was not saved');
        await this.history.create(
          [
            {
              ruleId: 'Default',
              version: null,
              action: 'Changed',
              who: who.id,
              whoName: who.name,
              at: new Date(),
              before: existing ? { mode: existing.mode, value: existing.value } : null,
              after: { mode, value },
            },
          ],
          { session },
        );
        return saved;
      },
      describe: (saved) => ({ name: 'Default commission', mode: saved.mode, value: saved.value }),
    });
    return this.getDefault();
  }

  // ----- helpers -----

  private filterOf(query: RuleListQuery): Record<string, unknown> {
    const filter: Record<string, unknown> = { deletedAt: null };
    if (query.scope) filter.scope = query.scope;
    if (query.status) filter.status = query.status;
    const text = query.search?.trim();
    if (text) {
      const pattern = { $regex: escapeRegExp(text), $options: 'i' };
      filter.$or = [{ shortId: pattern }, { targetName: pattern }, { agreedNote: pattern }];
    }
    return filter;
  }

  private async live(shortId: string): Promise<StoredCommissionRule> {
    const rule = await this.rules
      .findOne({ shortId, deletedAt: null })
      .lean<StoredCommissionRule>()
      .exec();
    if (!rule) throw new ApiException('RESOURCE_NOT_FOUND', 'This rule no longer exists');
    return rule;
  }

  private assertDay(day: string): void {
    if (!isValidDay(day)) throw fieldError('effectiveFrom', 'Pick a date');
    // A new version cannot rewrite today's or an earlier price
    if (day < todayIst()) throw fieldError('effectiveFrom', 'The date cannot be in the past');
  }

  private cleanNote(note: string | undefined): string {
    const text = (note ?? '').trim();
    if (text.length > MAX_NOTE_LENGTH) {
      throw fieldError('agreedNote', `Note can be up to ${MAX_NOTE_LENGTH} characters`);
    }
    return text;
  }

  private async target(
    scope: CommissionScope,
    targetId: string,
  ): Promise<{ id: Types.ObjectId; name: string }> {
    if (!Types.ObjectId.isValid(targetId)) throw fieldError('targetId', 'Choose which one');
    const record = await this.connection
      .model<Record<string, unknown>>(TARGET_MODELS[scope])
      .findById(targetId)
      .lean<(Record<string, unknown> & { _id: Types.ObjectId }) | null>()
      .exec();
    if (!record) throw fieldError('targetId', 'Choose which one');
    return { id: record._id, name: nameOf(scope, record) };
  }

  private async whoIs(
    actor: AuthenticatedUserActor,
  ): Promise<{ id: Types.ObjectId; name: string }> {
    const id = new Types.ObjectId(actor.userId);
    const [found] = await this.users.findNames([id]);
    return { id, name: found?.name?.trim() || 'Staff' };
  }

  private alreadyActive(holder: StoredCommissionRule): ApiException {
    const subject = { OPERATOR: 'operator', ROUTE: 'route', BUS_TYPE: 'bus type' }[holder.scope];
    return new ApiException(
      'ALREADY_REGISTERED',
      `${holder.shortId} is already the active rule for this ${subject}. Edit it, or deactivate it first.`,
    );
  }

  private async writeHistory(
    session: ClientSession,
    who: { id: Types.ObjectId; name: string },
    rule: StoredCommissionRule,
    action: HistoryAction,
    before: Described | null,
    after: Described | null,
  ): Promise<void> {
    await this.history.create(
      [
        {
          ruleId: rule.shortId,
          version: rule.version,
          action,
          who: who.id,
          whoName: who.name,
          at: new Date(),
          before,
          after,
        },
      ],
      { session },
    );
  }

  private snapshot(rule: StoredCommissionRule): Described {
    return {
      mode: rule.mode,
      value: rule.value,
      effectiveFrom: rule.effectiveFrom,
      agreedNote: rule.agreedNote,
      version: rule.version,
      status: rule.status,
    };
  }

  /** What the audit trail keeps: the rule's name (for the page) and its terms. Nothing secret. */
  private describe(rule: StoredCommissionRule): Described {
    return {
      name: `${rule.shortId} ${rule.targetName}`,
      scope: rule.scope,
      ...this.snapshot(rule),
    };
  }
}

function nameOf(scope: CommissionScope, record: Record<string, unknown>): string {
  const value = scope === 'OPERATOR' ? (record.displayName ?? record.companyName) : record.name;
  return typeof value === 'string' && value ? value : 'Unnamed';
}

/** Reads the Payout and fees settings the Payout feature saves (`gstPct`, `convenienceFee` in paise). */
export function payoutFeesFrom(connection: Connection): PayoutFeesProvider {
  return async () => {
    const settings = await connection.collection(PAYOUT_SETTINGS_COLLECTION).findOne({});
    const gstPct: unknown = settings?.['gstPct'];
    const fee: unknown = settings?.['convenienceFee'];
    return typeof gstPct === 'number' && typeof fee === 'number'
      ? { gstPct, convenienceFeePaise: fee }
      : undefined;
  };
}
