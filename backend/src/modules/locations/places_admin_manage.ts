import { Body, Controller, Get, HttpCode, Module, Param, Post, Query, Req } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Schema, type Types } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { escapeRegExp, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { normalizePhoneNumber } from '../../common/validation/contact-identifiers';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { importController } from '../catalogue-shared/catalogue_import_manage';
import {
  type ImportColumn,
  type ImportSpec,
  issueMessage,
  parseNumber,
} from '../catalogue-shared/catalogue_import_manage.service';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { CreateLocationDto, LocationListQueryDto } from './dto/location.dto';
import {
  PLACE_REQUEST_MODEL,
  PLACE_REQUEST_STATUSES,
  type PlaceRequest,
  PlaceRequestNotificationHandler,
  PlaceRequestsAdminService,
  type PlaceRequestView,
} from './places_admin_manage.service';
import {
  PlaceRequestsClientController,
  PlaceRequestsClientExportController,
} from './places_client_manage';
import { PlaceRequestsClientService } from './places_client_manage.service';
import { type PlaceSource, type PlaceUse } from './schemas/location.schema';
import { type LocationView, LocationsService } from './services/locations.service';

/** The words the demo uses for "Used for" and "Added by". */
export const PLACE_USE_LABELS: Readonly<Record<PlaceUse, string>> = {
  BOARDING: 'Boarding only',
  DROPPING: 'Dropping only',
  BOTH: 'Both',
};
export const PLACE_SOURCE_LABELS: Readonly<Record<PlaceSource, string>> = {
  ADMIN: 'Admin',
  IMPORT: 'Import',
  OPERATOR_REQUEST: 'Operator request',
  OPERATOR: 'Operator',
};

/** The places list as a file. */
export const PLACES_EXPORT_KIND: ExportKind<LocationView> = {
  key: 'places',
  references: (places) => ({ City: places.map((place) => place.cityId) }),
  columns: [
    { header: 'Place', value: (place) => place.name },
    { header: 'City', value: (place, names) => names('City', place.cityId) },
    { header: 'Address', value: (place) => place.address },
    { header: 'Landmark', value: (place) => place.landmark },
    { header: 'Used for', value: (place) => PLACE_USE_LABELS[place.usedFor] },
    { header: 'Instructions', value: (place) => place.instructions },
    { header: 'Contact phone', value: (place) => place.contactPhone },
    { header: 'Latitude', value: (place) => place.latitude },
    { header: 'Longitude', value: (place) => place.longitude },
    { header: 'Added by', value: (place) => PLACE_SOURCE_LABELS[place.source] },
    { header: 'Trips using it', value: (place) => place.tripsUsing ?? 0 },
    { header: 'Status', value: (place) => (place.isActive ? 'Active' : 'Inactive') },
  ],
};

/** `GET catalogue/locations/export`. Register it before the module's other controllers. */
export const PlacesExportController = exportController({
  base: 'catalogue/locations',
  permission: 'catalogue.export',
  kind: PLACES_EXPORT_KIND,
  service: LocationsService,
  query: LocationListQueryDto,
  title: 'places',
  load: (service, query) => service.list(query as never),
});

const PLACE_COLUMNS = [
  {
    key: 'name',
    header: 'Place',
    required: true,
    aliases: ['name', 'place name'],
    sample: 'Hyderabad Bus Stand',
  },
  { key: 'city', header: 'City', required: true, sample: 'Hyderabad' },
  { key: 'address', header: 'Address', required: true, sample: '12 Main Road' },
  { key: 'landmark', header: 'Landmark', sample: 'Near the flyover' },
  { key: 'instructions', header: 'Instructions', sample: 'Report 15 minutes early' },
  { key: 'contact_phone', header: 'Contact phone', aliases: ['phone'], sample: '+919876543210' },
  { key: 'latitude', header: 'Latitude', sample: '17.385' },
  { key: 'longitude', header: 'Longitude', sample: '78.4867' },
] as const satisfies readonly ImportColumn[];

const PLACE_HEADERS: Readonly<Record<string, string>> = {
  name: 'Place',
  cityId: 'City',
  address: 'Address',
  landmark: 'Landmark',
  instructions: 'Instructions',
  contactPhone: 'Contact phone',
  latitude: 'Latitude',
  longitude: 'Longitude',
};

/**
 * Importing places: the city is named in the file and must be an active city; a place that exists
 * in that city already (same name), or appears twice in the file, is refused. Places are shared
 * by every operator, as when platform staff add one on the screen.
 */
export const PLACES_IMPORT_SPEC: ImportSpec<CreateLocationDto, LocationsService> = {
  key: 'places',
  columns: PLACE_COLUMNS,
  async begin(context) {
    const cities = await context.connection
      .model<{ name: string; translations?: Map<string, string> | Record<string, string> }>('City')
      .find({ isActive: true })
      .lean<Array<{ _id: Types.ObjectId; name: string }>>()
      .exec();
    context.state.cities = new Map(cities.map((city) => [city.name.trim().toLowerCase(), city]));
    context.state.seen = new Map<string, number>();
  },
  async prepare(raw, context, rowNumber) {
    const label = raw.name || `Row ${rowNumber}`;
    const errors: string[] = [];
    const cities = context.state.cities as Map<string, { _id: Types.ObjectId; name: string }>;
    const city = cities.get((raw.city ?? '').trim().toLowerCase());
    if (!city) {
      errors.push(raw.city ? `City: "${raw.city}" is not an active city.` : 'City: is required.');
    }
    const candidate: Record<string, unknown> = {};
    if (city) candidate.cityId = city._id.toHexString();
    for (const [key, field] of [
      ['name', 'name'],
      ['address', 'address'],
      ['landmark', 'landmark'],
      ['instructions', 'instructions'],
    ] as const) {
      if (raw[key]) candidate[field] = raw[key];
    }
    if (raw.contact_phone) {
      candidate.contactPhone = normalizePhoneNumber(raw.contact_phone) ?? raw.contact_phone;
    }
    for (const [key, field, header] of [
      ['latitude', 'latitude', 'Latitude'],
      ['longitude', 'longitude', 'Longitude'],
    ] as const) {
      const value = parseNumber(raw[key] ?? '');
      if (value === null) errors.push(`${header}: "${raw[key]}" is not a number.`);
      else if (value !== undefined) candidate[field] = value;
    }
    const parsed = CreateLocationDto.zodSchema.safeParse(candidate);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = String(issue.path[0] ?? '');
        if (field === 'cityId' && !city) continue; // already said
        errors.push(`${PLACE_HEADERS[field] ?? field}: ${issueMessage(issue)}`);
      }
    }
    if (
      (candidate.latitude === undefined) !== (candidate.longitude === undefined) &&
      errors.length === 0
    ) {
      errors.push('Latitude and longitude go together: fill in both or neither.');
    }
    if (errors.length > 0 || !parsed.success || !city) return { errors, label };

    const key = `${city._id.toHexString()}|${parsed.data.name.toLowerCase()}`;
    const seen = context.state.seen as Map<string, number>;
    const earlier = seen.get(key);
    if (earlier !== undefined) {
      return { errors: [`The same place appears in row ${earlier}.`], label };
    }
    const existing = await context.connection
      .model('Location')
      .exists({
        cityId: city._id,
        name: new RegExp(`^${escapeRegExp(parsed.data.name)}$`, 'i'),
      })
      .exec();
    if (existing) {
      return { errors: [`A place with this name already exists in ${city.name}.`], label };
    }
    seen.set(key, rowNumber);
    return { dto: parsed.data, label };
  },
  async create(context, actor, dto, client) {
    await context.service.create(actor, dto, client, 'IMPORT');
  },
};

