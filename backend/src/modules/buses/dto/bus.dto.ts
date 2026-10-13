import { z } from 'zod';
import { changeReason, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { BUS_STATUSES, MANUAL_BUS_STATUSES } from '../schemas/bus.schema';

const fields = {
  name: z.string().trim().min(2).max(80),
  busTypeId: objectIdString,
  /** Keys of amenities that are switched on (`GET /catalogue/amenities`). */
  amenities: z
    .array(z.string().regex(/^[A-Z][A-Z0-9_]{1,39}$/, 'must be an amenity key'))
    .max(50)
    .refine((list) => new Set(list).size === list.length, 'must not repeat an amenity'),
  /** Seats and berths sold on this bus. */
  seatCapacity: z.number().int().min(1).max(100),
};

export class CreateBusDto extends createZodDto(
  z.object({
    /** Required for platform staff; operator staff create for their own operator. */
    operatorId: objectIdString.optional(),
    registrationNumber: z
      .string()
      .trim()
      .transform((value) => value.toUpperCase().replace(/[\s-]/g, ''))
      .pipe(z.string().regex(/^[A-Z0-9]{5,15}$/, 'must be a vehicle registration number')),
    ...fields,
    amenities: fields.amenities.default([]),
  }),
) {}

export class UpdateBusDto extends createZodDto(
  z.object({
    name: fields.name.optional(),
    busTypeId: fields.busTypeId.optional(),
    amenities: fields.amenities.optional(),
    seatCapacity: fields.seatCapacity.optional(),
  }),
) {}

export class BusListQueryDto extends createZodDto(
  z.object({
    operatorId: objectIdString.optional(),
    status: z.enum(BUS_STATUSES).optional(),
    ...pagingShape,
  }),
) {}

export class ChangeBusStatusDto extends createZodDto(
  z.object({ status: z.enum(MANUAL_BUS_STATUSES), reason: changeReason.optional() }),
) {}
