import { z } from 'zod';
import { activeFlag, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { BERTH_TYPES } from '../schemas/bus-type.schema';

const name = z.string().trim().min(2).max(60);

export class CreateBusTypeDto extends createZodDto(
  z.object({
    /** Stable key used by filters, e.g. AC_SLEEPER. Cannot be changed later. */
    key: z.string().regex(/^[A-Z][A-Z0-9_]{1,39}$/, 'upper-case letters, digits and underscores'),
    name,
    isAc: z.boolean(),
    berthType: z.enum(BERTH_TYPES),
  }),
) {}

export class UpdateBusTypeDto extends createZodDto(
  z.object({
    name: name.optional(),
    isAc: z.boolean().optional(),
    berthType: z.enum(BERTH_TYPES).optional(),
  }),
) {}

export class BusTypeListQueryDto extends createZodDto(
  z.object({ active: activeFlag, ...pagingShape }),
) {}
