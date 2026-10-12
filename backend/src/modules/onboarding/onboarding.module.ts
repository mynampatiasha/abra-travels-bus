import { ClientKycController, ClientKycService } from './client_kyc';
import {
  KYC_CONFIGURATION_MODEL,
  kycConfigurationMongoSchema,
} from '../system-settings/admin_kyc_configuration';
import {
  DOCUMENT_TYPE_MODEL,
  documentTypeSchema,
} from '../document-types/schemas/document-type.schema';
import { OPERATOR_MODEL, operatorSchema } from '../operators/schemas/operator.schema';
import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { EmailModule } from '../../integrations/email/email.module';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { AuthenticationModule } from '../authentication/authentication.module';
import { BusesModule } from '../buses/buses.module';
import { DocumentTypesModule } from '../document-types/document-types.module';
import { FilesModule } from '../files/files.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { InvitationsController } from './controllers/invitations.controller';
import { SubmissionsController } from './controllers/submissions.controller';
import { InvitationRepository } from './repositories/invitation.repository';
import { SubmissionRepository } from './repositories/submission.repository';
import {
  ONBOARDING_INVITATION_MODEL,
  onboardingInvitationSchema,
} from './schemas/onboarding-invitation.schema';
import {
  ONBOARDING_SUBMISSION_MODEL,
  onboardingSubmissionSchema,
} from './schemas/onboarding-submission.schema';
import { InvitationsService } from './services/invitations.service';
import { OnboardingAuditor } from './services/onboarding-auditor';
import { SubmissionReviewService } from './services/submission-review.service';
import { SubmissionViewService } from './services/submission-view.service';
import { SubmissionsService } from './services/submissions.service';

/**
 * `onboarding` — Supply domain (documentation/architecture.md §5). How a bus owner is checked and
 * approved before anything of theirs can be sold: invitation, document submission per company and
 * per bus, platform review, approval or rejection with reasons (documentation/client-onboarding.md).
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: KYC_CONFIGURATION_MODEL, schema: kycConfigurationMongoSchema },
      { name: DOCUMENT_TYPE_MODEL, schema: documentTypeSchema },
      { name: OPERATOR_MODEL, schema: operatorSchema },
      { name: ONBOARDING_INVITATION_MODEL, schema: onboardingInvitationSchema },
      { name: ONBOARDING_SUBMISSION_MODEL, schema: onboardingSubmissionSchema },
    ]),
    RbacModule,
    AuditLogsModule,
    AuthenticationModule,
    UsersModule,
    OperatorsModule,
    BusesModule,
    DocumentTypesModule,
    FilesModule,
    EmailModule,
  ],
  controllers: [InvitationsController, SubmissionsController, ClientKycController],
  providers: [
    ClientKycService,
    InvitationRepository,
    SubmissionRepository,
    OnboardingAuditor,
    SubmissionViewService,
    SubmissionsService,
    SubmissionReviewService,
    InvitationsService,
  ],
})
export class OnboardingModule {}
