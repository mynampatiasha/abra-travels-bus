import { snapshotTypes, kycProblems } from '../client_kyc';
import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { dayRange, skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { OutboxService } from '../../../events/outbox.service';
import { BusRepository } from '../../buses/repositories/bus.repository';
import { DocumentTypeRepository } from '../../document-types/repositories/document-type.repository';
import { FilesService } from '../../files/services/files.service';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import {
  type CreateBusSubmissionDto,
  type SetDocumentDto,
  type SubmissionListQueryDto,
} from '../dto/onboarding.dto';
import { type StoredSubmission, SubmissionRepository } from '../repositories/submission.repository';
import { type SubmittedDocument } from '../schemas/onboarding-submission.schema';
import { OnboardingAuditor } from './onboarding-auditor';
import { parseCalendarDate, startOfToday, submissionProblems } from './submission-rules';
import {
  type SubmissionSummaryView,
  type SubmissionView,
  SubmissionViewService,
} from './submission-view.service';

function wrongState(message: string): ApiException {
  return new ApiException('INVALID_STATE_TRANSITION', message);
}

/**
 * The bus owner's side of onboarding: start the file of a bus, put documents in it, and send it
 * for review. Reading and editing are limited to the owner's own operator by the repository's data
 * scope; platform staff reach every operator's submissions.
 */
@Injectable()
export class SubmissionsService {
  constructor(
    private readonly submissions: SubmissionRepository,
    private readonly views: SubmissionViewService,
    private readonly documentTypes: DocumentTypeRepository,
    private readonly files: FilesService,
    private readonly buses: BusRepository,
    private readonly operators: OperatorRepository,
    private readonly transactions: TransactionRunner,
    private readonly outbox: OutboxService,
    private readonly auditor: OnboardingAuditor,
  ) {}

  async list(query: SubmissionListQueryDto): Promise<PaginatedResult<SubmissionSummaryView>> {
    const filter = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.subjectType ? { subjectType: query.subjectType } : {}),
      ...(query.operatorId ? { operatorId: new Types.ObjectId(query.operatorId) } : {}),
      ...(dayRange(query) ? { submittedAt: dayRange(query) } : {}),
    };
    // Waiting for review: oldest first, so nobody waits longest
    const sort: Record<string, 1 | -1> =
      query.status === 'PENDING' ? { submittedAt: 1 } : { updatedAt: -1 };
    const [items, total] = await Promise.all([
      this.submissions.findMany(filter, { sort, skip: skipOf(query), limit: query.pageSize }),
      this.submissions.count(filter),
    ]);
    return new PaginatedResult(
      await this.views.summaries(items),
      query.page,
      query.pageSize,
      total,
    );
  }

  async get(id: string): Promise<SubmissionView> {
    return this.views.detail(await this.submissions.getById(id));
  }

  /** The review file of a bus the owner added. Asking again returns the same file. */
  async createForBus(
    actor: AuthenticatedUserActor,
    input: CreateBusSubmissionDto,
  ): Promise<SubmissionView> {
    // Scoped: a bus of another operator does not exist for the caller
    const bus = await this.buses.getById(input.busId);
    const existing = await this.submissions.findOne({ subjectType: 'BUS', busId: bus._id });
    if (existing) return this.views.detail(existing);
    if (bus.status !== 'PENDING_APPROVAL') {
      throw wrongState('This bus does not need approval.');
    }
    try {
      const created = await this.transactions.run((session) =>
        this.submissions.insertOne(
          {
            operatorId: bus.operatorId,
            subjectType: 'BUS',
            busId: bus._id,
            status: 'DRAFT',
            documents: [],
            submitCount: 0,
            history: [
              { at: new Date(), action: 'CREATED', byUserId: new Types.ObjectId(actor.userId) },
            ],
          },
          { session },
        ),
      );
      return await this.views.detail(created);
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      // Created by a request that ran at the same moment
      const winner = await this.submissions.findOne({ subjectType: 'BUS', busId: bus._id });
      if (!winner) throw error;
      return this.views.detail(winner);
    }
  }

  /**
   * Puts files into one document, replacing what was there. Allowed while the submission is a draft
   * or was sent back; a document the reviewer approved stays as approved.
   */
  async setDocument(
    id: string,
    documentTypeId: string,
    input: SetDocumentDto,
  ): Promise<SubmissionView> {
    const submission = await this.submissions.getById(id);
    this.assertEditable(submission);
    const type = await this.documentTypes.findById(documentTypeId);
    if (!type?.isActive || type.appliesTo !== submission.subjectType) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'This document is not asked for here.');
    }
    if (submission.kyc && !submission.kyc.requirements.some((d) => d.id === documentTypeId))
      throw new ApiException(
        'VALIDATION_FAILED',
        'This document is not part of your KYC checklist.',
      );
    const current = this.documentOf(submission, type._id);
    this.assertDocumentEditable(submission, current);

    const fileCount = new Set(input.fileIds).size;
    if (fileCount > type.maxFiles) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `${type.name} accepts at most ${type.maxFiles} file${type.maxFiles === 1 ? '' : 's'}.`,
      );
    }
    let expiryDate: Date | undefined;
    if (type.requiresExpiry) {
      if (!input.expiryDate) {
        throw new ApiException('VALIDATION_FAILED', `${type.name} needs its expiry date.`);
      }
      expiryDate = parseCalendarDate(input.expiryDate);
      if (!expiryDate) {
        throw new ApiException('VALIDATION_FAILED', 'The expiry date is not a real date.');
      }
      if (expiryDate < startOfToday()) {
        throw new ApiException('VALIDATION_FAILED', `${type.name} has already expired.`);
      }
    } else if (input.expiryDate) {
      throw new ApiException('VALIDATION_FAILED', `${type.name} has no expiry date.`);
    }

    const saved = await this.transactions.run(async (session) => {
      const attached = await this.files.attachToSubmission(
        {
          ids: input.fileIds,
          operatorId: submission.operatorId,
          documentTypeId: type._id,
          submissionId: submission._id,
        },
        session,
      );
      const keptIds = new Set(attached.map((file) => file._id.toHexString()));
      const dropped = (current?.fileIds ?? []).filter(
        (fileId) => !keptIds.has(fileId.toHexString()),
      );
      await this.files.releaseFromSubmission(dropped, session);

      const replacement: SubmittedDocument = {
        documentTypeId: type._id,
        documentTypeKey: type.key,
        documentTypeName: type.name,
        fileIds: attached.map((file) => file._id),
        ...(expiryDate ? { expiryDate } : {}),
        // New content needs a new look, whatever was decided about the old one
        status: 'PENDING',
      };
      const documents = current
        ? submission.documents.map((document) =>
            document.documentTypeId.equals(type._id) ? replacement : document,
          )
        : [...submission.documents, replacement];
      return this.submissions.saveChange(submission, { documents }, session);
    });
    return this.views.detail(saved);
  }

  async removeDocument(id: string, documentTypeId: string): Promise<SubmissionView> {
    const submission = await this.submissions.getById(id);
    this.assertEditable(submission);
    const current = submission.documents.find(
      (document) => document.documentTypeId.toHexString() === documentTypeId,
    );
    if (!current) throw new ApiException('RESOURCE_NOT_FOUND', 'This document was not added.');
    this.assertDocumentEditable(submission, current);
    const saved = await this.transactions.run(async (session) => {
      await this.files.releaseFromSubmission(current.fileIds, session);
      return this.submissions.saveChange(
        submission,
        { documents: submission.documents.filter((document) => document !== current) },
        session,
      );
    });
    return this.views.detail(saved);
  }

  /** Sends the submission for review (again, when it was sent back). */
  async submit(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<SubmissionView> {
    const submission = await this.submissions.getById(id);
    this.assertEditable(submission);
    const activeTypes =
      snapshotTypes(submission) ?? (await this.documentTypes.activeFor(submission.subjectType));
    const problems = [
      ...kycProblems(submission),
      ...submissionProblems(submission, activeTypes, startOfToday()),
    ];
    if (problems.length > 0) {
      throw new ApiException('VALIDATION_FAILED', problems.join(' '), { problems });
    }
    const labels = await this.assertSubjectAwaitsApproval(submission);

    const resubmission = submission.status === 'REJECTED';
    const now = new Date();
    const saved = await this.transactions.run(async (session) => {
      const updated = await this.submissions.saveChange(
        submission,
        {
          status: 'PENDING',
          submittedAt: now,
          submitCount: submission.submitCount + 1,
          history: [
            ...submission.history,
            {
              at: now,
              action: resubmission ? 'RESUBMITTED' : 'SUBMITTED',
              byUserId: new Types.ObjectId(actor.userId),
            },
          ],
        },
        session,
        // the previous rejection no longer applies
        ['decisionNote', 'decidedAt', 'decidedBy'],
      );
      await this.auditor.record(
        {
          actor,
          action: 'onboarding.submitted',
          entityType: 'onboarding_submission',
          entityId: updated._id,
          operatorId: updated.operatorId,
          before: { status: submission.status },
          after: { status: updated.status, submitCount: updated.submitCount },
          client,
        },
        session,
      );
      await this.outbox.record(
        {
          type: 'onboarding.submitted',
          aggregateType: 'onboarding_submission',
          aggregateId: updated._id.toHexString(),
          payload: {
            submissionId: updated._id.toHexString(),
            operatorId: updated.operatorId.toHexString(),
            subjectType: updated.subjectType,
            busId: updated.busId?.toHexString() ?? null,
            ...labels,
            resubmission,
          },
        },
        session,
      );
      return updated;
    });
    return this.views.detail(saved);
  }

  private documentOf(
    submission: StoredSubmission,
    documentTypeId: Types.ObjectId,
  ): SubmittedDocument | undefined {
    return submission.documents.find((document) => document.documentTypeId.equals(documentTypeId));
  }

  private assertEditable(submission: StoredSubmission): void {
    if (submission.status === 'PENDING') {
      throw wrongState('This was sent for review. Wait for the decision.');
    }
    if (submission.status === 'APPROVED') throw wrongState('This was approved already.');
  }

  /** After a rejection only what was rejected (or never added) can change. */
  private assertDocumentEditable(
    submission: StoredSubmission,
    document: SubmittedDocument | undefined,
  ): void {
    if (submission.status === 'REJECTED' && document?.status === 'APPROVED') {
      throw wrongState('This document was approved. Only rejected documents can be replaced.');
    }
  }

  /** A company or bus that is already live (or refused for good) has nothing to send. */
  private async assertSubjectAwaitsApproval(
    submission: StoredSubmission,
  ): Promise<{ companyName: string; busRegistrationNumber: string | null }> {
    const operator = await this.operators.getById(submission.operatorId.toHexString());
    const companyName = operator.displayName ?? operator.companyName;
    if (submission.subjectType === 'OPERATOR') {
      if (operator.status !== 'PENDING_APPROVAL') {
        throw wrongState(`The company is ${operator.status.toLowerCase().replace('_', ' ')}.`);
      }
      return { companyName, busRegistrationNumber: null };
    }
    const bus = await this.buses.getById((submission.busId as Types.ObjectId).toHexString());
    if (bus.status !== 'PENDING_APPROVAL') {
      throw wrongState('This bus does not need approval.');
    }
    return { companyName, busRegistrationNumber: bus.registrationNumber };
  }
}
