import { Types } from 'mongoose';
import {
  approvalProblems,
  checklistStateOf,
  parseCalendarDate,
  startOfToday,
  submissionProblems,
  type TypeRule,
} from '../services/submission-rules';
import { type SubmittedDocument } from '../schemas/onboarding-submission.schema';

const TODAY = new Date('2026-10-07T00:00:00.000Z');

function type(name: string, overrides: Partial<TypeRule> = {}): TypeRule {
  return {
    _id: new Types.ObjectId(),
    key: name.toUpperCase(),
    name,
    isRequired: true,
    requiresExpiry: false,
    maxFiles: 1,
    ...overrides,
  };
}

function document(
  forType: TypeRule,
  overrides: Partial<SubmittedDocument> = {},
): SubmittedDocument {
  return {
    documentTypeId: forType._id as Types.ObjectId,
    documentTypeKey: forType.key,
    documentTypeName: forType.name,
    fileIds: [new Types.ObjectId()],
    status: 'PENDING',
    ...overrides,
  };
}

describe('dates', () => {
  it('reads a calendar date as UTC midnight and refuses impossible ones', () => {
    expect(parseCalendarDate('2027-03-31')?.toISOString()).toBe('2027-03-31T00:00:00.000Z');
    expect(parseCalendarDate('2027-02-30')).toBeUndefined();
    expect(parseCalendarDate('2027-13-01')).toBeUndefined();
    expect(parseCalendarDate('not a date')).toBeUndefined();
  });

  it('today starts at midnight UTC, so a document valid today still counts', () => {
    expect(startOfToday(new Date('2026-10-07T18:45:10.000Z')).toISOString()).toBe(
      '2026-10-07T00:00:00.000Z',
    );
  });
});

describe('submissionProblems', () => {
  const gst = type('GST certificate');
  const insurance = type('Insurance', { requiresExpiry: true });
  const optional = type('Pollution', { isRequired: false });

  it('lists every missing required document, and ignores missing optional ones', () => {
    const problems = submissionProblems(
      { status: 'DRAFT', documents: [] },
      [gst, insurance, optional],
      TODAY,
    );
    expect(problems).toEqual(['"GST certificate" is missing.', '"Insurance" is missing.']);
  });

  it('is empty when everything required is in', () => {
    const submission = {
      status: 'DRAFT' as const,
      documents: [
        document(gst),
        document(insurance, { expiryDate: new Date('2027-01-01T00:00:00.000Z') }),
      ],
    };
    expect(submissionProblems(submission, [gst, insurance, optional], TODAY)).toEqual([]);
  });

  it('wants an expiry date, and refuses an expired one but not one that ends today', () => {
    const none = { status: 'DRAFT' as const, documents: [document(insurance)] };
    expect(submissionProblems(none, [insurance], TODAY)).toEqual([
      '"Insurance" needs its expiry date.',
    ]);

    const expired = {
      status: 'DRAFT' as const,
      documents: [document(insurance, { expiryDate: new Date('2026-10-06T00:00:00.000Z') })],
    };
    expect(submissionProblems(expired, [insurance], TODAY)).toEqual(['"Insurance" has expired.']);

    const endsToday = {
      status: 'DRAFT' as const,
      documents: [document(insurance, { expiryDate: TODAY })],
    };
    expect(submissionProblems(endsToday, [insurance], TODAY)).toEqual([]);
  });

  it('a rejected document must be replaced first, and its reason is repeated', () => {
    const submission = {
      status: 'REJECTED' as const,
      documents: [document(gst, { status: 'REJECTED', rejectionReason: 'Photo is blurred' })],
    };
    expect(submissionProblems(submission, [gst], TODAY)).toEqual([
      '"GST certificate" was rejected: Photo is blurred Replace it.',
    ]);
  });

  it('a rejected document of a type that is no longer asked for still blocks', () => {
    const retired = type('Old document');
    const submission = {
      status: 'REJECTED' as const,
      documents: [document(retired, { status: 'REJECTED' })],
    };
    expect(submissionProblems(submission, [gst], TODAY)).toEqual([
      '"GST certificate" is missing.',
      '"Old document" was rejected. Replace or remove it.',
    ]);
  });
});

describe('approvalProblems', () => {
  const gst = type('GST certificate');

  it('wants every document looked at and accepted', () => {
    expect(approvalProblems({ documents: [document(gst, { status: 'APPROVED' })] }, TODAY)).toEqual(
      [],
    );
    expect(approvalProblems({ documents: [document(gst)] }, TODAY)).toEqual([
      '"GST certificate" has not been reviewed yet.',
    ]);
    expect(approvalProblems({ documents: [document(gst, { status: 'REJECTED' })] }, TODAY)).toEqual(
      ['"GST certificate" is rejected. Reject the submission instead.'],
    );
  });

  it('refuses a document that expired while it waited', () => {
    const submission = {
      documents: [
        document(gst, { status: 'APPROVED', expiryDate: new Date('2026-10-06T00:00:00.000Z') }),
      ],
    };
    expect(approvalProblems(submission, TODAY)).toEqual(['"GST certificate" has expired.']);
  });
});

describe('checklistStateOf', () => {
  it('is MISSING without a document, otherwise the review state', () => {
    const gst = type('GST certificate');
    expect(checklistStateOf(undefined)).toBe('MISSING');
    expect(checklistStateOf(document(gst, { status: 'APPROVED' }))).toBe('APPROVED');
  });
});
