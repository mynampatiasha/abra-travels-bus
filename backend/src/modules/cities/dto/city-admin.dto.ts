import { z } from 'zod';
import {
  activeFlag,
  changeReason,
  objectIdString,
  pagingShape,
} from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';

const name = z.string().trim().min(2).max(80);
const cityFields = {
  name,
  state: name,
  countryCode: z
    .string()
    .regex(/^[A-Za-z]{2}$/, 'must be a two-letter country code')
    .transform((value) => value.toUpperCase()),
  /** Names in other languages by language code, e.g. { "kn": "..." }. */
  translations: z.record(z.string().regex(/^[a-z]{2,3}$/), name).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  isPopular: z.boolean(),
  sortOrder: z.number().int().min(0).max(100_000),
};

export class CreateCityDto extends createZodDto(
  z.object({
    ...cityFields,
    countryCode: cityFields.countryCode.default('IN'),
    isPopular: cityFields.isPopular.default(false),
    sortOrder: cityFields.sortOrder.default(0),
    /** URL key; made from the name when left out. */
    slug: z
      .string()
      .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'lowercase letters, digits and hyphens only')
      .max(80)
      .optional(),
  }),
) {}

export class UpdateCityDto extends createZodDto(
  z.object({
    name: cityFields.name.optional(),
    state: cityFields.state.optional(),
    countryCode: cityFields.countryCode.optional(),
    translations: cityFields.translations,
    latitude: cityFields.latitude,
    longitude: cityFields.longitude,
    isPopular: cityFields.isPopular.optional(),
    sortOrder: cityFields.sortOrder.optional(),
  }),
) {}

export class CityListQueryDto extends createZodDto(
  z.object({
    /** Start of the name. */
    query: z.string().trim().min(1).max(40).optional(),
    active: activeFlag,
    ...pagingShape,
  }),
) {}

export class SetActiveDto extends createZodDto(
  z.object({ active: z.boolean(), reason: changeReason.optional() }),
) {}

export class CatalogueIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}
