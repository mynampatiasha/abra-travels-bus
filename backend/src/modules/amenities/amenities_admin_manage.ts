import { Body, Controller, Get, Module, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Schema } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { activeFlag, objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import {
  AMENITY_KEY_PATTERN,
  AMENITY_MODEL,
  type Amenity,
  type AmenityChoice,
  AmenitiesService,
  type AmenityView,
} from './amenities_admin_manage.service';

/** `amenities`. Switched off, never deleted: buses refer to the key. */
export const amenitySchema = new Schema<Amenity>(
  {
    key: { type: String, required: true, match: AMENITY_KEY_PATTERN },
    name: { type: String, required: true, trim: true, minlength: 2, maxlength: 60 },
    isActive: { type: Boolean, required: true, default: true },
    sortOrder: { type: Number, required: true, default: 0 },
  },
  { collection: 'amenities', timestamps: true, versionKey: false },
);
amenitySchema.index({ key: 1 }, { unique: true });
amenitySchema.index({ isActive: 1, sortOrder: 1 });

export class CreateAmenityDto extends createZodDto(
  z.object({ name: z.string().trim().min(2).max(60) }),
) {}

export class SetAmenityActiveDto extends createZodDto(z.object({ active: z.boolean() })) {}

export class AmenityIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

/** The amenity list is short: one page of up to 100 is the default. */
export class AmenityListQueryDto extends createZodDto(
  z.object({
    active: activeFlag,
    page: z.coerce.number().int().min(1).max(100).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(100),
  }),
) {}

/** The amenities list of the Bus types page. */
@ApiTags('catalogue')
@Controller('admin/amenities')
export class AmenitiesAdminController {
  constructor(private readonly amenities: AmenitiesService) {}

  @Get()
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'List amenities',
    description:
      'Requires catalogue.read. Every amenity, switched off ones included (`active` filters).',
  })
  list(@Query() query: AmenityListQueryDto): Promise<PaginatedResult<AmenityView>> {
    return this.amenities.list(query);
  }

  @Post()
  @RequirePermission('catalogue.manage')
  @ZodApiBody(CreateAmenityDto)
  @ApiOperation({
    summary: 'Add an amenity',
    description:
      'Requires catalogue.manage. The key is made from the name ("Charging point" is ' +
      'CHARGING_POINT) and cannot change; a name that makes an existing key is ALREADY_REGISTERED. ' +
      'The amenity starts switched on. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateAmenityDto,
    @Req() request: Request,
  ): Promise<AmenityView> {
    return this.amenities.create(actor, body.name, clientRequestInfo(request));
  }

  @Patch(':id/active')
  @RequirePermission('catalogue.manage')
  @ZodApiBody(SetAmenityActiveDto)
  @ApiOperation({
    summary: 'Switch an amenity on or off',
    description:
      'Requires catalogue.manage. A switched-off amenity cannot be given to a bus any more; ' +
      'buses that have it keep it. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AmenityIdParamDto,
    @Body() body: SetAmenityActiveDto,
    @Req() request: Request,
  ): Promise<AmenityView> {
    return this.amenities.setActive(actor, params.id, body.active, clientRequestInfo(request));
  }
}

/** What a bus form offers: the amenities that are switched on. */
@ApiTags('catalogue')
@Controller('catalogue/amenities')
export class AmenityChoicesController {
  constructor(private readonly amenities: AmenitiesService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({
    summary: 'Amenities a bus can have',
    description: 'Requires buses.read. The amenities that are switched on, by key and name.',
  })
  choices(): Promise<AmenityChoice[]> {
    return this.amenities.choices();
  }
}

@Module({
  imports: [
    MongooseModule.forFeature([{ name: AMENITY_MODEL, schema: amenitySchema }]),
    RbacModule,
  ],
  controllers: [AmenitiesAdminController, AmenityChoicesController],
  providers: [AmenitiesService],
  exports: [AmenitiesService, MongooseModule],
})
export class AmenitiesModule {}
