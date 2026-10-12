import { snapshotTypes, kycProblems } from '../client_kyc';
import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { OutboxService } from '../../../events/outbox.service';
import { BusRepository } from '../../buses/repositories/bus.repository';
import { DocumentTypeRepository } from '../../document-types/repositories/document-type.repository';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { type RejectSubmissionDto, type ReviewDocumentDto } from '../dto/onboarding.dto';
import { type StoredSubmission, SubmissionRepository } from '../repositories/submission.repository';
import { OnboardingAuditor } from './onboarding-auditor';
import { approvalProblems, startOfToday } from './submission-rules';
import { type SubmissionView, SubmissionViewService } from './submission-view.service';

function wrongState(message: string): ApiException {
  return new ApiException('INVALID_STATE_TRANSITION', message);
}

/**
 * The platform employee's side of onboarding. Each document is accepted or rejected (with the
 * reason the owner will read); then the submission as a whole is approved, which makes the company
 * or bus live, or rejected, which sends it back to be fixed. Needs `documents.review`.
 */
@Injectable()
export class SubmissionReviewService {
  constructor(
    private readonly submissions: SubmissionRepository,
    private readonly views: SubmissionViewService,
    private readonly documentTypes: DocumentTypeRepository,
    private readonly operators: OperatorRepository,
    private readonly buses: BusRepository,
    private readonly transactions: TransactionRunner,
    private readonly outbox: OutboxService,
    private readonly auditor: OnboardingAuditor,
  ) {}

  /** Accepts or rejects one document. It can be changed again until the submission is decided. */
  async reviewDocument(
    actor: AuthenticatedUserActor,
    id: string,
    documentTypeId: string,
    input: ReviewDocumentDto,
  ): Promise<SubmissionView> {
    if (actor.userType !== 'STAFF')
      throw new ApiException('PERMISSION_DENIED', 'Only platform administrators can review KYC.');
    const submission = await this.submissions.getById(id);
    this.assertAwaitingReview(submission);
    const target = submission.documents.find(
      (document) => document.documentTypeId.toHexString() === documentTypeId,
    );
    if (!target) throw new ApiException('RESOURCE_NOT_FOUND', 'This document was not added.');

    const now = new Date();
    const actorId = new Types.ObjectId(actor.userId);
    const rejected = input.decision === 'REJECTED';
    const documents = submission.documents.map((document) => {
      if (document !== target) return document;
      // Rebuilt field by field, so approving after rejecting leaves no stale reason
      return {
        documentTypeId: document.documentTypeId,
        documentTypeKey: document.documentTypeKey,
        documentTypeName: document.documentTypeName,
        fileIds: document.fileIds,
        ...(document.expiryDate ? { expiryDate: document.expiryDate } : {}),
        status: input.decision,
        ...(rejected && input.reason ? { rejectionReason: input.reason } : {}),
        reviewedBy: actorId,
        reviewedAt: now,
      };
    });
    const saved = await this.transactions.run((session) =>
      this.submissions.saveChange(
        submission,
        {
          documents,
          history: [
            ...submission.history,
            {
              at: now,
              action: rejected ? 'DOCUMENT_REJECTED' : 'DOCUMENT_APPROVED',
              byUserId: actorId,
              documentTypeKey: target.documentTypeKey,
              ...(rejected && input.reason ? { note: input.reason } : {}),
            },
          ],
        },
        session,
      ),
    );
    return this.views.detail(saved);
  }

  /**
   * Accepts the submission. Every document must have been accepted and none may have expired.
   * Approving a company makes the operator ACTIVE; approving a bus makes the bus ACTIVE, and only
   * once its company is live.
   */
  async approve(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<SubmissionView> {
    if (actor.userType !== 'STAFF')
      throw new ApiException('PERMISSION_DENIED', 'Only platform administrators can review KYC.');
    const submission = await this.submissions.getById(id);
    this.assertAwaitingReview(submission);
    const problems = [
      ...kycProblems(submission),
      ...approvalProblems(submission, startOfToday()),
      ...(await this.missingRequired(submission)),
    ];
    if (submission.documents.length === 0 && !submission.kyc)
      problems.push('No documents were added.');
    if (problems.length > 0) {
      throw new ApiException('VALIDATION_FAILED', problems.join(' '), { problems });
    }
    if (submission.subjectType === 'BUS') {
      const operator = await this.operators.getById(submission.operatorId.toHexString());
      if (operator.status !== 'ACTIVE') {
        throw wrongState(
          'Approve the company first. A bus can only go live for an approved company.',
        );
      }
    }

    const now = new Date();
    const actorId = new Types.ObjectId(actor.userId);
    const saved = await this.transactions.run(async (session) => {
      const updated = await this.submissions.saveChange(
        submission,
        {
          status: 'APPROVED',
          decidedAt: now,
          decidedBy: actorId,
          history: [...submission.history, { at: now, action: 'APPROVED', byUserId: actorId }],
        },
        session,
      );
      await this.activateSubject(updated, session);
      await this.auditor.record(
        {
          actor,
          action: 'onboarding.approved',
          entityType: 'onboarding_submission',
          entityId: updated._id,
          operatorId: updated.operatorId,
          before: { status: submission.status },
          after: { status: updated.status },
          client,
        },
        session,
      );
      await this.outbox.record(
        {
          type: 'onboarding.approved',
          aggregateType: 'onboarding_submission',
          aggregateId: updated._id.toHexString(),
          payload: await this.eventPayload(updated),
        },
        session,
      );
      return updated;
    });
    return this.views.detail(saved);
  }

  /**
   * Sends the submission back. At least one document must be rejected (with its reason) and every
   * document must have been looked at, so the owner learns everything to fix in one go.
   */
  async reject(
    actor: AuthenticatedUserActor,
    id: string,
    input: RejectSubmissionDto,
    client: ClientRequestInfo,
  ): Promise<SubmissionView> {
    if (actor.userType !== 'STAFF')
      throw new ApiException('PERMISSION_DENIED', 'Only platform administrators can review KYC.');
    const submission = await this.submissions.getById(id);
    this.assertAwaitingReview(submission);
    const rejectedDocuments = submission.documents.filter(
      (document) => document.status === 'REJECTED',
    );
    if (rejectedDocuments.length === 0) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'Reject at least one document, with its reason. If everything is correct, approve instead.',
      );
    }
    const unreviewed = submission.documents.filter((document) => document.status === 'PENDING');
    if (unreviewed.length > 0) {
      const names = unreviewed.map((document) => `"${document.documentTypeName}"`).join(', ');
      throw new ApiException(
        'VALIDATION_FAILED',
        `Review every document first, so the owner sees everything to fix at once: ${names}.`,
      );
    }

