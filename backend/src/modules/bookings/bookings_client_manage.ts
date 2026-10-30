import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { BookingListQueryDto } from './bookings_admin_manage';
import {
  type AdminBookingDetail,
  type AdminBookingRow,
  BookingsAdminService,
  type OperatorBookingSummary,
} from './bookings_admin_manage.service';

/** The operator's own bookings in the client portal. Never another operator's. */
@ApiTags('bookings')
@Controller('client/bookings')
export class BookingsClientController {
  constructor(private readonly bookings: BookingsAdminService) {}

  @Get()
  @RequirePermission('bookings.read')
  @ApiOperation({
    summary: 'My company bookings',
    description:
      'Requires bookings.read and an operator account. Only bookings of the caller operator, newest first. ' +
      'Filters: search (PNR, passenger, phone, email), status, from and to.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: BookingListQueryDto,
  ): Promise<PaginatedResult<AdminBookingRow>> {
    return this.bookings.listForOperator(actor, query);
  }

  @Get('summary')
  @RequirePermission('bookings.read')
  @ApiOperation({
    summary: 'The numbers on top of the bookings page',
    description: 'Requires bookings.read and an operator account. Bookings, confirmed, cancelled, and the amount of the confirmed ones.',
  })
  summary(@CurrentActor() actor: AuthenticatedUserActor): Promise<OperatorBookingSummary> {
    return this.bookings.summaryForOperator(actor);
  }

  @Get(':id')
  @RequirePermission('bookings.read')
  @ApiOperation({
    summary: 'One of my company bookings',
    description: 'Requires bookings.read and an operator account. A booking of another operator answers 404.',
  })
  get(@CurrentActor() actor: AuthenticatedUserActor, @Param('id') id: string): Promise<AdminBookingDetail> {
    return this.bookings.getForOperator(actor, id);
  }
}
