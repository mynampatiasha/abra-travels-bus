import { Schema, type Types } from 'mongoose';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const OPERATOR_MODEL = 'Operator';

export const OPERATOR_STATUSES = ['PENDING_APPROVAL', 'ACTIVE', 'REJECTED', 'SUSPENDED'] as const;
export type OperatorStatus = (typeof OPERATOR_STATUSES)[number];

/**
 * A bus operator (state-machines.md §Operator). Only what trip discovery needs exists so far:
 * the name customers see and the status that decides whether its trips are offered. Company
 * documents, bank details and contacts arrive with operator onboarding.
 */
export interface Operator {
  companyName: string;
  /** Name shown to customers; the company name when not set. */
  displayName?: string;
  status: OperatorStatus;
  /** Why and when Abra suspended it; kept after reactivation as the last suspension. */
  suspension?: OperatorSuspension;
  createdAt?: Date;
  updatedAt?: Date;
}

/** The reason is shown to the owner; the proof note is for Abra staff only. */
export interface OperatorSuspension {
  reason: string;
  proofNote?: string;
  /** Proof files (the files service checks and links them once proof uploads exist). */
  proofFileIds?: Types.ObjectId[];
  at: Date;
  by: Types.ObjectId;
  reactivatedAt?: Date;
  reactivatedBy?: Types.ObjectId;
}

/** `operators` (database-architecture.md §1). */
export const operatorSchema = new Schema<Operator>(
  {
    companyName: { type: String, required: true, trim: true, maxlength: 160 },
    displayName: { type: String, trim: true, maxlength: 80 },
    status: { type: String, enum: OPERATOR_STATUSES, required: true, default: 'PENDING_APPROVAL' },
    suspension: {
      type: new Schema<OperatorSuspension>(
        {
          reason: { type: String, required: true, trim: true, maxlength: 500 },
          proofNote: { type: String, trim: true, maxlength: 1000 },
          proofFileIds: { type: [Schema.Types.ObjectId], default: undefined },
          at: { type: Date, required: true },
          by: { type: Schema.Types.ObjectId, required: true },
          reactivatedAt: { type: Date },
          reactivatedBy: { type: Schema.Types.ObjectId },
        },
        { _id: false },
      ),
    },
  },
  { collection: 'operators', timestamps: true, versionKey: false },
);

operatorSchema.plugin(softDeletePlugin);
operatorSchema.index({ status: 1 });