    const now = new Date();
    const actorId = new Types.ObjectId(actor.userId);
    const saved = await this.transactions.run(async (session) => {
      const updated = await this.submissions.saveChange(
        submission,
        {
          status: 'REJECTED',
          decidedAt: now,
          decidedBy: actorId,
          ...(input.note ? { decisionNote: input.note } : {}),
          history: [
            ...submission.history,
            {
              at: now,
              action: 'REJECTED',
              byUserId: actorId,
              ...(input.note ? { note: input.note } : {}),
            },
          ],
        },
        session,
        input.note ? [] : ['decisionNote'],
      );
      await this.auditor.record(
        {
          actor,
          action: 'onboarding.rejected',
          entityType: 'onboarding_submission',
          entityId: updated._id,
          operatorId: updated.operatorId,
          before: { status: submission.status },
          after: {
            status: updated.status,
            rejectedDocuments: rejectedDocuments.map((document) => document.documentTypeKey),
          },
          reason: input.note,
          client,
        },
        session,
      );
      await this.outbox.record(
        {
          type: 'onboarding.rejected',
          aggregateType: 'onboarding_submission',
          aggregateId: updated._id.toHexString(),
          payload: {
            ...(await this.eventPayload(updated)),
            note: input.note ?? null,
            rejectedDocuments: rejectedDocuments.map((document) => ({
              key: document.documentTypeKey,
              name: document.documentTypeName,
              reason: document.rejectionReason ?? null,
            })),
          },
        },
        session,
      );
      return updated;
    });
    return this.views.detail(saved);
  }

  private assertAwaitingReview(submission: StoredSubmission): void {
    if (submission.status === 'PENDING') return;
    throw wrongState(
      submission.status === 'DRAFT'
        ? 'The owner has not sent this for review yet.'
        : `This was already decided (${submission.status.toLowerCase()}).`,
    );
  }

  /** Required documents added to the platform's list after the owner sent the submission. */
  private async missingRequired(submission: StoredSubmission): Promise<string[]> {
    const activeTypes =
      snapshotTypes(submission) ?? (await this.documentTypes.activeFor(submission.subjectType));
    return activeTypes
      .filter(
        (type) =>
          type.isRequired &&
          !submission.documents.some((document) => document.documentTypeId.equals(type._id)),
      )
      .map(
        (type) => `"${type.name}" is required now but was not added. Reject so the owner adds it.`,
      );
  }

  /** Makes the company or bus live. Already live is fine; anything else is refused. */
  private async activateSubject(
    submission: StoredSubmission,
    session: Parameters<SubmissionRepository['saveChange']>[2],
  ): Promise<void> {
    if (submission.subjectType === 'OPERATOR') {
      const operator = await this.operators.getById(submission.operatorId.toHexString(), {
        session,
      });
      if (operator.status === 'ACTIVE') return;
      if (operator.status !== 'PENDING_APPROVAL') {
        throw wrongState(`The company is ${operator.status.toLowerCase()} and cannot be approved.`);
      }
      await this.operators.updateOne(
        { _id: operator._id },
        { $set: { status: 'ACTIVE' } },
        { session },
      );
      return;
    }
    const busId = (submission.busId as Types.ObjectId).toHexString();
    const bus = await this.buses.getById(busId, { session });
    if (bus.status === 'ACTIVE') return;
    if (bus.status !== 'PENDING_APPROVAL') {
      throw wrongState(`The bus is ${bus.status.toLowerCase()} and cannot be approved.`);
    }
    await this.buses.updateOne({ _id: bus._id }, { $set: { status: 'ACTIVE' } }, { session });
  }

  /** What the notification engine needs to word a message, so it does no lookups of its own. */
  private async eventPayload(submission: StoredSubmission): Promise<Record<string, unknown>> {
    const operator = await this.operators.getById(submission.operatorId.toHexString());
    const bus = submission.busId
      ? await this.buses.getById(submission.busId.toHexString())
      : undefined;
    return {
      submissionId: submission._id.toHexString(),
      operatorId: submission.operatorId.toHexString(),
      subjectType: submission.subjectType,
      busId: submission.busId?.toHexString() ?? null,
      companyName: operator.displayName ?? operator.companyName,
      busRegistrationNumber: bus?.registrationNumber ?? null,
    };
  }
}
