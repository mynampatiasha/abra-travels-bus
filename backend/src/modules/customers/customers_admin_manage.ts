import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  CUSTOMER_LIST_STATUSES,
  CustomersAdminService,
  SIGN_IN_METHODS,
  type CustomerDetailView,
  type CustomerRowView,
} from './customers_admin_manage.service';

export class CustomerIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class CustomerListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(CUSTOMER_LIST_STATUSES).optional(),
    signInMethod: z.enum(SIGN_IN_METHODS).optional(),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(10),
  }),
) {}

export class UpdateCustomerDto extends createZodDto(
  z
    .object({
      name: z.string().trim().min(1).max(120).optional(),
      email: z.string().trim().toLowerCase().email().max(254).optional(),
    })
    .refine((value) => Object.keys(value).length > 0, 'Send at least one thing to change'),
) {}

export class BlockCustomerDto extends createZodDto(
  z.object({
    reason: z.string().trim().min(1).max(500),
    proofFileIds: z.array(objectIdString).max(5).optional(),
  }),
) {}

/** The admin Customers page: `/admin/customers`. */
@ApiTags('customers')
@Controller('admin/customers')
export class CustomersAdminController {
  constructor(private readonly customers: CustomersAdminService) {}

  @Get()
  @RequirePermission('customers.read')
  @ApiOperation({
    summary: 'List customers',
    description:
      'Requires customers.read. Newest first, with bookings and money spent. Filters: search ' +
      '(name, email, phone), status and signInMethod.',
  })
  list(@Query() query: CustomerListQueryDto): Promise<PaginatedResult<CustomerRowView>> {
    return this.customers.list(query);
  }

  @Get(':id')
  @RequirePermission('customers.read')
  @ApiOperation({
    summary: 'One customer',
    description:
      'Requires customers.read. Profile, why the account is blocked, the latest bookings and ' +
      'the devices that are signed in.',
  })
  get(@Param() params: CustomerIdParamDto): Promise<CustomerDetailView> {
    return this.customers.get(params.id);
  }

  @Patch(':id')
  @RequirePermission('customers.update')
  @ZodApiBody(UpdateCustomerDto)
  @ApiOperation({
    summary: 'Change a customer',
    description: 'Requires customers.update. Name or email. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Body() body: UpdateCustomerDto,
    @Req() request: Request,
  ): Promise<CustomerDetailView> {
    return this.customers.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/block')
  @RequirePermission('customers.update')
  @ZodApiBody(BlockCustomerDto)
  @ApiOperation({
    summary: 'Block a customer',
    description:
      'Requires customers.update. A reason is required; proof files are optional (upload them ' +
      'first, then send their ids). The customer is signed out everywhere. Audited.',
  })
  block(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Body() body: BlockCustomerDto,
    @Req() request: Request,
  ): Promise<CustomerDetailView> {
    return this.customers.block(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/unblock')
  @RequirePermission('customers.update')
  @ApiOperation({
    summary: 'Unblock a customer',
    description: 'Requires customers.update. The customer can sign in again. Audited.',
  })
  unblock(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Req() request: Request,
  ): Promise<CustomerDetailView> {
    return this.customers.unblock(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/sessions/revoke')
  @RequirePermission('customers.update')
  @ApiOperation({
    summary: 'Sign a customer out of all devices',
    description: 'Requires customers.update. They can sign in again at once. Audited.',
  })
  revokeSessions(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Req() request: Request,
  ): Promise<{ signedOut: number }> {
    return this.customers.revokeSessions(actor, params.id, clientRequestInfo(request));
  }

  @Delete(':id')
  @RequirePermission('customers.account.delete')
  @ApiOperation({
    summary: 'Delete a customer',
    description:
      'Requires customers.account.delete. The account leaves every list and cannot sign in; ' +
      '`POST :id/restore` brings it back. Refused while the customer has a booking to travel on. Audited.',
  })
  async remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Req() request: Request,
  ): Promise<{ deleted: true }> {
    await this.customers.remove(actor, params.id, clientRequestInfo(request));
    return { deleted: true };
  }

  @Post(':id/restore')
  @RequirePermission('customers.account.delete')
  @ApiOperation({
    summary: 'Undo the delete of a customer',
    description:
      'Requires customers.account.delete. Not possible when the customer deleted their own ' +
      'account: their personal data is gone. Audited.',
  })
  restore(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CustomerIdParamDto,
    @Req() request: Request,
  ): Promise<CustomerDetailView> {
    return this.customers.restore(actor, params.id, clientRequestInfo(request));
  }
}
