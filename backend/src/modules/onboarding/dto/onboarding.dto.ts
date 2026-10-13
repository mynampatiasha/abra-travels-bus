import { z } from 'zod';
import { newPasswordSchema } from '../../authentication/services/password-policy';
import { dateRangeShape, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { phoneNumberSchema } from '../../../common/validation/contact-identifiers';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { INVITATION_STATUSES } from '../schemas/onboarding-invitation.schema';
import { SUBMISSION_STATUSES, SUBMISSION_SUBJECTS } from '../schemas/onboarding-submission.schema';

const email = z.email().max(254);
const reason = z.string().trim().min(3).max(500);

// ------------------------------------------------------------- invitations

export class InviteClientDto extends createZodDto(
  z.object({
    companyName: z.string().trim().min(2).max(160),
    displayName: z.string().trim().min(2).max(80).optional(),
    ownerName: z.string().trim().min(2).max(120),
    email,
    /** A 10-digit Indian mobile or E.164 (+919876543210); stored as E.164. */
    phone: phoneNumberSchema.optional(),
  }),
) {}

export class InvitationListQueryDto extends createZodDto(
  z.object({
    /** EXPIRED is a pending invitation whose seven days have passed; PENDING is one still valid. */
    status: z.enum([...INVITATION_STATUSES, 'EXPIRED']).optional(),
    /** Part of the company, owner or email. */
    search: z.string().trim().min(1).max(80).optional(),
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

export class InvitationIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

/** What the Client Portal sends before showing the "set your password" page. */
export class InspectInvitationDto extends createZodDto(
  z.object({ token: z.string().min(20).max(200) }),
) {}

export class AcceptInvitationDto extends createZodDto(
  z.object({
    token: z.string().min(20).max(200),
    name: z.string().trim().min(2).max(120).optional(),
    password: newPasswordSchema,
  }),
) {}

// ------------------------------------------------------------- submissions

export class SubmissionListQueryDto extends createZodDto(
  z.object({
    status: z.enum(SUBMISSION_STATUSES).optional(),
    subjectType: z.enum(SUBMISSION_SUBJECTS).optional(),
    /** Platform staff only; operator staff always see their own operator. */
    operatorId: objectIdString.optional(),
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

export class SubmissionIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class SubmissionDocumentParamDto extends createZodDto(
  z.object({ id: objectIdString, documentTypeId: objectIdString }),
) {}

/** Starts the review file of a bus the owner added. */
export class CreateBusSubmissionDto extends createZodDto(z.object({ busId: objectIdString })) {}

/** Puts files into one document of a submission, replacing what was there. */
export class SetDocumentDto extends createZodDto(
  z.object({
    fileIds: z.array(objectIdString).min(1).max(10),
    /** Required when the document type has an expiry date. Format YYYY-MM-DD. */
    expiryDate: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date like 2027-03-31')
      .optional(),
  }),
) {}

// ------------------------------------------------------------------ review

export class ReviewDocumentDto extends createZodDto(
  z
    .object({
      decision: z.enum(['APPROVED', 'REJECTED']),
      /** Required when rejecting: the client reads it to know what to fix. */
      reason: reason.optional(),
    })
    .refine((value) => value.decision === 'APPROVED' || value.reason !== undefined, {
      message: 'say why the document is rejected',
      path: ['reason'],
    }),
) {}

export class RejectSubmissionDto extends createZodDto(z.object({ note: reason.optional() })) {}
