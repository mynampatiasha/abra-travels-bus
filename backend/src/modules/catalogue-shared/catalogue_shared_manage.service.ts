import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { rejectDuplicates } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { WITH_DELETED } from '../../database/soft-delete.plugin';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';

/*
 * The one soft-delete mechanism of every catalogue record (Phase 1, step 1):
 *   - `softDeletePlugin` (database/soft-delete.plugin.ts) adds `deletedAt` / `deletedBy` to a
 *     schema and hides deleted records from every query, so no repository has to remember a filter;
 *   - `CatalogueDeletionService` deletes and restores a record, refuses a delete while other
 *     records still use it (with a sentence that names them), and writes the audit entry in the
 *     same transaction as the change.
 *
 * This file imports no schema (models are looked up by name). The plugin itself lives in
 * `database/soft-delete.plugin.ts`, which has no imports of the application, because the schemas
 * (which the permission catalogue imports) use it and an import cycle would break at start-up.
 */

/** What still points at a record. */
export interface UsageRule {
  /** Singular and plural noun for the sentence: "3 routes". */
  readonly one: string;
  readonly many: string;
  readonly model: string;
  readonly filter: (id: Types.ObjectId) => Record<string, unknown>;
}

export interface CatalogueKindConfig {
  /** Name of the record in sentences: "city", "bus type". */
  readonly label: string;
  /** `entityType` of the audit entries. */
  readonly entityType: string;
  readonly model: string;
  readonly usage: readonly UsageRule[];
  /** A rule that is not a count of other records. Returns the sentence that refuses, or null. */
  readonly refusal?: (record: Record<string, unknown>) => string | null;
  /** The operator a record belongs to, so operator administrators see its audit entries. */
  readonly operatorIdOf?: (record: Record<string, unknown>) => Types.ObjectId | undefined;
}

const rule = (
  one: string,
  many: string,
  model: string,
  filter: (id: Types.ObjectId) => Record<string, unknown>,
): UsageRule => ({ one, many, model, filter });

/** Every kind of record the shared mechanism can delete (the Phase 1 catalogue). */
export const CATALOGUE_KINDS = {
  city: {
    label: 'city',
    entityType: 'city',
    model: 'City',
    usage: [
      rule('place', 'places', 'Location', (id) => ({ cityId: id })),
      rule('route', 'routes', 'Route', (id) => ({
        $or: [{ originCityId: id }, { destinationCityId: id }, { 'stops.cityId': id }],
      })),
      rule('trip', 'trips', 'Trip', (id) => ({
        $or: [{ originCityId: id }, { destinationCityId: id }, { stopCityIds: id }],
      })),
    ],
  },
  location: {
    label: 'place',
    entityType: 'location',
    model: 'Location',
    usage: [
      rule('trip', 'trips', 'Trip', (id) => ({
        $or: [{ 'boardingPoints.locationId': id }, { 'droppingPoints.locationId': id }],
      })),
    ],
    operatorIdOf: (record) => record.operatorId as Types.ObjectId | undefined,
  },
  busType: {
    label: 'bus type',
    entityType: 'bus-type',
    model: 'BusType',
    usage: [rule('bus', 'buses', 'Bus', (id) => ({ busTypeId: id }))],
  },
  documentType: {
    label: 'document type',
    entityType: 'document-type',
    model: 'DocumentType',
    usage: [
      rule('KYC file', 'KYC files', 'OnboardingSubmission', (id) => ({
        'documents.documentTypeId': id,
      })),
    ],
  },
  operator: {
    label: 'operator',
    entityType: 'operator',
    model: 'Operator',
    usage: [
      rule('bus', 'buses', 'Bus', (id) => ({ operatorId: id })),
      rule('route', 'routes', 'Route', (id) => ({ operatorId: id })),
      rule('trip', 'trips', 'Trip', (id) => ({ operatorId: id })),
      rule('user account', 'user accounts', 'User', (id) => ({ operatorId: id })),
    ],
    operatorIdOf: (record) => record._id as Types.ObjectId,
  },
  banner: {
    label: 'banner',
    entityType: 'banner',
    model: 'Banner',
    usage: [],
  },
  invitation: {
    label: 'invitation',
    entityType: 'invitation',
    model: 'OnboardingInvitation',
    usage: [],
    refusal: (record) =>
      record.status === 'PENDING'
        ? 'This invitation is still pending. Revoke it first, then delete it.'
        : record.status === 'ACCEPTED'
          ? 'This invitation was accepted by the owner, so it is part of the operator’s history and cannot be deleted.'
          : null,
    operatorIdOf: (record) => record.operatorId as Types.ObjectId | undefined,
  },
} as const satisfies Record<string, CatalogueKindConfig>;

export type CatalogueKind = keyof typeof CATALOGUE_KINDS;

export interface DeletionResult {
  id: string;
  deleted: boolean;
  deletedAt: string | null;
}

const SUMMARY_FIELDS = ['name', 'companyName', 'title', 'key', 'email', 'status'] as const;

/** The few fields of a record the audit trail keeps (never more than a person would look for). */
export function summaryOf(record: Record<string, unknown>): Record<string, unknown> {
  const summary: Record<string, unknown> = {};
  for (const field of SUMMARY_FIELDS) {
    if (record[field] !== undefined) summary[field] = record[field];
  }
  return summary;
}

