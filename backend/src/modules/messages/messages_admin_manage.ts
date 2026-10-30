import { Controller, Get, HttpCode, Module, Param, Post, Query, Req } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { dateRangeShape, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { EmailModule } from '../../integrations/email/email.module';
import { SmsModule } from '../../integrations/sms/sms.module';
import { WhatsAppModule } from '../../integrations/whatsapp/whatsapp.module';
import { AuthenticationModule } from '../authentication/authentication.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { MessagesCustomerController } from './messages_customer';
import { MessagesCustomerService } from './messages_customer.service';
import {
  MESSAGE_CHANNELS,
  MESSAGE_KINDS,
  MESSAGE_MODEL,
  MESSAGE_STATUSES,
  MessageSenderService,
  type MessageView,
  MessagesAdminManageService,
  messageSchema,
} from './messages_admin_manage.service';

// ===== 2. REQUEST TYPES =============================================================

export class MessageListQueryDto extends createZodDto(
  z.object({
    q: z.string().trim().max(100).optional(),
    channel: z.enum(MESSAGE_CHANNELS).optional(),
    kind: z.enum(MESSAGE_KINDS).optional(),
    status: z.enum(MESSAGE_STATUSES).optional(),
    bookingId: objectIdString.optional(),
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

export class MessageIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

// ===== 3. CONTROLLER ================================================================

/** The admin "Messages sent" page. */
@ApiTags('messages')
@Controller('admin/messages')
export class MessagesAdminManageController {
  constructor(private readonly messages: MessagesAdminManageService) {}

  // permission: messages.read | audit: none | notifies: nobody
  @Get()
  @RequirePermission('messages.read')
  @ApiOperation({
    summary: 'Messages sent',
    description:
      'Requires messages.read. Every WhatsApp message, SMS and email, newest first. Filters: channel, ' +
      'kind, status, booking, day range and a search over name, address and subject. Paginated.',
  })
  list(@Query() query: MessageListQueryDto): Promise<PaginatedResult<MessageView>> {
    return this.messages.list(query);
  }

  // permission: messages.read | audit: none | notifies: nobody
  @Get(':id')
  @RequirePermission('messages.read')
  @ApiOperation({ summary: 'One message with its full text and delivery status' })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  get(@Param() params: MessageIdParamDto): Promise<MessageView> {
    return this.messages.get(params.id);
  }

  // permission: messages.resend | audit: message.resent | notifies: the recipient, by the same channel
  @Post(':id/resend')
  @HttpCode(200)
  @RequirePermission('messages.resend')
  @ApiOperation({
    summary: 'Send a message again',
    description:
      'Requires messages.resend. Tries the same channel again and writes an audit entry.',
  })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  resend(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: MessageIdParamDto,
    @Req() request: Request,
  ): Promise<MessageView> {
    return this.messages.resend(actor, params.id, clientRequestInfo(request));
  }
}

// ===== 4. MODULE ====================================================================

/**
 * `messages`: the log of WhatsApp messages and emails. Other features inject
 * `MessageSenderService` to tell a customer something (booking confirmed, refund paid, ...).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: MESSAGE_MODEL, schema: messageSchema }]),
    EmailModule,
    SmsModule,
    WhatsAppModule,
    RbacModule,
    AuthenticationModule,
  ],
  controllers: [MessagesAdminManageController, MessagesCustomerController],
  providers: [MessageSenderService, MessagesAdminManageService, MessagesCustomerService],
  exports: [MessageSenderService],
})
export class MessagesModule {}
