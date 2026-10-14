import { Body, Controller, Get, Module, Param, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import {
  BusKycClientService,
  type BusKycView,
  CompanyClientService,
  CompanyNotificationHandler,
  type CompanyView,
  type KycHistoryEntryView,
  KycHistoryService,
} from './kyc_client_manage.service';

// ===== 1. REQUESTS =====

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .transform((value) => (value === '' ? undefined : value));

export class CompanyProfileDto extends createZodDto(
  z.object({
    companyName: z.string().trim().min(2).max(160),
    ownerName: z.string().trim().min(2).max(120),
    email: z.string().trim().toLowerCase().email().max(254),
    supportPhone: optionalText(20),
    city: optionalText(80),
    /** 15 characters, e.g. 36ABCDE1234F1Z5. */
    gstin: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/, 'Enter a GSTIN like 36ABCDE1234F1Z5')
      .optional()
      .or(z.literal('').transform(() => undefined)),
  }),
) {}

export class CompanyBankDto extends createZodDto(
  z.object({
    holderName: z.string().trim().min(2).max(120),
    /** 6 to 18 digits. */
    accountNumber: z
      .string()
      .trim()
      .regex(/^\d{6,18}$/, 'Enter 6 to 18 digits'),
    /** For example HDFC0001234. */
    ifsc: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'Looks wrong, for example HDFC0001234'),
  }),
) {}

// ===== 2. CONTROLLER =====

/** The Company profile page of the client portal (#/company). */
@ApiTags('client portal')
@Controller('client/company')
export class CompanyClientController {
  constructor(private readonly company: CompanyClientService) {}

  // operators.read; operator staff only; their own company
  @Get()
  @RequirePermission('operators.read')
  @ApiOperation({
    summary: 'My company profile and bank account',
    description:
      'Requires operators.read, operator staff only. The company details, the payout mode set ' +
      'by Abra, and the bank account with its verification status. The account number is shown ' +
      'as its last four digits only.',
  })
  get(@CurrentActor() actor: AuthenticatedUserActor): Promise<CompanyView> {
    return this.company.get(actor);
  }

  // operators.update; audit operator.profile-updated
  @Put()
  @RequirePermission('operators.update')
  @ZodApiBody(CompanyProfileDto)
  @ApiOperation({
    summary: 'Save the company profile',
    description:
      'Requires operators.update, operator staff only. Company name, owner name and email are ' +
      'required; support phone, city and GSTIN are optional. Audited.',
  })
  save(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CompanyProfileDto,
    @Req() request: Request,
  ): Promise<CompanyView> {
    return this.company.updateProfile(actor, body, clientRequestInfo(request));
  }

  // operators.update; audit operator.bank-changed (last four digits only); Abra staff are told
  @Put('bank')
  @RequirePermission('operators.update')
  @ZodApiBody(CompanyBankDto)
  @ApiOperation({
    summary: 'Save the bank account for payouts',
    description:
      'Requires operators.update, operator staff only. The number is stored encrypted and is ' +
      'never returned. The account goes back to PENDING and automatic payouts to manual until ' +
      'Abra verifies it; Abra staff are told. Audited.',
  })
  saveBank(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CompanyBankDto,
    @Req() request: Request,
  ): Promise<CompanyView> {
    return this.company.saveBank(actor, body, clientRequestInfo(request));
  }
}

// ===== 3. BUS KYC AND HISTORY (Phase 1 step 9) =====

export class BusKycParamDto extends createZodDto(z.object({ busId: objectIdString })) {}

export class KycFileParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class SaveBusKycDto extends createZodDto(
  z
    .object({
      answers: z
        .record(
          z.string().max(40),
          z.union([z.string().max(40), z.array(z.string().max(40)).max(20)]),
        )
        .refine((answers) => Object.keys(answers).length <= 100, 'Too many answers'),
    })
    .strict(),
) {}

/** The bus KYC wizard of the client portal: the bus questions, before its documents. */
@ApiTags('client portal')
@Controller('client/kyc/buses')
export class BusKycClientController {
  constructor(private readonly buses: BusKycClientService) {}

  // documents.read; operator staff only; own buses; the company must be approved
  @Get(':busId')
  @RequirePermission('documents.read')
  @ApiOperation({
    summary: 'The KYC file of one of my buses',
    description:
      'Requires documents.read, operator staff of an approved company. Makes the bus file the ' +
      'first time (with the bus questions Abra set, if any). hasQuestions says whether the ' +
      'wizard starts with questions; documents, submit and corrections use ' +
      '/onboarding/submissions/:submissionId.',
  })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusKycParamDto,
  ): Promise<BusKycView> {
    return this.buses.describe(actor, params.busId);
  }

  // documents.upload; operator staff only; while DRAFT, or REJECTED with the same answers
  @Put(':busId')
  @RequirePermission('documents.upload')
  @ZodApiBody(SaveBusKycDto)
  @ApiOperation({
    summary: 'Answer the bus questions',
    description:
      'Requires documents.upload, operator staff of an approved company. The answers decide ' +
      'which documents the bus needs. After a rejection the answers cannot change; only the ' +
      'rejected documents can be replaced.',
  })
  save(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusKycParamDto,
    @Body() body: SaveBusKycDto,
  ): Promise<BusKycView> {
    return this.buses.saveAnswers(actor, params.busId, body.answers);
  }
}

/** The History of a KYC file: the admin "History" button and the client waiting screen. */
@ApiTags('onboarding')
@Controller('onboarding/submissions')
export class KycHistoryController {
  constructor(private readonly histories: KycHistoryService) {}

  // documents.read; staff see every file, operator staff only their own; read only
  @Get(':id/history')
  @RequirePermission('documents.read')
  @ApiOperation({
    summary: 'History of a KYC file',
    description:
      'Requires documents.read. Every step of a company or bus file, oldest first: started, ' +
      'submitted, each document accepted or rejected, corrections sent, the decision. Operator ' +
      'staff see their own files only (others are 404) and see Abra staff as "Abra Travels".',
  })
  history(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: KycFileParamDto,
  ): Promise<KycHistoryEntryView[]> {
    return this.histories.history(actor, params.id);
  }
}

/** The client portal Company profile page, bus KYC, and the KYC history. */
@Module({
  imports: [RbacModule, UsersModule, NotificationsModule],
  controllers: [CompanyClientController, BusKycClientController, KycHistoryController],
  providers: [
    CompanyClientService,
    CompanyNotificationHandler,
    BusKycClientService,
    KycHistoryService,
  ],
})
export class CompanyClientModule {}
