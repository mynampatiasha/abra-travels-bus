import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, type Types } from 'mongoose';
import { escapeRegExp } from '../../../common/pipes/list-query';
import { CITY_MODEL, type City } from '../schemas/city.schema';

export type StoredCity = City & { _id: Types.ObjectId };

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

  // ---- management (platform staff; authorised by permission, the catalogue has no tenant) ----

  findById(id: string, session?: ClientSession): Promise<StoredCity | null> {
    return this.model
      .findById(id)
      .session(session ?? null)
      .lean<StoredCity>()
      .exec();
  }

  async list(
    filter: { query?: string | undefined; active?: boolean | undefined },
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredCity[]; total: number }> {
    const match: QueryFilter<City> = {};
    if (filter.query) match.name = new RegExp(`^${escapeRegExp(filter.query)}`, 'i');
    if (filter.active !== undefined) match.isActive = filter.active;
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ name: 1, _id: 1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredCity[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  async insert(city: City, session: ClientSession): Promise<StoredCity> {
    const [created] = await this.model.create([city], { session });
    if (!created) throw new Error('City was not created');
    return created.toObject();
  }

  update(
    id: Types.ObjectId,
    set: Partial<City>,
    session: ClientSession,
  ): Promise<StoredCity | null> {
    return this.model
      .findOneAndUpdate(
        { _id: id },
        { $set: set },
        { returnDocument: 'after', session, runValidators: true },
      )
      .lean<StoredCity>()
      .exec();
  }
}
