import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { importController } from '../catalogue-shared/catalogue_import_manage';
import {
  type ImportColumn,
  type ImportSpec,
  issueMessage,
  parseNumber,
  parseYesNo,
} from '../catalogue-shared/catalogue_import_manage.service';
import { type ExportKind } from '../catalogue-shared/catalogue_export_manage.service';
import { CityListQueryDto, CreateCityDto } from './dto/city-admin.dto';
import { type CityAdminView, CitiesAdminService, slugOf } from './services/cities-admin.service';

/** The cities list as a file: the columns of the list, and the same file can be imported again. */
export const CITIES_EXPORT_KIND: ExportKind<CityAdminView> = {
  key: 'cities',
  columns: [
    { header: 'City', value: (city) => city.name },
    { header: 'State', value: (city) => city.state },
    { header: 'Country code', value: (city) => city.countryCode },
    { header: 'Slug', value: (city) => city.slug },
    { header: 'Telugu name', value: (city) => city.translations.te },
    { header: 'Hindi name', value: (city) => city.translations.hi },
    { header: 'Popular', value: (city) => city.isPopular },
    { header: 'Sort order', value: (city) => city.sortOrder },
    { header: 'Latitude', value: (city) => city.latitude },
    { header: 'Longitude', value: (city) => city.longitude },
    { header: 'Status', value: (city) => (city.isActive ? 'Active' : 'Inactive') },
  ],
};

/** `GET catalogue/cities/export`. Register it before the module's other controllers. */
export const CitiesExportController = exportController({
  base: 'catalogue/cities',
  permission: 'catalogue.export',
  kind: CITIES_EXPORT_KIND,
  service: CitiesAdminService,
  query: CityListQueryDto,
  title: 'cities',
  load: (service, query) => service.list(query as never),
});

const CITY_COLUMNS = [
  {
    key: 'name',
    header: 'City',
    required: true,
    aliases: ['name', 'city name'],
    sample: 'Hyderabad',
  },
  { key: 'state', header: 'State', required: true, sample: 'Telangana' },
  { key: 'country_code', header: 'Country code', sample: 'IN' },
  { key: 'slug', header: 'Slug', sample: 'hyderabad' },
  { key: 'telugu_name', header: 'Telugu name', sample: '' },
  { key: 'hindi_name', header: 'Hindi name', sample: '' },
  { key: 'popular', header: 'Popular', sample: 'Yes' },
  { key: 'sort_order', header: 'Sort order', sample: '0' },
  { key: 'latitude', header: 'Latitude', sample: '17.385' },
  { key: 'longitude', header: 'Longitude', sample: '78.4867' },
] as const satisfies readonly ImportColumn[];

const CITY_HEADERS: Readonly<Record<string, string>> = Object.fromEntries([
  ...CITY_COLUMNS.map((column) => [column.key, column.header] as const),
  ['countryCode', 'Country code'],
  ['isPopular', 'Popular'],
  ['sortOrder', 'Sort order'],
]);

/**
 * Importing cities: each row is checked with the rules of adding a city on the screen, and a city
 * whose slug (made from the name) is already taken, or appears twice in the file, is refused.
 */
export const CITIES_IMPORT_SPEC: ImportSpec<CreateCityDto, CitiesAdminService> = {
  key: 'cities',
  columns: CITY_COLUMNS,
  async prepare(raw, context, rowNumber) {
    const label = raw.name || `Row ${rowNumber}`;
    const errors: string[] = [];
    const candidate: Record<string, unknown> = {};
    const text = (key: string, field: string) => {
      if (raw[key]) candidate[field] = raw[key];
    };
    text('name', 'name');
    text('state', 'state');
    text('country_code', 'countryCode');
    text('slug', 'slug');
    for (const [key, field, header] of [
      ['latitude', 'latitude', 'Latitude'],
      ['longitude', 'longitude', 'Longitude'],
      ['sort_order', 'sortOrder', 'Sort order'],
    ] as const) {
      const value = parseNumber(raw[key] ?? '');
      if (value === null) errors.push(`${header}: "${raw[key]}" is not a number.`);
      else if (value !== undefined) candidate[field] = value;
    }
    const popular = parseYesNo(raw.popular ?? '');
    if (popular === null) errors.push(`Popular: "${raw.popular}" must be Yes or No.`);
    else if (popular !== undefined) candidate.isPopular = popular;
    const translations: Record<string, string> = {};
    if (raw.telugu_name) translations.te = raw.telugu_name;
    if (raw.hindi_name) translations.hi = raw.hindi_name;
    if (Object.keys(translations).length > 0) candidate.translations = translations;

    const parsed = CreateCityDto.zodSchema.safeParse(candidate);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = String(issue.path[0] ?? '');
        errors.push(`${CITY_HEADERS[field] ?? field}: ${issueMessage(issue)}`);
      }
    }
    // A rule of the service (not of the form): both or neither, as on the screen
    if (
      (candidate.latitude === undefined) !== (candidate.longitude === undefined) &&
      errors.length === 0
    ) {
      errors.push('Latitude and longitude go together: fill in both or neither.');
    }
    if (errors.length > 0 || !parsed.success) return { errors, label };

    const slug = parsed.data.slug ?? slugOf(parsed.data.name);
    const seen = (context.state.slugs ??= new Map<string, number>()) as Map<string, number>;
    const earlier = seen.get(slug);
    if (earlier !== undefined) {
      return { errors: [`The same city appears in row ${earlier}.`], label };
    }
    const taken = await context.connection
      .model('City')
      .exists({ slug })
      .setOptions({ withDeleted: true })
      .exec();
    if (taken) return { errors: ['A city with this name already exists.'], label };
    seen.set(slug, rowNumber);
    return { dto: parsed.data, label };
  },
  async create(context, actor, dto, client) {
    await context.service.create(actor, dto, client);
  },
};

/** `GET catalogue/cities/import-template` and `POST catalogue/cities/import`. Register it first. */
export const CitiesImportController = importController({
  base: 'catalogue/cities',
  permission: 'catalogue.manage',
  spec: CITIES_IMPORT_SPEC,
  service: CitiesAdminService,
  title: 'cities',
});
