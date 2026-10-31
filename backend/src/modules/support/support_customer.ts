import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { SupportCustomerService } from './support_customer.service';
import {
  MAX_MESSAGE_LENGTH,
  TICKET_CATEGORIES,
  type TicketDetailView,
  type TicketView,
} from './support_admin_manage.service';

export class MyTicketIdDto extends createZodDto(z.object({ id: objectIdString })) {}

export class NewTicketDto extends createZodDto(
  z.object({
    category: z.enum(TICKET_CATEGORIES),
    subject: z.string().trim().max(120).optional(),
    message: z.string().trim().min(1).max(MAX_MESSAGE_LENGTH),
    bookingRef: z.string().trim().max(40).optional(),
    proofFileIds: z.array(objectIdString).max(5).optional(),
  }),
) {}

export class MyReplyDto extends createZodDto(z.object({ message: z.string().trim().min(1).max(MAX_MESSAGE_LENGTH) })) {}

/** The signed-in customer's own tickets (`/customer/support`). */
@ApiTags('customer')
@AuthenticatedOnly()
@Controller('customer/support')
export class SupportCustomerController {
  constructor(private readonly support: SupportCustomerService) {}

  @Post('tickets')
  @ZodApiBody(NewTicketDto)
  @ApiOperation({
    summary: 'Raise a ticket',
    description:
      'Category and message are required. The booking number is kept as text only. Proof files are ' +
      'uploaded first (`POST /files/proofs`), then their ids are sent here.',
  })
  create(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: NewTicketDto): Promise<TicketDetailView> {
    return this.support.create(actor, body);
  }

  @Get('tickets')
  @ApiOperation({ summary: 'My tickets', description: 'Newest first, with their status.' })
  list(@CurrentActor() actor: AuthenticatedUserActor): Promise<TicketView[]> {
    return this.support.list(actor);
  }

  @Get('tickets/:id')
  @ApiOperation({ summary: 'One of my tickets', description: 'My message, the replies and my proof files.' })
  get(@CurrentActor() actor: AuthenticatedUserActor, @Param() params: MyTicketIdDto): Promise<TicketDetailView> {
    return this.support.get(actor, params.id);
  }

  @Post('tickets/:id/replies')
  @ZodApiBody(MyReplyDto)
  @ApiOperation({
    summary: 'Write on my ticket',
    description: 'A message on a resolved ticket opens it again.',
  })
  reply(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: MyTicketIdDto,
    @Body() body: MyReplyDto,
  ): Promise<TicketDetailView> {
    return this.support.reply(actor, params.id, body.message);
  }
}
