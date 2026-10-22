/**
 * Payout and fees: logic.
 * - PayoutCfgService: settings (one platform record) and refund slabs.
 * - Pure functions for booking/cancellation code to reuse: refundPercent, feeAndGst, roundPaise.
 *
 * Money rule: integers in paise, ONE rounding function (roundPaise).
 */
import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
// Type-only import on purpose: payout_cfg_admin_manage.ts imports this file, and a
// normal import back would be circular. Model names are plain strings for the same reason.
import type {
  CreateRefundSlabDto,
  PayoutSettings,
  RefundSlab,
  UpdatePayoutSettingsDto,
} from './payout_cfg_admin_manage';

// ---------------------------------------------------------------------------
// Pure money / refund functions (no database, easy to unit test)
// ---------------------------------------------------------------------------

/** The ONE rounding function for money. Half rounds up, result is an integer paise. */
export function roundPaise(value: number): number {
  return Math.round(value);
}

export interface SlabLike {
  hoursBefore: number;
  refundPct: number;
}

/**
 * Refund percent for a cancellation.
 * - no slabs at all            -> 100
 * - largest hoursBefore that is <= hours left -> that slab's refundPct
 * - none matches (too late)    -> 0
 */
export function refundPercent(hoursBeforeDeparture: number, slabs: SlabLike[]): number {
  if (!slabs || slabs.length === 0) return 100;
  const sorted = [...slabs].sort((a, b) => b.hoursBefore - a.hoursBefore);
  const hit = sorted.find((s) => s.hoursBefore <= hoursBeforeDeparture);
  return hit ? hit.refundPct : 0;
}

/**
 * Used ONLY when no settings have been saved yet. The accountant must confirm the
 * real rate; once settings are saved this is never used. Result says so (usedFallback).
 */
export const FALLBACK_GST_PCT = 18;
export const FALLBACK_CONVENIENCE_FEE_PAISE = 0;

export interface FeeSettingsLike {
  gstPct: number;
  convenienceFee: number; // paise
}

export interface FeeAndGstResult {
  fare: number; // paise, fare shown to the customer (operator fare + commission)
  gstPct: number;
  gst: number; // paise
  convenienceFee: number; // paise
  total: number; // paise
  usedFallback: boolean; // true = no saved settings, values are a marked fallback
}

/**
 * GST and convenience fee from the saved settings.
 * GST is charged on the fare shown to the customer (operator fare + commission).
 * GST on the convenience fee is NOT added: the accountant must confirm that.
 */
