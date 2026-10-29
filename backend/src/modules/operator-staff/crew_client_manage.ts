import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  Module,
  forwardRef,
} from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Schema } from 'mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { AppConfigService } from '../../config/app-config.service';
import { createFileStorage } from '../files/files.module';
import { FILE_STORAGE } from '../files/storage/file-storage';
import { USER_MODEL, userSchema } from '../users/schemas/user.schema';
import { AuthenticationModule } from '../authentication/authentication.module';
import { SessionsModule } from '../sessions/sessions.module';
import { UsersModule } from '../users/users.module';
import { CrewDocumentsClientController } from './crew_documents_client_manage';
import { CrewLoginClientController } from './crew_login_client_manage';
import { CrewLoginClientManageService } from './crew_login_client_manage.service';
import {
  CREW_DOCUMENT_MODEL,
  CREW_REMINDER_MODEL,
  CrewDocumentSchema,
  CrewDocumentsClientManageService,
  CrewReminderSchema,
} from './crew_documents_client_manage.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type ClientCrewKpis,
  type ClientCrewView,
  CrewClientManageService,
  CREW_ROLES,
  CREW_STATUSES,
} from './crew_client_manage.service';

export const OperatorCrewSchema = new Schema(
  {
    operatorId: { type: Schema.Types.ObjectId, ref: 'operators', required: true, index: true },
    name: { type: String, required: true, trim: true },
    role: { type: String, enum: CREW_ROLES, required: true, default: 'DRIVER', index: true },
    phone: { type: String, required: true, trim: true, index: true },
    licenseNumber: { type: String, trim: true },
    licenseExpiryDate: { type: Date },
    badgeNumber: { type: String, trim: true },
    status: { type: String, enum: CREW_STATUSES, required: true, default: 'ACTIVE', index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'users' },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date },
  },
  {
    timestamps: true,
    collection: 'operator_crew',
  },
);

OperatorCrewSchema.index({ operatorId: 1, phone: 1 }, { unique: true, partialFilterExpression: { isDeleted: false } });
OperatorCrewSchema.index({ operatorId: 1, role: 1 });
OperatorCrewSchema.index({ operatorId: 1, status: 1 });
OperatorCrewSchema.index({ operatorId: 1, licenseExpiryDate: 1 });

export const ClientCreateCrewSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  role: z.enum(CREW_ROLES).default('DRIVER'),
  phone: z.string().min(7, 'Phone number must be at least 7 characters').max(20),
  licenseNumber: z.string().max(50).optional(),
  licenseExpiryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date format (YYYY-MM-DD)').optional(),
  badgeNumber: z.string().max(50).optional(),
  status: z.enum(CREW_STATUSES).default('ACTIVE'),
});

export const ClientUpdateCrewSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  role: z.enum(CREW_ROLES).optional(),
  phone: z.string().min(7).max(20).optional(),
  licenseNumber: z.string().max(50).optional(),
  licenseExpiryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date format (YYYY-MM-DD)').optional(),
  badgeNumber: z.string().max(50).optional(),
  status: z.enum(CREW_STATUSES).optional(),
});

export const ClientUpdateCrewStatusSchema = z.object({
  status: z.enum(CREW_STATUSES),
});

export const ClientCrewListQuerySchema = z.object({
  role: z.string().optional(),
  status: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(20),
});