/** `GET catalogue/locations/import-template` and `POST catalogue/locations/import`. Register it first. */
export const PlacesImportController = importController({
  base: 'catalogue/locations',
  permission: 'catalogue.manage',
  spec: PLACES_IMPORT_SPEC,
  service: LocationsService,
  title: 'places',
});

// ===== PLACE REQUESTS (Phase 1 step 5): schema, requests, admin controller, module =====

/** `place_requests`. Never deleted: requests stay for the record. */
export const placeRequestSchema = new Schema<PlaceRequest>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    operatorName: { type: String, required: true, trim: true, maxlength: 200 },
    cityId: { type: Schema.Types.ObjectId, required: true },
    cityName: { type: String, required: true, trim: true, maxlength: 120 },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    address: { type: String, required: true, trim: true, maxlength: 300 },
    landmark: { type: String, trim: true, maxlength: 160 },
    status: { type: String, enum: PLACE_REQUEST_STATUSES, required: true, default: 'PENDING' },
    reason: { type: String, trim: true, maxlength: 500 },
    requestedBy: { type: Schema.Types.ObjectId, required: true },
    decidedBy: { type: Schema.Types.ObjectId },
    decidedAt: { type: Date },
    placeId: { type: Schema.Types.ObjectId },
  },
  { collection: 'place_requests', timestamps: true, versionKey: false },
);
placeRequestSchema.index({ status: 1, createdAt: -1 });
placeRequestSchema.index({ operatorId: 1, createdAt: -1 });

export class PlaceRequestListQueryDto extends createZodDto(
  z.object({
    /** Part of the place, address, landmark, city or operator name. */
    query: z.string().trim().max(100).optional(),
    status: z.enum(PLACE_REQUEST_STATUSES).optional(),
    cityId: objectIdString.optional(),
    operatorId: objectIdString.optional(),
    ...pagingShape,
  }),
) {}

