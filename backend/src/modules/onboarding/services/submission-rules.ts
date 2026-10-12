import {
  type DocumentSubject,
  type DocumentType,
} from '../../document-types/schemas/document-type.schema';
import {
  type OnboardingSubmission,
  type SubmittedDocument,
} from '../schemas/onboarding-submission.schema';

/** The part of a document type the rules need. */
export type TypeRule = Pick<
  DocumentType,
  'key' | 'name' | 'isRequired' | 'requiresExpiry' | 'maxFiles'
> & {
  _id: { toHexString(): string };
};

/** Midnight (UTC) of today, so "valid today" counts as valid. */
export function startOfToday(now: Date = new Date()): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

/** A `YYYY-MM-DD` string as a date (UTC midnight), or undefined when it is not a real date. */
export function parseCalendarDate(value: string): Date | undefined {
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value
    ? undefined
    : date;
}

/** Which kind of document types a submission asks for. */
export function subjectOf(submission: Pick<OnboardingSubmission, 'subjectType'>): DocumentSubject {
  return submission.subjectType;
}

function findDocument(
  submission: Pick<OnboardingSubmission, 'documents'>,
  type: TypeRule,
): SubmittedDocument | undefined {
  return submission.documents.find(
    (document) => document.documentTypeId.toHexString() === type._id.toHexString(),
  );
}

/** Where one document stands, for the owner's checklist. */
export type ChecklistState = 'MISSING' | 'PENDING' | 'APPROVED' | 'REJECTED';

export function checklistStateOf(document: SubmittedDocument | undefined): ChecklistState {
  return document ? document.status : 'MISSING';
}

/**
 * What stops a submission from being sent for review, in words the owner can act on. Empty when
 * it can be sent. `activeTypes` are the document types asked for now.
 */
export function submissionProblems(
  submission: Pick<OnboardingSubmission, 'documents' | 'status'>,
  activeTypes: readonly TypeRule[],
  today: Date,
): string[] {
  const problems: string[] = [];
  for (const type of activeTypes) {
    const document = findDocument(submission, type);
    if (!document) {
      if (type.isRequired) problems.push(`"${type.name}" is missing.`);
      continue;
    }
    if (document.fileIds.length === 0) problems.push(`"${type.name}" has no file.`);
    if (document.status === 'REJECTED') {
      problems.push(
        `"${type.name}" was rejected${document.rejectionReason ? `: ${document.rejectionReason}` : '.'} Replace it.`,
      );
    }
    if (type.requiresExpiry) {
      if (!document.expiryDate) problems.push(`"${type.name}" needs its expiry date.`);
      else if (document.expiryDate < today) problems.push(`"${type.name}" has expired.`);
    }
  }
  // Documents of a type that is no longer asked for are still judged
  for (const document of submission.documents) {
    const stillAsked = activeTypes.some(
      (type) => type._id.toHexString() === document.documentTypeId.toHexString(),
    );
    if (!stillAsked && document.status === 'REJECTED') {
      problems.push(`"${document.documentTypeName}" was rejected. Replace or remove it.`);
    }
  }
  return problems;
}

/**
 * What stops a reviewer from approving: every document must have been looked at and accepted, and
 * none may have expired in the meantime. Empty when it can be approved.
 */
export function approvalProblems(
  submission: Pick<OnboardingSubmission, 'documents'>,
  today: Date,
): string[] {
  const problems: string[] = [];
  for (const document of submission.documents) {
    if (document.status === 'PENDING') {
      problems.push(`"${document.documentTypeName}" has not been reviewed yet.`);
    } else if (document.status === 'REJECTED') {
      problems.push(`"${document.documentTypeName}" is rejected. Reject the submission instead.`);
    } else if (document.expiryDate && document.expiryDate < today) {
      problems.push(`"${document.documentTypeName}" has expired.`);
    }
  }
  return problems;
}
