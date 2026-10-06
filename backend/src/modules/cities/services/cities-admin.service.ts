import { Injectable } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { rejectDuplicates } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type CityListQueryDto,
  type CreateCityDto,
  type UpdateCityDto,
} from '../dto/city-admin.dto';
import { CityRepository, type StoredCity } from '../repositories/city.repository';
import { type City, type GeoPoint } from '../schemas/city.schema';

/** A city as platform staff see it. */
export interface CityAdminView {
  id: string;
  name: string;
  slug: string;
  state: string;
  countryCode: string;
  translations: Record<string, string>;
  latitude: number | null;
  longitude: number | null;
  isPopular: boolean;
  sortOrder: number;
  isActive: boolean;
  updatedAt: string | null;
}

const DUPLICATE = 'A city with this name already exists.';

export function slugOf(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function pointOf(latitude?: number, longitude?: number): GeoPoint | undefined {
  if (latitude === undefined && longitude === undefined) return undefined;
  if (latitude === undefined || longitude === undefined) {
    throw new ApiException('VALIDATION_FAILED', 'latitude and longitude go together.');
  }
  return { type: 'Point', coordinates: [longitude, latitude] };
}

export function cityAdminViewOf(city: StoredCity): CityAdminView {
  const translations =
    city.translations instanceof Map
      ? (Object.fromEntries(city.translations) as Record<string, string>)
      : (city.translations ?? {});
  return {
    id: city._id.toHexString(),
    name: city.name,
    slug: city.slug,
    state: city.state,
    countryCode: city.countryCode,
    translations,
    latitude: city.location?.coordinates?.[1] ?? null,
    longitude: city.location?.coordinates?.[0] ?? null,
    isPopular: city.isPopular,
    sortOrder: city.sortOrder,
    isActive: city.isActive,
    updatedAt: city.updatedAt?.toISOString() ?? null,
  };
}

/** Management of the city catalogue by platform staff. Every change is audited. */
@Injectable()
export class CitiesAdminService {
  constructor(
    private readonly cities: CityRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: CityListQueryDto): Promise<PaginatedResult<CityAdminView>> {
    const { items, total } = await this.cities.list(
      { query: query.query, active: query.active },
      { skip: skipOf(query), limit: query.pageSize },
    );
    return new PaginatedResult(items.map(cityAdminViewOf), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<CityAdminView> {
    return cityAdminViewOf(await this.require(id));
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateCityDto,
    client: ClientRequestInfo,
  ): Promise<CityAdminView> {
    const slug = input.slug ?? slugOf(input.name);
    if (!slug) throw new ApiException('VALIDATION_FAILED', 'A slug is required for this name.');
    const location = pointOf(input.latitude, input.longitude);
    const city: City = {
      name: input.name,
      slug,
      state: input.state,
      countryCode: input.countryCode,
      ...(input.translations ? { translations: input.translations } : {}),
      ...(location ? { location } : {}),
      isPopular: input.isPopular,
      sortOrder: input.sortOrder,
      isActive: true,
    };
    const created = await rejectDuplicates(DUPLICATE, () =>
      this.changes.run({
        actor,
        client,
        action: 'catalogue.created',
        entityType: 'city',
        before: {},
        apply: (session) => this.cities.insert(city, session),
        describe: (record) => ({ ...cityAdminViewOf(record) }),
      }),
    );
    return cityAdminViewOf(created);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateCityDto,
    client: ClientRequestInfo,
  ): Promise<CityAdminView> {
    const before = await this.require(id);
    const { latitude, longitude, ...fields } = input;
    const location = pointOf(latitude, longitude);
    const set: Partial<City> = { ...(location ? { location } : {}) };
    for (const [key, value] of Object.entries(fields)) {
      if (value !== undefined) Object.assign(set, { [key]: value });
    }
    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    return cityAdminViewOf(
      await this.changes.run({
        actor,
        client,
        action: 'catalogue.updated',
        entityType: 'city',
        before: { ...cityAdminViewOf(before) },
        apply: (session) => this.saved(this.cities.update(before._id, set, session)),
        describe: (record) => ({ ...cityAdminViewOf(record) }),
      }),
    );
  }

  /** Disabling hides the city from selection and search; trips already on sale keep their name. */
  async setActive(
    actor: AuthenticatedUserActor,
    id: string,
    input: { active: boolean; reason?: string | undefined },
    client: ClientRequestInfo,
  ): Promise<CityAdminView> {
    const before = await this.require(id);
    if (before.isActive === input.active) return cityAdminViewOf(before);
    return cityAdminViewOf(
      await this.changes.run({
        actor,
        client,
        action: 'catalogue.status-changed',
        entityType: 'city',
        before: { isActive: before.isActive },
        reason: input.reason,
        apply: (session) =>
          this.saved(this.cities.update(before._id, { isActive: input.active }, session)),
        describe: (record) => ({ isActive: record.isActive }),
      }),
    );
  }

  private async require(id: string): Promise<StoredCity> {
    const city = await this.cities.findById(id);
    if (!city) throw new ApiException('RESOURCE_NOT_FOUND', 'City not found');
    return city;
  }

  private async saved(update: Promise<StoredCity | null>): Promise<StoredCity> {
    const city = await update;
    if (!city) throw new ApiException('RESOURCE_NOT_FOUND', 'City not found');
    return city;
  }
}
