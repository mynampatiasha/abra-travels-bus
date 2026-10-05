import { Injectable } from '@nestjs/common';
import { type Types } from 'mongoose';
import { CityRepository, type StoredCity } from '../repositories/city.repository';

export interface CityView {
  id: string;
  /** Name in the requested language when a translation exists, otherwise in English. */
  name: string;
  state: string;
  slug: string;
}

/** Name of `city` in `language`, falling back to English. */
export function cityNameIn(city: StoredCity, language: string | undefined): string {
  return (language && city.translations?.[language]) || city.name;
}

/** The city catalogue as customers see it. */
@Injectable()
export class CitiesService {
  constructor(private readonly cities: CityRepository) {}

  async search(
    query: string | undefined,
    language: string | undefined,
    limit: number,
  ): Promise<CityView[]> {
    const found = query
      ? await this.cities.searchByName(query, language, limit)
      : await this.cities.popular(limit);
    return found.map((city) => this.viewOf(city, language));
  }

  /** Active cities by id, keyed by id. A missing or inactive city is absent from the map. */
  async activeById(
    ids: readonly Types.ObjectId[],
    language: string | undefined,
  ): Promise<Map<string, CityView>> {
    return this.toMap(await this.cities.findActiveByIds(ids), language);
  }

  /** Names for display of cities a trip refers to, including cities retired since. */
  async byId(
    ids: readonly Types.ObjectId[],
    language: string | undefined,
  ): Promise<Map<string, CityView>> {
    return this.toMap(await this.cities.findByIds(ids), language);
  }

  private toMap(cities: StoredCity[], language: string | undefined): Map<string, CityView> {
    return new Map(cities.map((city) => [city._id.toHexString(), this.viewOf(city, language)]));
  }

  private viewOf(city: StoredCity, language: string | undefined): CityView {
    return {
      id: city._id.toHexString(),
      name: cityNameIn(city, language),
      state: city.state,
      slug: city.slug,
    };
  }
}
