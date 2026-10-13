import { Schema, type Types } from 'mongoose';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const ONBOARDING_INVITATION_MODEL = 'OnboardingInvitation';

/** PENDING: waiting for the owner. ACCEPTED: the owner set a password. REVOKED: withdrawn. */
export const INVITATION_STATUSES = ['PENDING', 'ACCEPTED', 'REVOKED'] as const;
export type InvitationStatus = (typeof INVITATION_STATUSES)[number];

/**
 * An invitation for a bus owner to join the platform. Platform staff create the operator and the
 * invitation together; the owner follows the emailed link and sets a password. Only a hash of the
 * link's token is stored, so a database leak cannot be used to take over an invited account.
 */
export interface OnboardingInvitation {
  operatorId: Types.ObjectId;
  /** The company's name when invited, so the sign-up page can show it without signing in. */
  companyName: string;
  /** Lower-cased; the account created on acceptance uses this address. */
  email: string;
  ownerName: string;
  /** E.164, optional. */
  phone?: string;
  /** SHA-256 of the token in the link (hex). */
  tokenHash: string;
  expiresAt: Date;
  status: InvitationStatus;
  invitedBy: Types.ObjectId;
  /** Whether the email with the link was handed to the mail server. */
  emailStatus: 'SENT' | 'FAILED' | 'NOT_SENT';
  acceptedAt?: Date;
  acceptedUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `onboarding_invitations`. */
export const onboardingInvitationSchema = new Schema<OnboardingInvitation>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    companyName: { type: String, required: true, trim: true, maxlength: 160 },
    email: { type: String, required: true, lowercase: true, trim: true, maxlength: 254 },
    ownerName: { type: String, required: true, trim: true, maxlength: 120 },
    phone: { type: String, maxlength: 16 },
    tokenHash: { type: String, required: true, match: /^[0-9a-f]{64}$/ },
    expiresAt: { type: Date, required: true },
    status: { type: String, enum: INVITATION_STATUSES, required: true, default: 'PENDING' },
    invitedBy: { type: Schema.Types.ObjectId, required: true },
    emailStatus: {
      type: String,
      enum: ['SENT', 'FAILED', 'NOT_SENT'],
      required: true,
      default: 'NOT_SENT',
    },
    acceptedAt: { type: Date },
    acceptedUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'onboarding_invitations', timestamps: true, versionKey: false },
);

onboardingInvitationSchema.plugin(softDeletePlugin);
onboardingInvitationSchema.index({ tokenHash: 1 }, { unique: true });
onboardingInvitationSchema.index({ operatorId: 1 });
// One open invitation per address, so an owner is not invited twice at the same time
onboardingInvitationSchema.index(
  { email: 1 },
  { unique: true, partialFilterExpression: { status: 'PENDING' } },
);
