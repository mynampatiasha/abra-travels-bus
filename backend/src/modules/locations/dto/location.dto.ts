import { z } from 'zod';
import { activeFlag, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { PLACE_USES } from '../schemas/location.schema';

const fields = {
  name: z.string().trim().min(2).max(120),
  address: z.string().trim().min(3).max(300),
  landmark: z.string().trim().min(2).max(160).nullable().optional(),
  instructions: z.string().trim().min(2).max(300).nullable().optional(),
  contactPhone: z
    .string()
    .regex(/^\+[1-9]\d{7,14}$/, 'must be a phone number in international form')
    .nullable()
    .optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  usedFor: z.enum(PLACE_USES).optional(),
};

export class CreateLocationDto extends createZodDto(
  z.object({
    cityId: objectIdString,
    /**
     * Operator the location belongs to. Left out by platform staff for a location every
     * operator may use; operator staff always create for their own operator.
     */
    operatorId: objectIdString.optional(),
    ...fields,
  }),
) {}

export class UpdateLocationDto extends createZodDto(
  z.object({ ...fields, name: fields.name.optional(), address: fields.address.optional() }),
) {}

export class LocationListQueryDto extends createZodDto(
  z.object({
    cityId: objectIdString.optional(),
    active: activeFlag,
    /** Part of the name, address or landmark. */
    query: z.string().trim().max(100).optional(),
    usedFor: z.enum(PLACE_USES).optional(),
    ...pagingShape,
  }),
) {}
