import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { activeFlag, dateRangeShape, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind, readable } from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type AdminPaymentDetail, type AdminPaymentRow, PaymentsAdminService } from './payments_admin_manage.service';
import { PAYMENT_STATUSES } from './payments_customer.service';

export class PaymentListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(PAYMENT_STATUSES).optional(),
    refundDue: activeFlag,
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

/** The columns of the table, in the file. */
export const PAYMENT_EXPORT_KIND: ExportKind<AdminPaymentRow> = {
  key: 'payments',
  columns: [
    { header: 'PNR', value: (row) => row.pnr },
    { header: 'Passenger', value: (row) => row.customerName },
    { header: 'Phone', value: (row) => row.customerPhone },
    { header: 'Gateway', value: (row) => readable(row.gateway) },
    { header: 'Order', value: (row) => row.gatewayOrderId },
    { header: 'Payment', value: (row) => row.gatewayPaymentId },
    { header: 'Amount (Rs)', value: (row) => row.amountPaise / 100 },
    { header: 'Sent back (Rs)', value: (row) => row.refundedPaise / 100 },
    { header: 'Status', value: (row) => readable(row.status) },
    { header: 'Refund due', value: (row) => (row.refundDue ? 'Yes' : 'No') },
    { header: 'Reason', value: (row) => readable(row.failureReason) },
    { header: 'Paid on', value: (row) => (row.paidAt ? new Date(row.paidAt) : null) },
    { header: 'Started on', value: (row) => new Date(row.createdAt) },
  ],
};

/** Registered first: the main controller has `GET :id`, which would take "export" for an id. */
export const PaymentsExportController = exportController({
  base: 'admin/payments',
  permission: 'payments.export',
  kind: PAYMENT_EXPORT_KIND,
  service: PaymentsAdminService,
  query: PaymentListQueryDto,
  title: 'the payments',
  load: (service, query) => service.rows(query as never),
});

@ApiTags('payments')
@Controller('admin/payments')
export class PaymentsAdminController {
  constructor(private readonly payments: PaymentsAdminService) {}

  @Get()
  @RequirePermission('payments.read')
  @ApiOperation({
    summary: 'List payments',
    description:
      'Requires payments.read. Newest first. Filters: search (PNR, passenger, order or payment id), status, ' +
      'refundDue (true: money taken but the seats were lost), from and to.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: PaymentListQueryDto,
  ): Promise<PaginatedResult<AdminPaymentRow>> {
    return this.payments.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('payments.read')
  @ApiOperation({ summary: 'One payment in full', description: 'Requires payments.read. With what was sent back.' })
  get(@CurrentActor() actor: AuthenticatedUserActor, @Param('id') id: string): Promise<AdminPaymentDetail> {
    return this.payments.get(actor, id);
  }
}
