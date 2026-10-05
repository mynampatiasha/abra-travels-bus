import { Schema } from 'mongoose';

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
  createdAt?: Date;
  updatedAt?: Date;
}

/** `operators` (database-architecture.md §1). */
export const operatorSchema = new Schema<Operator>(
  {
    companyName: { type: String, required: true, trim: true, maxlength: 160 },
    displayName: { type: String, trim: true, maxlength: 80 },
    status: { type: String, enum: OPERATOR_STATUSES, required: true, default: 'PENDING_APPROVAL' },
  },
  { collection: 'operators', timestamps: true, versionKey: false },
);

operatorSchema.index({ status: 1 });
