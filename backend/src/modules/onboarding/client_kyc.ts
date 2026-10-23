import { Body, Controller, Get, Put, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { ApiException } from '../../common/errors/api-exception';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { OPERATOR_MODEL, type Operator } from '../operators/schemas/operator.schema';
import {
  DOCUMENT_TYPE_MODEL,
  type DocumentType,
} from '../document-types/schemas/document-type.schema';
import {
  documentTypeViewOf,
  type DocumentTypeView,
} from '../document-types/services/document-types.service';
import { type StoredDocumentType } from '../document-types/repositories/document-type.repository';
import {
  KYC_CONFIGURATION_MODEL,
  type KycConfiguration,
  type KycAnswers,
  resolveKycRequirements,
} from '../system-settings/admin_kyc_configuration';
import {
  ONBOARDING_SUBMISSION_MODEL,
  type OnboardingSubmission,
} from './schemas/onboarding-submission.schema';

export interface ClientKycSnapshot {
  version: number;
  configuration: KycConfiguration;
  answers: KycAnswers;
  documentCatalogue: DocumentTypeView[];
  requirements: DocumentTypeView[];
  introductionAcceptedAt?: string;
}

export function snapshotTypes(submission: OnboardingSubmission): StoredDocumentType[] | undefined {
  return submission.kyc?.requirements.map((d) => ({ ...d, _id: new Types.ObjectId(d.id) })) as
    StoredDocumentType[] | undefined;
}
export function kycProblems(submission: OnboardingSubmission): string[] {
  if (!submission.kyc)
    return submission.kycRequired ? ['Complete the KYC questions before submitting.'] : [];
  const k = submission.kyc;
  const result = resolveKycRequirements(
    k.configuration,
    k.documentCatalogue,
    submission.subjectType,
    k.answers,
  );
  return [
    ...(!k.introductionAcceptedAt
      ? ['Read the introduction and complete your company details.']
      : []),
    ...result.missingQuestions.map(
      (key) => `Answer "${k.configuration.questions.find((q) => q.key === key)?.label ?? key}".`,
    ),
    ...(k.requirements.length === 0
      ? ['Document requirements have not been configured for your answers. Contact support.']
      : []),
  ];
}

class SaveClientKycDto extends createZodDto(
  z
    .object({
      companyName: z.string().trim().min(2).max(160),
      introductionAccepted: z.literal(true),
      answers: z
        .record(
          z.string().max(40),
          z.union([z.string().max(40), z.array(z.string().max(40)).max(20)]),
        )
        .refine((a) => Object.keys(a).length <= 100),
    })
    .strict(),
) {}

@Injectable()
export class ClientKycService {
  constructor(
    @InjectModel(ONBOARDING_SUBMISSION_MODEL)
    private readonly submissions: Model<OnboardingSubmission>,
    @InjectModel(OPERATOR_MODEL) private readonly operators: Model<Operator>,
    @InjectModel(DOCUMENT_TYPE_MODEL) private readonly documents: Model<DocumentType>,
    @InjectModel(KYC_CONFIGURATION_MODEL)
    private readonly configurations: Model<KycConfiguration & { version: number }>,
    private readonly transactions: TransactionRunner,
  ) {}
  private operatorId(actor: AuthenticatedUserActor) {
    if (actor.userType !== 'OPERATOR_STAFF' || !actor.operatorId)
      throw new ApiException('PERMISSION_DENIED', 'A client account is required.');
    return new Types.ObjectId(actor.operatorId);
  }
  async describe(actor: AuthenticatedUserActor) {
    const operatorId = this.operatorId(actor);
    const company = await this.operators.findById(operatorId).lean();
    if (!company) throw new ApiException('RESOURCE_NOT_FOUND', 'Company not found.');
    let submission = await this.submissions.findOne({ operatorId, subjectType: 'OPERATOR' }).lean();
    if (!submission)
      throw new ApiException('RESOURCE_NOT_FOUND', 'Company verification file not found.');
    // Until the first submit, a draft follows the admin's latest questions, rules and document
    // types (keeping the owner's answers), so an owner who signed up before the admin finished
    // the setup is not stuck with an empty snapshot. Once submitted, the snapshot stays fixed.
    if (submission.status === 'DRAFT') {
      const [config, documents] = await Promise.all([
        this.configurations.findOne().lean(),
        this.documents.find().lean<StoredDocumentType[]>(),
      ]);
      const configuration: KycConfiguration = {
        schemaVersion: 1,
        questions: config?.questions ?? [],
        rules: config?.rules ?? [],
      };
      const documentCatalogue = documents.map(documentTypeViewOf);
      const version = config?.version ?? 0;
      const current = submission.kyc;
      const outdated =
        !current ||
        current.version !== version ||
        JSON.stringify(current.configuration) !== JSON.stringify(configuration) ||
        JSON.stringify(current.documentCatalogue) !== JSON.stringify(documentCatalogue);
      if (outdated) {
        const answers = current?.answers ?? {};
        const kyc: ClientKycSnapshot = {
          version,
          configuration,
          answers,
          documentCatalogue,
          requirements: resolveKycRequirements(
            configuration,
            documentCatalogue,
            'OPERATOR',
            answers,
          ).documents,
          ...(current?.introductionAcceptedAt
            ? { introductionAcceptedAt: current.introductionAcceptedAt }
            : {}),
        };
        await this.submissions.updateOne(
          current
            ? { _id: submission._id, status: 'DRAFT', 'kyc.version': current.version }
            : { _id: submission._id, status: 'DRAFT', kyc: { $exists: false } },
          { $set: { kyc } },
        );
        submission = await this.submissions.findById(submission._id).lean();
        if (!submission)
          throw new ApiException('RESOURCE_NOT_FOUND', 'Verification file not found.');
      }
    }
    return {
      companyName: company.companyName,
      companyStatus: company.status,
      submissionId: submission._id.toHexString(),
      status: submission.status,
      kyc: submission.kyc ?? null,
      problems: kycProblems(submission),
      approved: company.status === 'ACTIVE',
    };
  }
  async save(actor: AuthenticatedUserActor, input: SaveClientKycDto) {
    const operatorId = this.operatorId(actor);
    await this.describe(actor);
    await this.transactions.run(async (session) => {
      const submission = await this.submissions
        .findOne({ operatorId, subjectType: 'OPERATOR' })
        .session(session)
        .lean();
      if (!submission?.kyc || !['DRAFT', 'REJECTED'].includes(submission.status))
        throw new ApiException(
          'INVALID_STATE_TRANSITION',
          'This verification file cannot be edited.',
        );
      // Do not alter accepted answers/documents after a reviewer has accepted any document.
      if (
        submission.status === 'REJECTED' &&
        JSON.stringify(input.answers) !== JSON.stringify(submission.kyc.answers)
      )
        throw new ApiException(
          'INVALID_STATE_TRANSITION',
          'Keep your submitted answers while correcting rejected documents.',
        );
      const kyc = submission.kyc;
      // Keep the initial requirements snapshot stable throughout this review.
      const result = resolveKycRequirements(
        kyc.configuration,
        kyc.documentCatalogue,
        'OPERATOR',
        input.answers,
      );
      if (result.missingQuestions.length)
        throw new ApiException('VALIDATION_FAILED', 'Answer all required questions.');
      if (!result.documents.length)
        throw new ApiException(
          'VALIDATION_FAILED',
          'The admin must configure document requirements before you can submit.',
        );
      kyc.answers = input.answers;
      kyc.requirements = result.documents;
      kyc.introductionAcceptedAt ??= new Date().toISOString();
      await this.submissions.updateOne(
        { _id: submission._id, status: submission.status },
        { $set: { kyc } },
        { session },
      );
      await this.operators.updateOne(
        { _id: operatorId, status: 'PENDING_APPROVAL' },
        { $set: { companyName: input.companyName } },
        { session },
      );
    });
    return this.describe(actor);
  }
}

@Controller('client/kyc')
@AuthenticatedOnly()
export class ClientKycController {
  constructor(private readonly service: ClientKycService) {}
  @Get() get(@CurrentActor() actor: AuthenticatedUserActor) {
    return this.service.describe(actor);
  }
  @Put() save(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: SaveClientKycDto) {
    return this.service.save(actor, body);
  }
}
