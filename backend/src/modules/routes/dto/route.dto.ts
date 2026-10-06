import { z } from 'zod';
import { changeReason, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { ROUTE_STATUSES } from '../schemas/route.schema';

const stop = z.object({
  cityId: objectIdString,
  /** Minutes after departure from the origin. */
  offsetMinutes: z.number().int().min(1).max(4320),
  distanceFromOriginKm: z.number().min(0).max(10_000).optional(),
});

const fields = {
  name: z.string().trim().min(2).max(120),
  distanceKm: z.number().min(1).max(10_000).optional(),
  estimatedDurationMinutes: z.number().int().min(10).max(4320),
  /** Cities passed through, in travel order. */
  stops: z.array(stop).max(30),
};

export class CreateRouteDto extends createZodDto(
  z.object({
    operatorId: objectIdString.optional(),
    originCityId: objectIdString,
    destinationCityId: objectIdString,
    ...fields,
    stops: fields.stops.default([]),
  }),
) {}

/** Origin, destination and operator cannot be changed: create another route instead. */
export class UpdateRouteDto extends createZodDto(
  z.object({
    name: fields.name.optional(),
    distanceKm: fields.distanceKm,
    estimatedDurationMinutes: fields.estimatedDurationMinutes.optional(),
    stops: fields.stops.optional(),
  }),
) {}

export class RouteListQueryDto extends createZodDto(
  z.object({
    operatorId: objectIdString.optional(),
    originCityId: objectIdString.optional(),
    destinationCityId: objectIdString.optional(),
    status: z.enum(ROUTE_STATUSES).optional(),
    ...pagingShape,
  }),
) {}

export class ChangeRouteStatusDto extends createZodDto(
  z.object({ status: z.enum(ROUTE_STATUSES), reason: changeReason.optional() }),
) {}
