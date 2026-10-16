import { Injectable } from '@nestjs/common';
import { isValidObjectId, type QueryFilter, Types } from 'mongoose';
import { dayRange, escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { isAuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { type StoredDocument } from '../../database/scoped-repository.base';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { UsersService } from '../users/services/users.service';
import { AuditLogRepository } from './repositories/audit-log.repository';
import { AUDIT_ACTIONS, type AuditAction, type AuditLog } from './schemas/audit-log.schema';
import { type AuditLogView } from './services/audit-log.service';

/*
 * The audit log page of the admin app and the client portal (demo page "audit"): the same trail
 * the rest of the platform writes, read through the caller's data scope, with the words a person
 * needs on the screen (who, what, which record) and the filters of the demo.
 */

/** What each action says on screen. Typed over every action: a new action cannot be forgotten. */
export const AUDIT_ACTION_LABELS: Readonly<Record<AuditAction, string>> = {
  'user.roles.changed': 'Changed roles of a person',
  'user.permission-override.set': 'Changed a personal permission',
  'user.permission-override.removed': 'Removed a personal permission',
  'user.data-scope.changed': 'Changed what data a person can see',
  'role.access.changed': 'Changed role access',
  'role.created': 'Created a role',
  'role.renamed': 'Renamed a role',
  'role.deleted': 'Deleted a role',
  'message.resent': 'Sent a message again',
  'settings.integration.changed': 'Changed an integration',
  'assistant.action.confirmed': 'Confirmed an assistant action',
  'assistant.action.declined': 'Declined an assistant action',
  'feature-flag.changed': 'Changed a feature switch',
  'maintenance.changed': 'Changed maintenance mode',
  'settings.whatsapp.changed': 'Changed WhatsApp settings',
  'settings.email.changed': 'Changed email settings',
  'onboarding.invited': 'Invited an operator',
  'onboarding.invitation-resent': 'Sent an invitation again',
  'onboarding.invitation-revoked': 'Cancelled an invitation',
  'onboarding.invitation-updated': 'Changed an invitation',
  'onboarding.submitted': 'Sent documents for review',
  'onboarding.approved': 'Approved documents',
  'onboarding.rejected': 'Rejected documents',
  'user.super-admin.bootstrapped': 'Created the first Super Admin',
  'catalogue.created': 'Added a record',
  'catalogue.updated': 'Changed a record',
  'catalogue.status-changed': 'Switched a record on or off',
  'catalogue.deleted': 'Deleted a record',
  'catalogue.restored': 'Brought a record back',
  'catalogue.exported': 'Downloaded a list',
  'catalogue.imported': 'Imported a list',
  'trip.published': 'Published a trip',
  'trip.cancelled': 'Cancelled a trip',
  'banner.created': 'Added a banner',
  'banner.updated': 'Changed a banner',
  'banner.status-changed': 'Switched a banner on or off',
  'banner.image-changed': 'Changed a banner picture',
  'banner.deleted': 'Deleted a banner',
  'place-request.created': 'Asked for a new place',
  'place-request.approved': 'Approved a place request',
  'place-request.rejected': 'Rejected a place request',
  'operator.suspended': 'Suspended an operator',
  'operator.reactivated': 'Reactivated an operator',
  'operator.messaged': 'Messaged the operator owner',
  'operator.payout-mode-changed': 'Changed the payout mode',
  'operator.bank-verified': 'Verified bank details',
  'operator.bank-failed': 'Marked bank details as failed',
  'operator.profile-updated': 'Changed the company profile',
  'operator.bank-changed': 'Changed bank details',
  'commission.rule.created': 'Created a commission rule',
  'commission.rule.versioned': 'Saved a new version of a commission rule',
  'commission.rule.activated': 'Activated a commission rule',
  'commission.rule.deactivated': 'Deactivated a commission rule',
  'commission.rule.deleted': 'Deleted a commission rule',
  'commission.rule.restored': 'Restored a deleted commission rule',
  'commission.default.changed': 'Changed the default commission',
};

/**
 * Actions that change who may do what, money or safety settings, or that remove things. The demo
 * marks these "Sensitive" and shows what changed (before and after) when the entry is opened.
 */
export const SENSITIVE_ACTIONS: ReadonlySet<AuditAction> = new Set<AuditAction>([
  'operator.suspended',
  'operator.payout-mode-changed',
  'operator.bank-verified',
  'operator.bank-failed',
  'operator.bank-changed',
  'commission.rule.created',
  'commission.rule.versioned',
  'commission.rule.activated',
  'commission.rule.deactivated',
  'commission.rule.deleted',
  'commission.rule.restored',
  'commission.default.changed',
  'user.roles.changed',
  'user.permission-override.set',
  'user.permission-override.removed',
  'user.data-scope.changed',
  'role.access.changed',
  'role.created',
  'role.renamed',
  'role.deleted',
  'settings.integration.changed',
  'settings.whatsapp.changed',
  'settings.email.changed',
  'feature-flag.changed',
  'maintenance.changed',
  'assistant.action.confirmed',
  'onboarding.approved',
  'onboarding.rejected',
  'user.super-admin.bootstrapped',
  'catalogue.deleted',
  'banner.deleted',
  'trip.cancelled',
]);

/** What an operator's people see instead of the name of a member of the Abra team. */
export const ABRA_TEAM_LABEL = 'Abra team';

export const AUDIT_SORTS = ['newest', 'oldest', 'action'] as const;
export type AuditSort = (typeof AUDIT_SORTS)[number];

export interface AuditListQuery {
  search?: string | undefined;
  /** `actor.userId` of the Person filter. */
  personId?: string | undefined;
  /** `sensitive` is the demo's "Sensitive only". */
  type?: 'sensitive' | undefined;
  action?: AuditAction | undefined;
  entityType?: string | undefined;
  entityId?: string | undefined;
  operatorId?: string | undefined;
  from?: string | undefined;
  to?: string | undefined;
  sort: AuditSort;
  page: number;
  pageSize: number;
}

/** A row of the page: the stored entry plus the words for the screen. */
export interface AuditEntryView extends AuditLogView {
  actionLabel: string;
  sensitive: boolean;
  /** Name of the person; "Abra team" when an operator looks at a platform member's entry. */
  actorName: string;
  /** Role names of the person at the time, as one text. */
  actorRoleLabel: string;
  /** The record the change was about, by its name where the entry has one. */
  targetLabel: string;
}

export interface AuditFilterChoices {
  people: Array<{ id: string; name: string }>;
  actions: Array<{ key: AuditAction; label: string; sensitive: boolean }>;
}

/** `PLACE_REQUEST` or `place-request` as "Place request". */
function words(value: string): string {
  const text = value
    .replace(/[_.\-\s]+/g, ' ')
    .trim()
    .toLowerCase();
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** The name a change record carries for the thing it was about, if any. */
function nameIn(values: Record<string, unknown>): string | undefined {
  for (const field of ['name', 'title', 'companyName', 'key', 'label']) {
    const value = values[field];
    if (typeof value === 'string' && value.trim() !== '') return value.trim();
  }
  return undefined;
}

export function targetLabelOf(entry: Pick<AuditLog, 'entityType' | 'before' | 'after'>): string {
  const name = nameIn(entry.after) ?? nameIn(entry.before);
  const kind = words(entry.entityType);
  return name ? `${kind}: ${name}` : kind;
}

@Injectable()
export class AuditLogAdminService {
  constructor(
    private readonly repository: AuditLogRepository,
    private readonly users: UsersService,
    private readonly roles: RoleRepository,
  ) {}

  async list(query: AuditListQuery): Promise<PaginatedResult<AuditEntryView>> {
    const filter = await this.filterOf(query);
    const [entries, total] = await Promise.all([
      this.repository.searchSorted(filter, {
        sort: this.sortOf(query.sort),
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.repository.count(filter),
    ]);
    return new PaginatedResult(await this.present(entries), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<AuditEntryView> {
    // Out of scope or unknown: the same answer, so ids of other operators cannot be probed
    const entry = await this.repository.getById(id);
    return (await this.present([entry]))[0] as AuditEntryView;
  }

  /** The Person and Action choices of the filters: only what the caller can see in the trail. */
  async filters(): Promise<AuditFilterChoices> {
    const platform = this.viewerIsPlatform();
    const [actorIds, actions] = await Promise.all([
      this.repository.distinctInScope<Types.ObjectId>('actor.userId'),
      this.repository.distinctInScope<AuditAction>('action'),
    ]);
    const found = await this.users.findNames(actorIds);
    const people = found
      // An operator is not told who is on the Abra team
      .filter((user) => platform || user.userType !== 'STAFF')
      .map((user) => ({ id: user._id.toHexString(), name: user.name?.trim() || 'Unnamed' }))
      .sort((a, b) => a.name.localeCompare(b.name));
    return {
      people,
      actions: actions
        .filter((action) => action in AUDIT_ACTION_LABELS)
        .map((key) => ({
          key,
          label: AUDIT_ACTION_LABELS[key],
          sensitive: SENSITIVE_ACTIONS.has(key),
        }))
        .sort((a, b) => a.label.localeCompare(b.label)),
    };
  }

  /** Platform staff see every name; an operator's people see "Abra team" for the platform's. */
  private viewerIsPlatform(): boolean {
    const actor = RequestContextService.actor();
    return !isAuthenticatedUserActor(actor) || actor.userType === 'STAFF';
  }

  private sortOf(sort: AuditSort): Record<string, 1 | -1> {
    if (sort === 'oldest') return { at: 1, _id: 1 };
    if (sort === 'action') return { action: 1, at: -1, _id: -1 };
    return { at: -1, _id: -1 };
  }

  /** The database filter of a query. Filters only narrow: the data scope is added by the repository. */
  private async filterOf(query: AuditListQuery): Promise<QueryFilter<AuditLog>> {
    const all: Array<QueryFilter<AuditLog>> = [];
    const objectId = (field: string, value: string | undefined) => {
      if (value === undefined) return;
      // An id that cannot exist matches nothing instead of being ignored
      all.push({
        [field]: isValidObjectId(value) ? new Types.ObjectId(value) : { $in: [] },
      });
    };
    objectId('actor.userId', query.personId);
    objectId('entityId', query.entityId);
    objectId('operatorId', query.operatorId);
    if (query.entityType) all.push({ entityType: query.entityType });

    if (query.action && query.type === 'sensitive') {
      // Both chosen: the action must also be a sensitive one
      all.push({ action: SENSITIVE_ACTIONS.has(query.action) ? query.action : { $in: [] } });
    } else if (query.action) {
      all.push({ action: query.action });
    } else if (query.type === 'sensitive') {
      all.push({ action: { $in: [...SENSITIVE_ACTIONS] } });
    }

    const range = dayRange(query);
    if (range) all.push({ at: range });

    const term = query.search?.trim();
    if (term) all.push(await this.searchFilter(term));
    return all.length === 0 ? {} : { $and: all };
  }

  /** Search covers what a row shows: the person, the action words, the record's name, the reason and the IP. */
  private async searchFilter(term: string): Promise<QueryFilter<AuditLog>> {
    const pattern = new RegExp(escapeRegExp(term), 'i');
    const lower = term.toLowerCase();
    const people = await this.users.findIdsByName(pattern);
    const actions = AUDIT_ACTIONS.filter(
      (action) =>
        AUDIT_ACTION_LABELS[action].toLowerCase().includes(lower) || action.includes(lower),
    );
    const or: Array<QueryFilter<AuditLog>> = [
      { entityType: pattern },
      { reason: pattern },
      { ip: pattern },
      { 'after.name': pattern },
      { 'before.name': pattern },
      { 'after.title': pattern },
      { 'before.title': pattern },
    ];
    if (people.length > 0) or.push({ 'actor.userId': { $in: people } });
    if (actions.length > 0) or.push({ action: { $in: actions } });
    return { $or: or };
  }

  /** Adds names and labels to stored entries, with one lookup of people and one of roles. */
  private async present(entries: readonly StoredDocument<AuditLog>[]): Promise<AuditEntryView[]> {
    const people = new Map(
      (await this.users.findNames(entries.map((entry) => entry.actor.userId))).map((user) => [
        user._id.toHexString(),
        user,
      ]),
    );
    const roleKeys = [...new Set(entries.flatMap((entry) => entry.actor.roleKeys))];
    const roleNames = new Map(
      (await this.roles.findByKeys(roleKeys)).map((role) => [role.key, role.name]),
    );
    const viewerIsPlatform = this.viewerIsPlatform();

    return entries.map((entry) => {
      const person = people.get(entry.actor.userId.toHexString());
      const hidden = !viewerIsPlatform && entry.actor.userType === 'STAFF';
      return {
        id: entry._id.toHexString(),
        at: entry.at.toISOString(),
        action: entry.action,
        actionLabel: AUDIT_ACTION_LABELS[entry.action] ?? words(entry.action),
        sensitive: SENSITIVE_ACTIONS.has(entry.action),
        actor: {
          userId: hidden ? '' : entry.actor.userId.toHexString(),
          userType: entry.actor.userType,
          roleKeys: hidden ? [] : entry.actor.roleKeys,
        },
        actorName: hidden ? ABRA_TEAM_LABEL : person?.name?.trim() || 'Unnamed',
        actorRoleLabel: hidden
          ? ''
          : entry.actor.roleKeys.map((key) => roleNames.get(key) ?? words(key)).join(', '),
        entityType: entry.entityType,
        entityId: entry.entityId.toHexString(),
        targetLabel: targetLabelOf(entry),
        operatorId: entry.operatorId?.toHexString() ?? null,
        partnerId: entry.partnerId?.toHexString() ?? null,
        before: entry.before,
        after: entry.after,
        reason: entry.reason ?? null,
        requestId: entry.requestId ?? null,
        ip: entry.ip ?? null,
        userAgent: entry.userAgent ?? null,
      };
    });
  }
}
