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
  MAX_MESSAGE_LENGTH,
  SupportAdminService,
  TICKET_CATEGORIES,
  TICKET_PRIORITIES,
  TICKET_STATUSES,
  type TicketDetailView,
  type TicketView,
} from './support_admin_manage.service';

export class TicketIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class TicketListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(TICKET_STATUSES).optional(),
    category: z.enum(TICKET_CATEGORIES).optional(),
    priority: z.enum(TICKET_PRIORITIES).optional(),
    overdue: z.enum(['true', 'false']).transform((value) => value === 'true').optional(),
    mine: z.enum(['true', 'false']).transform((value) => value === 'true').optional(),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(10),
  }),
) {}

export class PriorityDto extends createZodDto(z.object({ priority: z.enum(TICKET_PRIORITIES) })) {}
export class AssignDto extends createZodDto(z.object({ assignToMe: z.boolean() })) {}
export class StaffReplyDto extends createZodDto(z.object({ message: z.string().trim().min(1).max(MAX_MESSAGE_LENGTH) })) {}
export class CannedDto extends createZodDto(
  z.object({ title: z.string().trim().min(1).max(80), body: z.string().trim().min(1).max(MAX_MESSAGE_LENGTH) }),
) {}

/** The admin Support tickets page: `/admin/support`. */
@ApiTags('support')
@Controller('admin/support')
export class SupportAdminController {
  constructor(private readonly support: SupportAdminService) {}

  @Get('tickets')
  @RequirePermission('support.read')
  @ApiOperation({
    summary: 'List support tickets',
    description:
      'Requires support.read. Newest first. Filters: search (number, customer, message, booking number), ' +
      'status, category, priority, overdue (staff have not answered in time), mine (assigned to me).',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: TicketListQueryDto,
  ): Promise<PaginatedResult<TicketView>> {
    return this.support.list(actor, query);
  }

  @Get('canned-replies')
  @RequirePermission('support.read')
  @ApiOperation({ summary: 'Ready-made replies', description: 'Requires support.read.' })
  canned(): Promise<Array<{ id: string; title: string; body: string }>> {
    return this.support.listCanned();
  }

  @Post('canned-replies')
  @RequirePermission('support.manage')
  @ZodApiBody(CannedDto)
  @ApiOperation({ summary: 'Add a ready-made reply', description: 'Requires support.manage. Audited.' })
  addCanned(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CannedDto,
    @Req() request: Request,
  ): Promise<{ id: string; title: string; body: string }> {
    return this.support.addCanned(actor, body, clientRequestInfo(request));
  }

  @Delete('canned-replies/:id')
  @RequirePermission('support.manage')
  @ApiOperation({ summary: 'Remove a ready-made reply', description: 'Requires support.manage. Audited.' })
  async removeCanned(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Req() request: Request,
  ): Promise<{ deleted: true }> {
    await this.support.removeCanned(actor, params.id, clientRequestInfo(request));
    return { deleted: true };
  }

  @Get('tickets/:id')
  @RequirePermission('support.read')
  @ApiOperation({
    summary: 'One ticket',
    description: 'Requires support.read. The customer message, every reply and the proof files.',
  })
  get(@CurrentActor() actor: AuthenticatedUserActor, @Param() params: TicketIdParamDto): Promise<TicketDetailView> {
    return this.support.get(actor, params.id);
  }

  @Patch('tickets/:id')
  @RequirePermission('support.manage')
  @ZodApiBody(PriorityDto)
  @ApiOperation({ summary: 'Set the priority', description: 'Requires support.manage. Audited.' })
  priority(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Body() body: PriorityDto,
    @Req() request: Request,
  ): Promise<TicketDetailView> {
    return this.support.setPriority(actor, params.id, body.priority, clientRequestInfo(request));
  }

  @Post('tickets/:id/assign')
  @RequirePermission('support.manage')
  @ZodApiBody(AssignDto)
  @ApiOperation({
    summary: 'Take a ticket or give it back',
    description: 'Requires support.manage. `assignToMe` true takes it (and starts work); false unassigns. Audited.',
  })
  assign(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Body() body: AssignDto,
    @Req() request: Request,
  ): Promise<TicketDetailView> {
    return this.support.assign(actor, params.id, body.assignToMe, clientRequestInfo(request));
  }

  @Post('tickets/:id/reply')
  @RequirePermission('support.manage')
  @ZodApiBody(StaffReplyDto)
  @ApiOperation({
    summary: 'Reply to the customer',
    description: 'Requires support.manage. Starts work on the ticket and stops the time limit. Audited.',
  })
  reply(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Body() body: StaffReplyDto,
    @Req() request: Request,
  ): Promise<TicketDetailView> {
    return this.support.reply(actor, params.id, body.message, clientRequestInfo(request));
  }

  @Post('tickets/:id/resolve')
  @RequirePermission('support.manage')
  @ApiOperation({ summary: 'Mark a ticket resolved', description: 'Requires support.manage. Audited.' })
  resolve(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Req() request: Request,
  ): Promise<TicketDetailView> {
    return this.support.resolve(actor, params.id, clientRequestInfo(request));
  }

  @Post('tickets/:id/reopen')
  @RequirePermission('support.manage')
  @ApiOperation({
    summary: 'Reopen a resolved ticket',
    description: 'Requires support.manage. Staff have a day to answer again. Audited.',
  })
  reopen(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TicketIdParamDto,
    @Req() request: Request,
  ): Promise<TicketDetailView> {
    return this.support.reopen(actor, params.id, clientRequestInfo(request));
  }
}
