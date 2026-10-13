import { Body, Controller, Get, Module, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import {
  CompanyClientService,
  CompanyNotificationHandler,
  type CompanyView,
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

/** The client portal Company profile page. */
@Module({
  imports: [RbacModule, UsersModule, NotificationsModule],
  controllers: [CompanyClientController],
  providers: [CompanyClientService, CompanyNotificationHandler],
})
export class CompanyClientModule {}
