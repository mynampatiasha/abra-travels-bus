import { snapshotTypes, kycProblems } from '../client_kyc';
import { Injectable } from '@nestjs/common';
import { type Types } from 'mongoose';
import { BusRepository } from '../../buses/repositories/bus.repository';
import { DocumentTypeRepository } from '../../document-types/repositories/document-type.repository';
import { type FileView, FilesService } from '../../files/services/files.service';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { type OnboardingSubmission } from '../schemas/onboarding-submission.schema';
import { type StoredSubmission } from '../repositories/submission.repository';
import {
  type ChecklistState,
  checklistStateOf,
  startOfToday,
  submissionProblems,
} from './submission-rules';

export interface SubmissionDocumentView {
  documentTypeId: string;
  key: string;
  name: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  /** Why the reviewer rejected it. What the owner reads to fix it. */
  rejectionReason: string | null;
  /** YYYY-MM-DD. */
  expiryDate: string | null;
  files: FileView[];
  reviewedAt: string | null;
}

/** One document the platform asks for, and where the owner stands on it. */
export interface ChecklistItemView {
  documentTypeId: string;
  key: string;
  name: string;
  instructions: string;
  isRequired: boolean;
  requiresExpiry: boolean;
  maxFiles: number;
  maxFileSizeMb: number;
  allowedMimeTypes: string[];
  state: ChecklistState;
}

export interface SubmissionSummaryView {
  id: string;
  operatorId: string;
  companyName: string;
  subjectType: string;
  busId: string | null;
  /** Registration number of the bus, for a bus submission. */
  busRegistrationNumber: string | null;
  status: string;
  submitCount: number;
  submittedAt: string | null;
  decidedAt: string | null;
  updatedAt: string | null;
}

export interface SubmissionView extends SubmissionSummaryView {
  kyc: OnboardingSubmission['kyc'] | null;
  busName: string | null;
  decisionNote: string | null;
  documents: SubmissionDocumentView[];
  checklist: ChecklistItemView[];
  /** What stops it from being sent for review right now; empty when it can be sent. */
  problems: string[];
  canSubmit: boolean;
  history: Array<{
    at: string;
    action: string;
    byUserId: string;
    documentTypeKey: string | null;
    note: string | null;
  }>;
}

const iso = (date: Date | undefined): string | null => date?.toISOString() ?? null;
const day = (date: Date | undefined): string | null => date?.toISOString().slice(0, 10) ?? null;

/** Turns stored submissions into what the apps show, with the files and the checklist. */
@Injectable()
export class SubmissionViewService {
  constructor(
    private readonly operators: OperatorRepository,
    private readonly buses: BusRepository,
    private readonly documentTypes: DocumentTypeRepository,
    private readonly files: FilesService,
  ) {}

  /** List rows: no files, no checklist. Names are looked up once per page. */
  async summaries(submissions: readonly StoredSubmission[]): Promise<SubmissionSummaryView[]> {
    const operatorIds = [...new Set(submissions.map((item) => item.operatorId.toHexString()))];
    const busIds = submissions.flatMap((item) => (item.busId ? [item.busId.toHexString()] : []));
    const [operators, buses] = await Promise.all([
      operatorIds.length > 0
        ? this.operators.findMany({ _id: { $in: operatorIds } })
        : Promise.resolve([]),
      busIds.length > 0 ? this.buses.findMany({ _id: { $in: busIds } }) : Promise.resolve([]),
    ]);
    return submissions.map((submission) => {
      const operator = operators.find((item) => item._id.equals(submission.operatorId));
      const bus = submission.busId
        ? buses.find((item) => item._id.equals(submission.busId as Types.ObjectId))
        : undefined;
      return {
        id: submission._id.toHexString(),
        operatorId: submission.operatorId.toHexString(),
        companyName: operator?.displayName ?? operator?.companyName ?? '',
        subjectType: submission.subjectType,
        busId: submission.busId?.toHexString() ?? null,
        busRegistrationNumber: bus?.registrationNumber ?? null,
        status: submission.status,
        submitCount: submission.submitCount,
        submittedAt: iso(submission.submittedAt),
        decidedAt: iso(submission.decidedAt),
        updatedAt: iso(submission.updatedAt),
      };
    });
  }

  async detail(submission: StoredSubmission): Promise<SubmissionView> {
    const [summary] = await this.summaries([submission]);
    if (!summary) throw new Error('A submission has no summary');
    const bus = submission.busId ? await this.buses.findById(submission.busId.toHexString()) : null;
    const activeTypes =
      snapshotTypes(submission) ?? (await this.documentTypes.activeFor(submission.subjectType));

    const documents: SubmissionDocumentView[] = [];
    for (const document of submission.documents) {
      documents.push({
        documentTypeId: document.documentTypeId.toHexString(),
        key: document.documentTypeKey,
        name: document.documentTypeName,
        status: document.status,
        rejectionReason: document.rejectionReason ?? null,
        expiryDate: day(document.expiryDate),
        files: await this.files.describeMany(document.fileIds),
        reviewedAt: iso(document.reviewedAt),
      });
    }

    const checklist: ChecklistItemView[] = activeTypes.map((type) => ({
      documentTypeId: type._id.toHexString(),
      key: type.key,
      name: type.name,
      instructions: type.instructions,
      isRequired: type.isRequired,
      requiresExpiry: type.requiresExpiry,
      maxFiles: type.maxFiles,
      maxFileSizeMb: type.maxFileSizeMb,
      allowedMimeTypes: [...type.allowedMimeTypes],
      state: checklistStateOf(
        submission.documents.find((item) => item.documentTypeId.equals(type._id)),
      ),
    }));

    const editable = submission.status === 'DRAFT' || submission.status === 'REJECTED';
    const problems = editable
      ? [...kycProblems(submission), ...submissionProblems(submission, activeTypes, startOfToday())]
      : [];
    return {
      ...summary,
      kyc: submission.kyc ?? null,
      busName: bus?.name ?? null,
      decisionNote: submission.decisionNote ?? null,
      documents,
      checklist,
      problems,
      canSubmit: editable && problems.length === 0,
      history: submission.history.map((entry) => ({
        at: entry.at.toISOString(),
        action: entry.action,
        byUserId: entry.byUserId.toHexString(),
        documentTypeKey: entry.documentTypeKey ?? null,
        note: entry.note ?? null,
      })),
    };
  }
}
