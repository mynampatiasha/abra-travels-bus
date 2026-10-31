import { Controller, Get, Param, Res, StreamableFile } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type TicketView, TicketsCustomerService } from './tickets_customer.service';

/** The e-ticket of a confirmed booking. */
@ApiTags('tickets')
@AuthenticatedOnly()
@Controller('bookings')
export class TicketsCustomerController {
  constructor(private readonly tickets: TicketsCustomerService) {}

  @Get(':bookingId/ticket')
  @ApiOperation({
    summary: 'The ticket of a booking',
    description:
      'Customer. Only the owner, and only once the payment is done (otherwise INVALID_STATE_TRANSITION). ' +
      'Gives the trip, the passengers with their seats, the boarding and dropping points, what was ' +
      'paid, and qrPayload: the signed text for the conductor scanner.',
  })
  @ApiResponse({ status: 200, description: 'The ticket' })
  ticket(@CurrentActor() actor: AuthenticatedUserActor, @Param('bookingId') bookingId: string): Promise<TicketView> {
    return this.tickets.ticket(actor, bookingId);
  }

  @Get(':bookingId/ticket/pdf')
  @ApiOperation({
    summary: 'The ticket as a PDF',
    description:
      'Customer. Same rules as the ticket (the owner, after payment). A PDF with the Abra logo, the trip, the passengers, the ' +
      'QR for boarding, what was paid, the cancellation policy of this booking and the terms.',
  })
  @ApiResponse({ status: 200, description: 'application/pdf' })
  async pdf(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('bookingId') bookingId: string,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const file = await this.tickets.pdf(actor, bookingId);
    response.setHeader('Content-Disposition', `attachment; filename="${file.fileName}"`);
    response.setHeader('Cache-Control', 'no-store');
    return new StreamableFile(file.body, { type: 'application/pdf' });
  }
}
