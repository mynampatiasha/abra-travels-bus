import { Body, Controller, Delete, Get, Patch, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { NOTIFICATION_TOPICS, type NotificationSettings } from './notification_settings';
import {
  CUSTOMER_LANGUAGES,
  CustomersCustomerService,
  type ProfileView,
} from './customers_customer.service';

export class UpdateProfileDto extends createZodDto(
  z
    .object({
      name: z.string().trim().min(1).max(120).optional(),
      email: z.string().trim().toLowerCase().email().max(254).optional(),
      language: z.enum(CUSTOMER_LANGUAGES).optional(),
    })
    .refine((value) => Object.keys(value).length > 0, 'Send at least one thing to change'),
) {}

const channelChoices = z.object({ whatsapp: z.boolean(), email: z.boolean(), push: z.boolean() });

export class NotificationSettingsDto extends createZodDto(
  z.object(
    Object.fromEntries(NOTIFICATION_TOPICS.map((topic) => [topic, channelChoices])) as Record<
      (typeof NOTIFICATION_TOPICS)[number],
      typeof channelChoices
    >,
  ),
) {}

/** The signed-in customer's own profile (`/customer/profile`) and account (`/customer/account`). */
@ApiTags('customer')
@AuthenticatedOnly()
@Controller('customer')
export class CustomersCustomerController {
  constructor(private readonly customer: CustomersCustomerService) {}

  @Get('profile')
  @ApiOperation({
    summary: 'My profile',
    description: 'Name, email, phone (read-only), language and how I sign in.',
  })
  profile(@CurrentActor() actor: AuthenticatedUserActor): Promise<ProfileView> {
    return this.customer.get(actor);
  }

  @Patch('profile')
  @ZodApiBody(UpdateProfileDto)
  @ApiOperation({
    summary: 'Save my profile',
    description:
      'Name, email or language. The email is required and must not belong to another account; ' +
      'a changed email has to be verified again. The phone number cannot be changed here. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: UpdateProfileDto,
    @Req() request: Request,
  ): Promise<ProfileView> {
    return this.customer.update(actor, body, clientRequestInfo(request));
  }

  @Get('notification-settings')
  @ApiOperation({
    summary: 'My notification settings',
    description:
      'For bookings, trips and offers: whether I want it on WhatsApp, email and push. ' +
      'Safety alerts are always sent and are not listed.',
  })
  notificationSettings(@CurrentActor() actor: AuthenticatedUserActor): Promise<NotificationSettings> {
    return this.customer.notificationSettings(actor);
  }

  @Put('notification-settings')
  @ZodApiBody(NotificationSettingsDto)
  @ApiOperation({
    summary: 'Save my notification settings',
    description: 'Send all three kinds with all three channels. The event router reads them before it sends.',
  })
  saveNotificationSettings(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: NotificationSettingsDto,
  ): Promise<NotificationSettings> {
    return this.customer.saveNotificationSettings(actor, body);
  }

  @Delete('account')
  @ApiOperation({
    summary: 'Delete my account',
    description:
      'Removes my personal data and signs me out everywhere; past bookings and payments stay as ' +
      'financial records. Refused while I still have a booking to travel on. Audited.',
  })
  async deleteAccount(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
  ): Promise<{ deleted: true }> {
    await this.customer.deleteAccount(actor, clientRequestInfo(request));
    return { deleted: true };
  }
}
