import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, type QueryFilter, type Types } from 'mongoose';
import { CITY_MODEL, type City } from '../schemas/city.schema';

export type StoredCity = City & { _id: Types.ObjectId };

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * `cities`. A platform catalogue that everyone may read, so it is not a ScopedRepository; only
 * active cities are ever returned.
 */
@Injectable()
export class CityRepository {
  constructor(@InjectModel(CITY_MODEL) private readonly model: Model<City>) {}

  /** Active cities whose name (English, or in `language`) starts with `query`. */
  searchByName(query: string, language: string | undefined, limit: number): Promise<StoredCity[]> {
    const startsWith = new RegExp(`^${escapeRegExp(query)}`, 'i');
    const names: QueryFilter<City>[] = [{ name: startsWith }];
    if (language) names.push({ [`translations.${language}`]: startsWith });
    return this.model
      .find({ isActive: true, $or: names })
      .sort({ isPopular: -1, sortOrder: 1, name: 1 })
      .limit(limit)
      .lean<StoredCity[]>()
      .exec();
  }

  popular(limit: number): Promise<StoredCity[]> {
    return this.model
      .find({ isActive: true, isPopular: true })
      .sort({ sortOrder: 1, name: 1 })
      .limit(limit)
      .lean<StoredCity[]>()
      .exec();
  }

  findActiveByIds(ids: readonly Types.ObjectId[]): Promise<StoredCity[]> {
    return this.model
      .find({ _id: { $in: ids }, isActive: true })
      .lean<StoredCity[]>()
      .exec();
  }

  /** Cities by id whatever their status: a trip keeps showing a city that was later retired. */
  findByIds(ids: readonly Types.ObjectId[]): Promise<StoredCity[]> {
    return this.model
      .find({ _id: { $in: ids } })
      .lean<StoredCity[]>()
      .exec();
  }
}
