import { Schema, type Types } from 'mongoose';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const OPERATOR_MODEL = 'Operator';

export const OPERATOR_STATUSES = ['PENDING_APPROVAL', 'ACTIVE', 'REJECTED', 'SUSPENDED'] as const;
export type OperatorStatus = (typeof OPERATOR_STATUSES)[number];

/** AUTO_SPLIT: Razorpay Route splits each payment. MANUAL: Abra collects and settles each cycle. */
export const PAYOUT_MODES = ['AUTO_SPLIT', 'MANUAL'] as const;
export type PayoutMode = (typeof PAYOUT_MODES)[number];

export const BANK_STATUSES = ['PENDING', 'VERIFIED', 'FAILED'] as const;
export type BankStatus = (typeof BANK_STATUSES)[number];
export const BANK_VERIFICATION_METHODS = ['MANUAL', 'PENNY_DROP'] as const;

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
  /** How Abra pays this operator; AUTO_SPLIT needs a verified bank account. */
  payoutMode?: PayoutMode;
  /** Where payouts go. Added by the operator; changing it sends it back to PENDING. */
  bank?: OperatorBank;
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

export interface OperatorBank {
  holderName: string;
  /** Encrypted with FieldEncryptionService; the full number is never shown or returned. */
  accountNumberEncrypted: string;
  accountLast4: string;
  ifsc: string;
  bankName?: string;
  status: BankStatus;
  method?: (typeof BANK_VERIFICATION_METHODS)[number];
  /** What was checked, or why the check failed (a failure reason is shown to the owner). */
  verificationNote?: string;
  verifiedAt?: Date;
  verifiedBy?: Types.ObjectId;
  addedAt: Date;
}

/** `operators` (database-architecture.md §1). */
export const operatorSchema = new Schema<Operator>(
  {
    companyName: { type: String, required: true, trim: true, maxlength: 160 },
    displayName: { type: String, trim: true, maxlength: 80 },
    status: { type: String, enum: OPERATOR_STATUSES, required: true, default: 'PENDING_APPROVAL' },
    payoutMode: { type: String, enum: PAYOUT_MODES, required: true, default: 'MANUAL' },
    bank: {
      type: new Schema<OperatorBank>(
        {
          holderName: { type: String, required: true, trim: true, maxlength: 120 },
          accountNumberEncrypted: { type: String, required: true },
          accountLast4: { type: String, required: true, minlength: 4, maxlength: 4 },
          ifsc: { type: String, required: true, uppercase: true, trim: true, maxlength: 11 },
          bankName: { type: String, trim: true, maxlength: 120 },
          status: { type: String, enum: BANK_STATUSES, required: true, default: 'PENDING' },
          method: { type: String, enum: BANK_VERIFICATION_METHODS },
          verificationNote: { type: String, trim: true, maxlength: 500 },
          verifiedAt: { type: Date },
          verifiedBy: { type: Schema.Types.ObjectId },
          addedAt: { type: Date, required: true },
        },
        { _id: false },
      ),
    },
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
