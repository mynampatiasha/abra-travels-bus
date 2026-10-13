import { type Types } from 'mongoose';
import { escapeRegExp } from '../../common/pipes/list-query';
import { normalizePhoneNumber } from '../../common/validation/contact-identifiers';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { importController } from '../catalogue-shared/catalogue_import_manage';
import {
  type ImportColumn,
  type ImportSpec,
  issueMessage,
  parseNumber,
} from '../catalogue-shared/catalogue_import_manage.service';
import { type ExportKind } from '../catalogue-shared/catalogue_export_manage.service';
import { CreateLocationDto, LocationListQueryDto } from './dto/location.dto';
import { type LocationView, LocationsService } from './services/locations.service';

/** The places list as a file. */
export const PLACES_EXPORT_KIND: ExportKind<LocationView> = {
  key: 'places',
  references: (places) => ({ City: places.map((place) => place.cityId) }),
  columns: [
    { header: 'Place', value: (place) => place.name },
    { header: 'City', value: (place, names) => names('City', place.cityId) },
    { header: 'Address', value: (place) => place.address },
    { header: 'Landmark', value: (place) => place.landmark },
    { header: 'Instructions', value: (place) => place.instructions },
    { header: 'Contact phone', value: (place) => place.contactPhone },
    { header: 'Latitude', value: (place) => place.latitude },
    { header: 'Longitude', value: (place) => place.longitude },
    { header: 'Added by', value: (place) => (place.operatorId ? 'Operator' : 'Platform') },
    { header: 'Status', value: (place) => (place.isActive ? 'Active' : 'Inactive') },
  ],
};

/** `GET catalogue/locations/export`. Register it before the module's other controllers. */
export const PlacesExportController = exportController({
  base: 'catalogue/locations',
  permission: 'catalogue.export',
  kind: PLACES_EXPORT_KIND,
  service: LocationsService,
  query: LocationListQueryDto,
  title: 'places',
  load: (service, query) => service.list(query as never),
});

const PLACE_COLUMNS = [
  {
    key: 'name',
    header: 'Place',
    required: true,
    aliases: ['name', 'place name'],
    sample: 'Hyderabad Bus Stand',
  },
  { key: 'city', header: 'City', required: true, sample: 'Hyderabad' },
  { key: 'address', header: 'Address', required: true, sample: '12 Main Road' },
  { key: 'landmark', header: 'Landmark', sample: 'Near the flyover' },
  { key: 'instructions', header: 'Instructions', sample: 'Report 15 minutes early' },
  { key: 'contact_phone', header: 'Contact phone', aliases: ['phone'], sample: '+919876543210' },
  { key: 'latitude', header: 'Latitude', sample: '17.385' },
  { key: 'longitude', header: 'Longitude', sample: '78.4867' },
] as const satisfies readonly ImportColumn[];

const PLACE_HEADERS: Readonly<Record<string, string>> = {
  name: 'Place',
  cityId: 'City',
  address: 'Address',
  landmark: 'Landmark',
  instructions: 'Instructions',
  contactPhone: 'Contact phone',
  latitude: 'Latitude',
  longitude: 'Longitude',
};

/**
 * Importing places: the city is named in the file and must be an active city; a place that exists
 * in that city already (same name), or appears twice in the file, is refused. Places are shared
 * by every operator, as when platform staff add one on the screen.
 */
export const PLACES_IMPORT_SPEC: ImportSpec<CreateLocationDto, LocationsService> = {
  key: 'places',
  columns: PLACE_COLUMNS,
  async begin(context) {
    const cities = await context.connection
      .model<{ name: string; translations?: Map<string, string> | Record<string, string> }>('City')
      .find({ isActive: true })
      .lean<Array<{ _id: Types.ObjectId; name: string }>>()
      .exec();
    context.state.cities = new Map(cities.map((city) => [city.name.trim().toLowerCase(), city]));
    context.state.seen = new Map<string, number>();
  },
  async prepare(raw, context, rowNumber) {
    const label = raw.name || `Row ${rowNumber}`;
    const errors: string[] = [];
    const cities = context.state.cities as Map<string, { _id: Types.ObjectId; name: string }>;
    const city = cities.get((raw.city ?? '').trim().toLowerCase());
    if (!city) {
      errors.push(raw.city ? `City: "${raw.city}" is not an active city.` : 'City: is required.');
    }
    const candidate: Record<string, unknown> = {};
    if (city) candidate.cityId = city._id.toHexString();
    for (const [key, field] of [
      ['name', 'name'],
      ['address', 'address'],
      ['landmark', 'landmark'],
      ['instructions', 'instructions'],
    ] as const) {
      if (raw[key]) candidate[field] = raw[key];
    }
    if (raw.contact_phone) {
      candidate.contactPhone = normalizePhoneNumber(raw.contact_phone) ?? raw.contact_phone;
    }
    for (const [key, field, header] of [
      ['latitude', 'latitude', 'Latitude'],
      ['longitude', 'longitude', 'Longitude'],
    ] as const) {
      const value = parseNumber(raw[key] ?? '');
      if (value === null) errors.push(`${header}: "${raw[key]}" is not a number.`);
      else if (value !== undefined) candidate[field] = value;
    }
    const parsed = CreateLocationDto.zodSchema.safeParse(candidate);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = String(issue.path[0] ?? '');
        if (field === 'cityId' && !city) continue; // already said
        errors.push(`${PLACE_HEADERS[field] ?? field}: ${issueMessage(issue)}`);
      }
    }
    if (
      (candidate.latitude === undefined) !== (candidate.longitude === undefined) &&
      errors.length === 0
    ) {
      errors.push('Latitude and longitude go together: fill in both or neither.');
    }
    if (errors.length > 0 || !parsed.success || !city) return { errors, label };

    const key = `${city._id.toHexString()}|${parsed.data.name.toLowerCase()}`;
    const seen = context.state.seen as Map<string, number>;
    const earlier = seen.get(key);
    if (earlier !== undefined) {
      return { errors: [`The same place appears in row ${earlier}.`], label };
    }
    const existing = await context.connection
      .model('Location')
      .exists({
        cityId: city._id,
        name: new RegExp(`^${escapeRegExp(parsed.data.name)}$`, 'i'),
      })
      .exec();
    if (existing) {
      return { errors: [`A place with this name already exists in ${city.name}.`], label };
    }
    seen.set(key, rowNumber);
    return { dto: parsed.data, label };
  },
  async create(context, actor, dto, client) {
    await context.service.create(actor, dto, client);
  },
};

/** `GET catalogue/locations/import-template` and `POST catalogue/locations/import`. Register it first. */
export const PlacesImportController = importController({
  base: 'catalogue/locations',
  permission: 'catalogue.manage',
  spec: PLACES_IMPORT_SPEC,
  service: LocationsService,
  title: 'places',
});
