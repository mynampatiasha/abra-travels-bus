import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { MESSAGE_CHANNELS } from './messages_admin_manage.service';
import { type CustomerMessageView, MessagesCustomerService } from './messages_customer.service';

// ===== 1. REQUEST TYPES =============================================================
// The schema of the data lives in messages_admin_manage.service.ts (collection `messages`).

class CustomerMessageListQueryDto extends createZodDto(
  z.object({ channel: z.enum(MESSAGE_CHANNELS).optional(), ...pagingShape }),
) {}

class CustomerMessageIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

// ===== 2. CONTROLLER ================================================================

/** "Messages sent to me" in the customer app. No permission key: the person comes from the token. */
@ApiTags('messages')
@Controller('customer/messages')
@AuthenticatedOnly()
export class MessagesCustomerController {
  constructor(private readonly messages: MessagesCustomerService) {}

  // access: signed-in customer, own messages only | audit: none
  @Get()
  @ApiOperation({
    summary: 'Messages sent to me',
    description:
      'Copies of the WhatsApp messages and emails sent to the signed-in customer, newest first. ' +
      'Paginated. Optional filter: channel.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: CustomerMessageListQueryDto,
  ): Promise<PaginatedResult<CustomerMessageView>> {
    return this.messages.list(actor, query);
  }

  // access: signed-in customer, own messages only | audit: none
  @Get(':id')
  @ApiOperation({ summary: 'One message sent to me' })
  @ApiResponse({ status: 404, description: "RESOURCE_NOT_FOUND (also for someone else's message)" })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerMessageIdParamDto,
  ): Promise<CustomerMessageView> {
    return this.messages.get(actor, params.id);
  }
}
