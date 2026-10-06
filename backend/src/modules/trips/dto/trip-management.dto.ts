import { z } from 'zod';
import { changeReason, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { TRIP_STATUSES } from '../schemas/trip.schema';

const point = z.object({
  locationId: objectIdString,
  /** Minutes after the departure of the trip at which the bus is at this point. */
  offsetMinutes: z.number().int().min(0).max(4320),
});
const points = z.array(point).min(1).max(30);

const fields = {
  busId: objectIdString,
  routeId: objectIdString,
  /** Date of departure in India time. */
  travelDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date written YYYY-MM-DD'),
  /** Departure in India time, 24-hour clock. */
  departureTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'must be a time written HH:mm'),
  /** Journey time; the estimate of the route when left out. */
  durationMinutes: z.number().int().min(10).max(4320).optional(),
  /** Lowest fare of any seat, in paise. */
  startingFarePaise: z.number().int().min(100).max(100_000_00),
  boardingPoints: points,
  droppingPoints: points,
};

export class CreateTripDto extends createZodDto(z.object(fields)) {}

/** Only a draft can be edited. Only the fields sent change. */
export class UpdateTripDto extends createZodDto(
  z.object({
    busId: fields.busId.optional(),
    routeId: fields.routeId.optional(),
    travelDate: fields.travelDate.optional(),
    departureTime: fields.departureTime.optional(),
    durationMinutes: fields.durationMinutes,
    startingFarePaise: fields.startingFarePaise.optional(),
    boardingPoints: points.optional(),
    droppingPoints: points.optional(),
  }),
) {}

export class TripListQueryDto extends createZodDto(
  z.object({
    operatorId: objectIdString.optional(),
    busId: objectIdString.optional(),
    routeId: objectIdString.optional(),
    travelDate: fields.travelDate.optional(),
    status: z.enum(TRIP_STATUSES).optional(),
    ...pagingShape,
  }),
) {}

export class CancelTripDto extends createZodDto(z.object({ reason: changeReason })) {}