export function feeAndGst(
  fareShownToCustomer: number,
  settings: FeeSettingsLike | null | undefined,
): FeeAndGstResult {
  if (!Number.isInteger(fareShownToCustomer) || fareShownToCustomer < 0) {
    throw new ApiException('VALIDATION_FAILED', 'Fare must be a whole number of paise, 0 or more');
  }
  const usedFallback = !settings;
  const gstPct = settings ? settings.gstPct : FALLBACK_GST_PCT;
  const fee = settings ? settings.convenienceFee : FALLBACK_CONVENIENCE_FEE_PAISE;
  // gstPct may have decimals (for example 5.5): work in basis points to avoid float noise.
  const bps = Math.round(gstPct * 100);
  const gst = roundPaise((fareShownToCustomer * bps) / 10000);
  return {
    fare: fareShownToCustomer,
    gstPct,
    gst,
    convenienceFee: fee,
    total: fareShownToCustomer + gst + fee,
    usedFallback,
  };
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

const SETTINGS_KEY = 'platform';

type StoredSettings = PayoutSettings & { _id: Types.ObjectId };
type StoredSlab = RefundSlab & { _id: Types.ObjectId; createdAt?: Date; updatedAt?: Date };

/** A refund slab as the screen and the export read it. */
export interface RefundSlabView {
  id: string;
  hoursBefore: number;
  refundPct: number;
  deletedAt: string | null;
}

export function refundSlabViewOf(slab: StoredSlab): RefundSlabView {
  return {
    id: slab._id.toHexString(),
    hoursBefore: slab.hoursBefore,
    refundPct: slab.refundPct,
    deletedAt: slab.deletedAt ? slab.deletedAt.toISOString() : null,
  };
}

/** The settings as the screen reads them (no internal key or id). */
function settingsViewOf(settings: StoredSettings | null) {
  if (!settings) return null;
  return {
    defaultMode: settings.defaultMode,
    cycleDays: settings.cycleDays,
    minPayout: settings.minPayout,
    holdDays: settings.holdDays,
    razorpayRoute: settings.razorpayRoute,
    gstPct: settings.gstPct,
    convenienceFee: settings.convenienceFee,
    couponFunding: settings.couponFunding,
    updatedBy: settings.updatedBy ?? null,
    updatedAt: settings.updatedAt ? settings.updatedAt.toISOString() : null,
  };
}

@Injectable()
export class PayoutCfgService {
  constructor(
    @InjectModel('PayoutSettings')
    private readonly settingsModel: Model<PayoutSettings>,
    @InjectModel('RefundSlab')
    private readonly slabModel: Model<RefundSlab>,
    // Operators live in modules/operators; read by name, so this module needs no import cycle
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
  ) {}

  // ----- settings ----------------------------------------------------------

  private findSettings(session?: ClientSession) {
    return this.settingsModel
      .findOne({ key: SETTINGS_KEY })
      .session(session ?? null)
      .lean<StoredSettings>()
      .exec();
  }

  /** The one platform record, or null when nothing has been saved yet (nothing is invented). */
  async getSettings() {
    return settingsViewOf(await this.findSettings());
  }

  async updateSettings(
    dto: UpdatePayoutSettingsDto,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
  ) {
    const before = await this.findSettings();

    // Route cannot be switched off while operators are on Automatic.
    if (dto.razorpayRoute === false) {
      const affected = await this.connection
        .model('Operator')
        .countDocuments({ payoutMode: 'AUTO_SPLIT' })
        .exec();
      if (affected > 0) {
        throw new ApiException(
          'INVALID_STATE_TRANSITION',
          `Razorpay Route cannot be switched off: ${affected} operator${
            affected === 1 ? ' is' : 's are'
          } on Automatic payout. Change them to Manual first.`,
        );
      }
    }

    // Money and fee changes are sensitive (marked so on the audit page).
    const after = await this.changes.run<StoredSettings>({
      actor,
      client,
      action: 'payout.settings-changed',
      entityType: 'payout_settings',
      before: settingsViewOf(before) ?? {},
      apply: async (session) => {
        const saved = await this.settingsModel
          .findOneAndUpdate(
            { key: SETTINGS_KEY },
            { $set: { ...dto, updatedBy: actor.userId, updatedAt: new Date() } },
            { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true, session },
          )
          .lean<StoredSettings>()
          .exec();
        if (!saved) throw new Error('Payout settings were not saved');
        return saved;
      },
      describe: (record) => ({ ...settingsViewOf(record) }),
    });
    return settingsViewOf(after);
  }

  /** True when Automatic mode may be used (used by the operators code too). */
  async isRouteEnabled(): Promise<boolean> {
    const s = await this.findSettings();
    return !!s?.razorpayRoute;
  }

  // ----- refund slabs ------------------------------------------------------

  private async findSlabs(includeDeleted: boolean): Promise<StoredSlab[]> {
    const filter = includeDeleted ? {} : { deletedAt: null };
    return this.slabModel.find(filter).sort({ hoursBefore: -1 }).lean<StoredSlab[]>().exec();
  }

  async listSlabs(includeDeleted = false): Promise<RefundSlabView[]> {
    return (await this.findSlabs(includeDeleted)).map(refundSlabViewOf);
  }

  /** A page of slabs, for the shared export. */
  async listSlabPage(query: {
    includeDeleted?: boolean | undefined;
    page: number;
    pageSize: number;
  }): Promise<PaginatedResult<RefundSlabView>> {
    const all = await this.listSlabs(query.includeDeleted ?? false);
    const start = skipOf(query);
    return new PaginatedResult(
      all.slice(start, start + query.pageSize),
      query.page,
      query.pageSize,
      all.length,
    );
  }

  private async requireSlab(id: string): Promise<StoredSlab> {
    const slab = Types.ObjectId.isValid(id)
      ? await this.slabModel.findById(id).lean<StoredSlab>().exec()
      : null;
    if (!slab) throw new ApiException('RESOURCE_NOT_FOUND', 'Refund slab not found');
    return slab;
  }

  async getSlab(id: string): Promise<RefundSlabView> {
    return refundSlabViewOf(await this.requireSlab(id));
  }

  async createSlab(
    dto: CreateRefundSlabDto,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
  ): Promise<RefundSlabView> {
    const clash = await this.slabModel
      .exists({ hoursBefore: dto.hoursBefore, deletedAt: null })
      .exec();
    if (clash) {
      throw new ApiException('ALREADY_REGISTERED', 'A slab for these hours already exists');
    }
    const created = await this.changes.run<StoredSlab>({
      actor,
      client,
      action: 'payout.slab-added',
      entityType: 'refund_slab',
      before: {},
      apply: async (session) => {
        const [slab] = await this.slabModel.create(
          [{ hoursBefore: dto.hoursBefore, refundPct: dto.refundPct, deletedAt: null }],
          { session },
        );
        if (!slab) throw new Error('The refund slab was not created');
        return slab.toObject();
      },
      describe: (record) => ({ ...refundSlabViewOf(record) }),
    });
    return refundSlabViewOf(created);
  }

  async removeSlab(
    id: string,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
  ): Promise<RefundSlabView> {
    const before = await this.requireSlab(id);
    if (before.deletedAt) return refundSlabViewOf(before); // already removed, nothing to do
    const after = await this.changes.run<StoredSlab>({
      actor,
      client,
      action: 'payout.slab-removed',
      entityType: 'refund_slab',
      before: { ...refundSlabViewOf(before) },
      apply: async (session) => {
        const saved = await this.slabModel
          .findByIdAndUpdate(
            before._id,
            { $set: { deletedAt: new Date() } },
            { returnDocument: 'after', session },
          )
          .lean<StoredSlab>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Refund slab not found');
        return saved;
      },
      describe: (record) => ({ ...refundSlabViewOf(record) }),
    });
    return refundSlabViewOf(after);
  }

  async restoreSlab(
    id: string,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
  ): Promise<RefundSlabView> {
    const before = await this.requireSlab(id);
    if (!before.deletedAt) return refundSlabViewOf(before);
    const clash = await this.slabModel
      .exists({ hoursBefore: before.hoursBefore, deletedAt: null, _id: { $ne: before._id } })
      .exec();
    if (clash) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Cannot restore: another slab now uses these hours',
      );
    }
    const after = await this.changes.run<StoredSlab>({
      actor,
      client,
      action: 'payout.slab-restored',
      entityType: 'refund_slab',
      before: { ...refundSlabViewOf(before) },
      apply: async (session) => {
        const saved = await this.slabModel
          .findByIdAndUpdate(
            before._id,
            { $set: { deletedAt: null } },
            { returnDocument: 'after', session },
          )
          .lean<StoredSlab>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Refund slab not found');
        return saved;
      },
      describe: (record) => ({ ...refundSlabViewOf(record) }),
    });
    return refundSlabViewOf(after);
  }

  /** Server-side helpers for booking/cancellation code. */
  async refundPercentFor(hoursBeforeDeparture: number): Promise<number> {
    return refundPercent(hoursBeforeDeparture, await this.findSlabs(false));
  }

  async feeAndGstFor(fareShownToCustomer: number): Promise<FeeAndGstResult> {
    return feeAndGst(fareShownToCustomer, await this.findSettings());
  }
}
