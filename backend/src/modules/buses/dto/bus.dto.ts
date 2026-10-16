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
  insuranceExpiryDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  seatLayoutType: z.string().trim().min(2).max(40).optional(),
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
    insuranceExpiryDate: fields.insuranceExpiryDate,
    seatLayoutType: fields.seatLayoutType,
  }),
) {}

export class BusListQueryDto extends createZodDto(
  z.object({
    query: z.string().trim().max(100).optional(),
    operatorId: objectIdString.optional(),
    busTypeId: objectIdString.optional(),
    status: z.enum(BUS_STATUSES).optional(),
    expiredInsurance: z
      .enum(['true', 'false'])
      .optional()
      .transform((val) => (val ? val === 'true' : undefined)),
    ...pagingShape,
  }),
) {}

export class ChangeBusStatusDto extends createZodDto(
  z.object({ status: z.enum(MANUAL_BUS_STATUSES), reason: changeReason.optional() }),
) {}

export class BulkMaintenanceDto extends createZodDto(
  z.object({
    busIds: z.array(objectIdString).min(1).max(100),
    reason: changeReason.optional(),
  }),
) {}

export class SaveSeatLayoutDto extends createZodDto(
  z.object({
    name: z.string().trim().min(1).max(80).default('Main Layout'),
    layoutType: z.string().trim().min(2).max(40).default('2+2 Seater'),
    decks: z.number().int().min(1).max(2).default(1),
    map: z.array(z.string().min(1).max(20)).min(1).max(30),
    upperDeckMap: z.array(z.string().min(1).max(20)).max(30).optional(),
  }),
) {}