export class PlaceRequestIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class RejectPlaceRequestDto extends createZodDto(
  z.object({ reason: z.string().trim().min(3).max(500) }),
) {}

/** The Operator requests tab as a file. */
export const PLACE_REQUESTS_EXPORT_KIND: ExportKind<PlaceRequestView> = {
  key: 'place_requests',
  columns: [
    { header: 'Requested place', value: (request) => request.name },
    { header: 'Address', value: (request) => request.address },
    { header: 'Landmark', value: (request) => request.landmark },
    { header: 'City', value: (request) => request.cityName },
    { header: 'Operator', value: (request) => request.operatorName },
    { header: 'Requested', value: (request) => timeOf(request.requestedAt) },
    { header: 'Status', value: (request) => readable(request.status) },
    { header: 'Reason', value: (request) => request.reason },
  ],
};

/** `GET admin/place-requests/export`. Registered before the controller below. */
export const PlaceRequestsAdminExportController = exportController({
  base: 'admin/place-requests',
  permission: 'catalogue.export',
  kind: PLACE_REQUESTS_EXPORT_KIND,
  service: PlaceRequestsAdminService,
  query: PlaceRequestListQueryDto,
  title: 'place requests',
  load: (service, query) => service.list(query as never),
});

/** The Operator requests tab of the admin Cities and places page. */
@ApiTags('catalogue')
@Controller('admin/place-requests')
export class PlaceRequestsAdminController {
  constructor(private readonly requests: PlaceRequestsAdminService) {}

  // catalogue.read; read only, no audit
  @Get()
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'List place requests from operators',
    description:
      'Requires catalogue.read. Newest first. Filters: query (place, address, city, operator), ' +
      'status, cityId, operatorId. Paginated.',
  })
  list(@Query() query: PlaceRequestListQueryDto): Promise<PaginatedResult<PlaceRequestView>> {
    return this.requests.list(query);
  }

  // catalogue.read; the number on the tab
  @Get('pending-count')
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'How many place requests wait',
    description: 'Requires catalogue.read.',
  })
  pendingCount(): Promise<{ pending: number }> {
    return this.requests.pendingCount();
  }

  // catalogue.read; read only, no audit
  @Get(':id')
  @RequirePermission('catalogue.read')
  @ApiOperation({ summary: 'One place request', description: 'Requires catalogue.read.' })
  get(@Param() params: PlaceRequestIdParamDto): Promise<PlaceRequestView> {
    return this.requests.get(params.id);
  }

  // catalogue.manage; audit place-request.approved; event place-request.approved tells the operator
  @Post(':id/approve')
  @HttpCode(200)
  @RequirePermission('catalogue.manage')
  @ApiOperation({
    summary: 'Approve a place request',
    description:
      'Requires catalogue.manage (platform staff). Adds the place to the shared list, so every ' +
      'operator can use it ("Added by: Operator request"), and tells the operator. Refused when ' +
      'the request was already decided, the city is switched off, or a place with the same name ' +
      'exists in that city. Audited.',
  })
  approve(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PlaceRequestIdParamDto,
    @Req() request: Request,
  ): Promise<PlaceRequestView> {
    return this.requests.approve(actor, params.id, clientRequestInfo(request));
  }

  // catalogue.manage; audit place-request.rejected with the reason; event tells the operator
  @Post(':id/reject')
  @HttpCode(200)
  @RequirePermission('catalogue.manage')
  @ZodApiBody(RejectPlaceRequestDto)
  @ApiOperation({
    summary: 'Reject a place request',
    description:
      'Requires catalogue.manage (platform staff). The reason is shown to the operator and sent ' +
      'to them. Refused when the request was already decided. Audited.',
  })
  reject(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PlaceRequestIdParamDto,
    @Body() body: RejectPlaceRequestDto,
    @Req() request: Request,
  ): Promise<PlaceRequestView> {
    return this.requests.reject(actor, params.id, body.reason, clientRequestInfo(request));
  }
}

/**
 * Place requests: operators ask for a missing boarding or dropping place (client portal Places
 * page); Abra approves or rejects it (admin Cities and places page, Operator requests tab).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: PLACE_REQUEST_MODEL, schema: placeRequestSchema }]),
    RbacModule,
    UsersModule,
    NotificationsModule,
    CatalogueSharedModule,
  ],
  controllers: [
    PlaceRequestsAdminExportController,
    PlaceRequestsClientExportController,
    PlaceRequestsAdminController,
    PlaceRequestsClientController,
  ],
  providers: [
    PlaceRequestsAdminService,
    PlaceRequestsClientService,
    PlaceRequestNotificationHandler,
  ],
})
export class PlaceRequestsModule {}
