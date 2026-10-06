import { Schema, type Types } from 'mongoose';
import { type UserType } from '../../../common/request-context/request-actor';

export const AUDIT_LOG_MODEL = 'AuditLog';

/** Actions recorded so far. Each module adds its own actions when it starts auditing. */
export const AUDIT_ACTIONS = [
  'user.roles.changed',
  'user.permission-override.set',
  'user.permission-override.removed',
  'user.data-scope.changed',
  'settings.whatsapp.changed',
  'user.super-admin.bootstrapped',
  'catalogue.created',
  'catalogue.updated',
  'catalogue.status-changed',
  'trip.published',
  'trip.cancelled',
] as const;
export type AuditAction = (typeof AUDIT_ACTIONS)[number];

export interface AuditLogActor {
  userId: Types.ObjectId;
  userType: UserType;
  roleKeys: string[];
}

/**
 * One audited change: who did what to which record, the state before and after, and why.
 * Append-only — the application never updates or deletes an entry. `before` / `after` hold
 * authorization facts (role keys, permission keys, scope), never credentials or tokens.
 */
export interface AuditLog {
  actor: AuditLogActor;
  action: AuditAction;
  entityType: string;
  entityId: Types.ObjectId;
  /** Operator the affected record belongs to; scopes who may read the entry. */
  operatorId?: Types.ObjectId;
  /** Partner the affected record belongs to; scopes who may read the entry. */
  partnerId?: Types.ObjectId;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  reason?: string;
  requestId?: string;
  ip?: string;
  userAgent?: string;
  at: Date;
}

/** `audit_logs` (database-architecture.md §10). */
export const auditLogSchema = new Schema<AuditLog>(
  {
    actor: {
      userId: { type: Schema.Types.ObjectId, required: true },
      userType: { type: String, required: true },
      roleKeys: { type: [String], default: [] },
    },
    action: { type: String, enum: AUDIT_ACTIONS, required: true },
    entityType: { type: String, required: true, maxlength: 64 },
    entityId: { type: Schema.Types.ObjectId, required: true },
    operatorId: { type: Schema.Types.ObjectId },
    partnerId: { type: Schema.Types.ObjectId },
    before: { type: Schema.Types.Mixed, required: true },
    after: { type: Schema.Types.Mixed, required: true },
    reason: { type: String, maxlength: 300 },
    requestId: { type: String, maxlength: 128 },
    ip: { type: String, maxlength: 64 },
    userAgent: { type: String, maxlength: 256 },
    at: { type: Date, required: true },
  },
  { collection: 'audit_logs', minimize: false, versionKey: false },
);

auditLogSchema.index({ entityType: 1, entityId: 1, at: -1 });
auditLogSchema.index({ 'actor.userId': 1, at: -1 });
auditLogSchema.index({ action: 1, at: -1 });
auditLogSchema.index({ operatorId: 1, at: -1 });
