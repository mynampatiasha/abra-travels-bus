import { Controller, Get, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { dateRangeShape, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind, readable } from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type AdminBookingDetail, type AdminBookingRow, BookingsAdminService } from './bookings_admin_manage.service';
import { BOOKING_STATUSES } from './bookings_customer.service';

export class BookingListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(BOOKING_STATUSES).optional(),
    operatorId: objectIdString.optional(),
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

const rupees = (paise: number) => paise / 100;

/** The columns of the table, in the file. */
export const BOOKING_EXPORT_KIND: ExportKind<AdminBookingRow> = {
  key: 'bookings',
  columns: [
    { header: 'PNR', value: (row) => row.pnr },
    { header: 'Status', value: (row) => readable(row.status) },
    { header: 'Passenger', value: (row) => row.customerName },
    { header: 'Phone', value: (row) => row.customerPhone },
    { header: 'Email', value: (row) => row.customerEmail },
    { header: 'Route', value: (row) => row.route },
    { header: 'Operator', value: (row) => row.operatorName },
    { header: 'Departure', value: (row) => (row.departureAt ? new Date(row.departureAt) : null) },
    { header: 'Seats', value: (row) => row.seats },
    { header: 'Amount (Rs)', value: (row) => rupees(row.amountPaise) },
    { header: 'Payment', value: (row) => readable(row.paymentStatus) },
    { header: 'Booked on', value: (row) => new Date(row.createdAt) },
  ],
};

/** Registered first: the main controller has `GET :id`, which would take "export" for an id. */
export const BookingsExportController = exportController({
  base: 'admin/bookings',
  permission: 'bookings.export',
  kind: BOOKING_EXPORT_KIND,
  service: BookingsAdminService,
  query: BookingListQueryDto,
  title: 'the bookings',
  load: (service, query) => service.rows(query as never),
});

@ApiTags('bookings')
@Controller('admin/bookings')
export class BookingsAdminController {
  constructor(private readonly bookings: BookingsAdminService) {}

  @Get()
  @RequirePermission('bookings.read')
  @ApiOperation({
    summary: 'List bookings',
    description:
      'Requires bookings.read. Newest first. Filters: search (PNR, passenger name, phone, email), status, ' +
      'operatorId, from and to (the day it was booked).',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: BookingListQueryDto,
  ): Promise<PaginatedResult<AdminBookingRow>> {
    return this.bookings.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('bookings.read')
  @ApiOperation({ summary: 'One booking in full', description: 'Requires bookings.read. Passengers, amounts, points and payments.' })
  get(@CurrentActor() actor: AuthenticatedUserActor, @Param('id') id: string): Promise<AdminBookingDetail> {
    return this.bookings.get(actor, id);
  }

  @Post(':id/resend-ticket')
  @HttpCode(200)
  @RequirePermission('bookings.update')
  @ApiOperation({
    summary: 'Send the ticket message again',
    description: 'Requires bookings.update. Only for a paid booking. Queues the confirmation WhatsApp and email again. Audited.',
  })
  resend(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('id') id: string,
    @Req() request: Request,
  ): Promise<{ queued: true }> {
    return this.bookings.resendTicket(actor, id, clientRequestInfo(request));
  }
}