/** "3 routes and 5 trips" from counts, skipping what is zero; null when nothing uses it. */
export function usageSentence(
  label: string,
  counts: readonly { rule: UsageRule; count: number }[],
): string | null {
  const used = counts.filter((entry) => entry.count > 0);
  if (used.length === 0) return null;
  const parts = used.map(
    ({ rule: usage, count }) => `${count} ${count === 1 ? usage.one : usage.many}`,
  );
  const list =
    parts.length === 1
      ? parts[0]!
      : `${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1]!}`;
  return `This ${label} is used by ${list}, so it cannot be deleted. Disable it instead.`;
}

@Injectable()
export class CatalogueDeletionService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
  ) {}

  private modelOf(kind: CatalogueKind): Model<Record<string, unknown>> {
    return this.connection.model<Record<string, unknown>>(CATALOGUE_KINDS[kind].model);
  }

  private async load(
    kind: CatalogueKind,
    id: string,
  ): Promise<Record<string, unknown> & { _id: Types.ObjectId }> {
    const found = await this.modelOf(kind)
      .findOne({ _id: new Types.ObjectId(id) })
      .setOptions({ [WITH_DELETED]: true })
      .lean<Record<string, unknown> & { _id: Types.ObjectId }>()
      .exec();
    if (!found) {
      throw new ApiException(
        'RESOURCE_NOT_FOUND',
        `This ${CATALOGUE_KINDS[kind].label} was not found.`,
      );
    }
    return found;
  }

  /** The sentence that says why a record cannot be deleted now, or null when it can. */
  async refusalFor(
    kind: CatalogueKind,
    record: Record<string, unknown> & { _id: Types.ObjectId },
  ): Promise<string | null> {
    const config: CatalogueKindConfig = CATALOGUE_KINDS[kind];
    const own = config.refusal?.(record);
    if (own) return own;
    const counts = await Promise.all(
      config.usage.map(async (usage) => ({
        rule: usage,
        count: await this.connection
          .model(usage.model)
          .countDocuments(usage.filter(record._id))
          .exec(),
      })),
    );
    return usageSentence(config.label, counts);
  }

  async delete(
    kind: CatalogueKind,
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<DeletionResult> {
    const config: CatalogueKindConfig = CATALOGUE_KINDS[kind];
    const scopeOf = config.operatorIdOf;
    const record = await this.load(kind, id);
    if (record.deletedAt) return this.resultOf(record); // already deleted: same answer, no new entry
    const refusal = await this.refusalFor(kind, record);
    if (refusal) throw new ApiException('RESOURCE_IN_USE', refusal);

    const deleted = await this.changes.run({
      actor,
      client,
      action: 'catalogue.deleted',
      entityType: config.entityType,
      before: summaryOf(record),
      ...(scopeOf ? { operatorIdOf: () => scopeOf(record) } : {}),
      apply: async (session) => {
        const updated = await this.modelOf(kind)
          .findOneAndUpdate(
            { _id: record._id },
            { $set: { deletedAt: new Date(), deletedBy: new Types.ObjectId(actor.userId) } },
            { returnDocument: 'after', session },
          )
          .lean<Record<string, unknown> & { _id: Types.ObjectId }>()
          .exec();
        if (!updated)
          throw new ApiException('RESOURCE_NOT_FOUND', `This ${config.label} was not found.`);
        return updated;
      },
      describe: (updated) => ({ ...summaryOf(updated), deleted: true }),
    });
    return this.resultOf(deleted);
  }

  /** Undo of a delete. A record that is not deleted is returned as it is. */
  async restore(
    kind: CatalogueKind,
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<DeletionResult> {
    const config: CatalogueKindConfig = CATALOGUE_KINDS[kind];
    const scopeOf = config.operatorIdOf;
    const record = await this.load(kind, id);
    if (!record.deletedAt) return this.resultOf(record);

    const restored = await rejectDuplicates(
      `Another ${config.label} with the same name or key was added after this one was deleted, so it cannot be restored.`,
      () =>
        this.changes.run({
          actor,
          client,
          action: 'catalogue.restored',
          entityType: config.entityType,
          before: { ...summaryOf(record), deleted: true },
          ...(scopeOf ? { operatorIdOf: () => scopeOf(record) } : {}),
          apply: async (session) => {
            const updated = await this.modelOf(kind)
              .findOneAndUpdate(
                { _id: record._id },
                { $set: { deletedAt: null, deletedBy: null } },
                { returnDocument: 'after', session },
              )
              .setOptions({ [WITH_DELETED]: true })
              .lean<Record<string, unknown> & { _id: Types.ObjectId }>()
              .exec();
            if (!updated) {
              throw new ApiException('RESOURCE_NOT_FOUND', `This ${config.label} was not found.`);
            }
            return updated;
          },
          describe: (updated) => ({ ...summaryOf(updated), deleted: false }),
        }),
    );
    return this.resultOf(restored);
  }

  private resultOf(record: Record<string, unknown> & { _id: Types.ObjectId }): DeletionResult {
    const at = record.deletedAt instanceof Date ? record.deletedAt : null;
    return {
      id: record._id.toHexString(),
      deleted: at !== null,
      deletedAt: at?.toISOString() ?? null,
    };
  }
}