export class ClientCreateCrewDto extends createZodDto(ClientCreateCrewSchema) {}
export class ClientUpdateCrewDto extends createZodDto(ClientUpdateCrewSchema) {}
export class ClientUpdateCrewStatusDto extends createZodDto(ClientUpdateCrewStatusSchema) {}
export class ClientCrewListQueryDto extends createZodDto(ClientCrewListQuerySchema) {}
export class ClientCrewIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const CLIENT_CREW_EXPORT_KIND: ExportKind<ClientCrewView> = {
  key: 'my_crew',
  columns: [
    { header: 'Name', value: (c) => c.name },
    { header: 'Role', value: (c) => c.role },
    { header: 'Phone', value: (c) => c.phone },
    { header: 'License Number', value: (c) => c.licenseNumber ?? '-' },
    { header: 'License Expiry', value: (c) => (c.licenseExpiryDate ? timeOf(c.licenseExpiryDate) : '-') },
    { header: 'Badge Number', value: (c) => c.badgeNumber ?? '-' },
    { header: 'Status', value: (c) => readable(c.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const CrewClientExportController = exportController({
  base: 'client/crew',
  permission: 'buses.read',
  kind: CLIENT_CREW_EXPORT_KIND,
  service: CrewClientManageService,
  query: ClientCrewListQueryDto,
  title: 'my crew',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Client Crew')
@Controller('client/crew')
export class CrewClientManageController {
  constructor(
    private readonly service: CrewClientManageService,
    private readonly documents: CrewDocumentsClientManageService,
    private readonly logins: CrewLoginClientManageService,
  ) {}

  @Get('kpis')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get crew KPIs for operator dashboard' })
  kpis(@CurrentActor() actor: AuthenticatedUserActor): Promise<ClientCrewKpis> {
    return this.service.kpis(actor);
  }

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'List operator crew with pagination and filters' })
  async list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientCrewListQueryDto,
  ): Promise<PaginatedResult<ClientCrewView> & { kpis: ClientCrewKpis }> {
    const result = await this.service.list(actor, query);
    // How many documents each person has, and how many are expiring or expired
    const counts = await this.documents.countsFor(actor, result.items.map((person) => person.id));
    // Whether each person can sign in to the driver app
    const loginStates = await this.logins.statesFor(actor, result.items.map((person) => person.id));
    for (const person of result.items) {
      Object.assign(
        person,
        counts.get(person.id) ?? { documentsCount: 0, documentsExpiring: 0, documentsExpired: 0 },
        { loginState: loginStates.get(person.id) ?? 'NONE' },
      );
    }
    return result;
  }

  @Get(':id')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get single crew member details' })
  findById(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() param: ClientCrewIdParamDto,
  ): Promise<ClientCrewView> {
    return this.service.findById(actor, param.id);
  }

  @Post()
  @RequirePermission('buses.create')
  @ApiOperation({ summary: 'Create a new crew member' })
  @ZodApiBody(ClientCreateCrewDto)
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() dto: ClientCreateCrewDto,
    @Req() req: Request,
  ): Promise<ClientCrewView> {
    return this.service.create(actor, dto, clientRequestInfo(req));
  }

  @Put(':id')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Update crew member' })
  @ZodApiBody(ClientUpdateCrewDto)
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() param: ClientCrewIdParamDto,
    @Body() dto: ClientUpdateCrewDto,
    @Req() req: Request,
  ): Promise<ClientCrewView> {
    return this.service.update(actor, param.id, dto, clientRequestInfo(req));
  }

  @Patch(':id/status')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Change crew status (active, on-leave, inactive)' })
  @ZodApiBody(ClientUpdateCrewStatusDto)
  updateStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() param: ClientCrewIdParamDto,
    @Body() dto: ClientUpdateCrewStatusDto,
  ): Promise<ClientCrewView> {
    return this.service.updateStatus(actor, param.id, dto.status);
  }

  @Delete(':id')
  @RequirePermission('buses.delete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Soft delete crew member' })
  async delete(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() param: ClientCrewIdParamDto,
    @Req() req: Request,
  ): Promise<{ success: boolean; id: string }> {
    const result = await this.service.delete(actor, param.id, clientRequestInfo(req));
    // A person removed from the list can no longer sign in to the driver app
    await this.logins.switchOffForRemoved(actor, param.id);
    return result;
  }
}

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: 'operator_crew', schema: OperatorCrewSchema },
      { name: 'trips', schema: new Schema({}, { strict: false }) },
      { name: CREW_DOCUMENT_MODEL, schema: CrewDocumentSchema },
      { name: CREW_REMINDER_MODEL, schema: CrewReminderSchema },
      { name: USER_MODEL, schema: userSchema },
    ]),
    forwardRef(() => RbacModule),
    CatalogueSharedModule,
    UsersModule,
    SessionsModule,
    AuthenticationModule,
  ],
  controllers: [
    CrewClientExportController,
    CrewDocumentsClientController,
    CrewLoginClientController,
    CrewClientManageController,
  ],
  providers: [
    CrewClientManageService,
    CrewDocumentsClientManageService,
    CrewLoginClientManageService,
    { provide: FILE_STORAGE, inject: [AppConfigService], useFactory: createFileStorage },
  ],
  exports: [CrewClientManageService, CrewDocumentsClientManageService],
})
export class OperatorStaffModule {}
