import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';

export class CityQueryDto extends createZodDto(
  z.object({
    /** Start of a city name. Without it the popular cities are returned. */
    query: z.string().trim().min(1).max(40).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  }),
) {}
