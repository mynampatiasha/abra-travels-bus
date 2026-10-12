import { type ClientKycSnapshot } from '../client_kyc';
import { Schema, type Types } from 'mongoose';

export const ONBOARDING_SUBMISSION_MODEL = 'OnboardingSubmission';

/** What is being approved: the bus-owning company, or one of its buses. */
export const SUBMISSION_SUBJECTS = ['OPERATOR', 'BUS'] as const;
export type SubmissionSubject = (typeof SUBMISSION_SUBJECTS)[number];

/**
 * DRAFT: the owner is still collecting documents. PENDING: sent for review, locked. APPROVED:
 * accepted; the operator or bus is live. REJECTED: sent back with reasons; the owner fixes only
 * the rejected documents and sends it again (PENDING).
 */
export const SUBMISSION_STATUSES = ['DRAFT', 'PENDING', 'APPROVED', 'REJECTED'] as const;
export type SubmissionStatus = (typeof SUBMISSION_STATUSES)[number];

export const DOCUMENT_REVIEW_STATUSES = ['PENDING', 'APPROVED', 'REJECTED'] as const;
export type DocumentReviewStatus = (typeof DOCUMENT_REVIEW_STATUSES)[number];

/** One document of a submission, with the reviewer's decision on it. */
export interface SubmittedDocument {
  documentTypeId: Types.ObjectId;
  /** Copied when added, so the submission still reads correctly if the type is renamed. */
  documentTypeKey: string;
  documentTypeName: string;
  fileIds: Types.ObjectId[];
  expiryDate?: Date;
  status: DocumentReviewStatus;
  rejectionReason?: string;
  reviewedBy?: Types.ObjectId;
  reviewedAt?: Date;
}

export const HISTORY_ACTIONS = [
  'CREATED',
  'SUBMITTED',
  'RESUBMITTED',
  'DOCUMENT_APPROVED',
  'DOCUMENT_REJECTED',
  'APPROVED',
  'REJECTED',
] as const;
export type HistoryAction = (typeof HISTORY_ACTIONS)[number];

/** What happened to the submission, in order. Never edited afterwards. */
export interface SubmissionHistoryEntry {
  at: Date;
  action: HistoryAction;
  byUserId: Types.ObjectId;
  documentTypeKey?: string;
  note?: string;
}

export interface OnboardingSubmission {
  kyc?: ClientKycSnapshot;
  kycRequired?: boolean;
  operatorId: Types.ObjectId;
  subjectType: SubmissionSubject;
  /** Set when the subject is a bus. */
  busId?: Types.ObjectId;
  status: SubmissionStatus;
  documents: SubmittedDocument[];
  history: SubmissionHistoryEntry[];
  /** How many times it was sent for review. */
  submitCount: number;
  submittedAt?: Date;
  decidedAt?: Date;
  decidedBy?: Types.ObjectId;
  /** The reviewer's overall note on a rejection. */
  decisionNote?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

const submittedDocumentSchema = new Schema<SubmittedDocument>(
  {
    documentTypeId: { type: Schema.Types.ObjectId, required: true },
    documentTypeKey: { type: String, required: true },
    documentTypeName: { type: String, required: true },
    fileIds: { type: [Schema.Types.ObjectId], required: true },
    expiryDate: { type: Date },
    status: { type: String, enum: DOCUMENT_REVIEW_STATUSES, required: true, default: 'PENDING' },
    rejectionReason: { type: String, maxlength: 500 },
    reviewedBy: { type: Schema.Types.ObjectId },
    reviewedAt: { type: Date },
  },
  { _id: false },
);

const historyEntrySchema = new Schema<SubmissionHistoryEntry>(
  {
    at: { type: Date, required: true },
    action: { type: String, enum: HISTORY_ACTIONS, required: true },
    byUserId: { type: Schema.Types.ObjectId, required: true },
    documentTypeKey: { type: String },
    note: { type: String, maxlength: 500 },
  },
  { _id: false },
);

/** `onboarding_submissions`. */
export const onboardingSubmissionSchema = new Schema<OnboardingSubmission>(
  {
    kyc: { type: Schema.Types.Mixed },
    kycRequired: { type: Boolean },
    operatorId: { type: Schema.Types.ObjectId, required: true },
    subjectType: { type: String, enum: SUBMISSION_SUBJECTS, required: true },
    busId: { type: Schema.Types.ObjectId },
    status: { type: String, enum: SUBMISSION_STATUSES, required: true, default: 'DRAFT' },
    documents: { type: [submittedDocumentSchema], default: [] },
    history: { type: [historyEntrySchema], default: [] },
    submitCount: { type: Number, required: true, default: 0, min: 0 },
    submittedAt: { type: Date },
    decidedAt: { type: Date },
    decidedBy: { type: Schema.Types.ObjectId },
    decisionNote: { type: String, maxlength: 500 },
  },
  { collection: 'onboarding_submissions', timestamps: true, versionKey: false },
);

// One company submission per operator, one submission per bus
onboardingSubmissionSchema.index(
  { operatorId: 1 },
  { unique: true, partialFilterExpression: { subjectType: 'OPERATOR' } },
);
onboardingSubmissionSchema.index(
  { busId: 1 },
  { unique: true, partialFilterExpression: { subjectType: 'BUS' } },
);
onboardingSubmissionSchema.index({ status: 1, submittedAt: 1 });
