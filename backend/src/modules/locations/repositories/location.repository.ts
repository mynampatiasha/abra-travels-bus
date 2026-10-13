import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, type Types } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { hasPlatformScope } from '../../../common/request-context/operator-scope';
import { LOCATION_MODEL, type Location } from '../schemas/location.schema';

export type StoredLocation = StoredDocument<Location>;

/**
 * `locations`. Two kinds live here: shared locations (no operatorId, maintained by platform
 * staff, usable by every operator) and an operator's own locations.
 *
 * - Writes go through the data scope: operator staff can create and change only their own.
 * - Reads for operator staff add the shared locations to their own (`findVisible`).
 */
@Injectable()
export class LocationRepository extends ScopedRepository<Location> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(LOCATION_MODEL) model: Model<Location>) {
    super(model);
  }

  private async visibleFilter(filter: QueryFilter<Location>): Promise<QueryFilter<Location>> {
    const actor = this.currentActor();
    if (actor.actorType === 'USER' && hasPlatformScope(actor)) return filter;
    const own = await this.scopedFilter({});
    return { $and: [filter, { $or: [{ operatorId: null }, own] }] };
  }

  async findVisible(
    filter: QueryFilter<Location>,
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredLocation[]; total: number }> {
    const match = await this.visibleFilter(filter);
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ name: 1, _id: 1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredLocation[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  /**
   * How many trips use each place as a boarding or dropping point (the demo's "Trips using it").
   * Places no trip uses are missing from the map.
   */
  async tripCounts(ids: readonly Types.ObjectId[]): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await this.model.db
      .model('Trip')
      .aggregate<{ _id: Types.ObjectId; count: number }>([
        {
          $match: {
            $or: [
              { 'boardingPoints.locationId': { $in: [...ids] } },
              { 'droppingPoints.locationId': { $in: [...ids] } },
            ],
          },
        },
        {
          $project: {
            places: {
              $setUnion: [
                { $ifNull: ['$boardingPoints.locationId', []] },
                { $ifNull: ['$droppingPoints.locationId', []] },
              ],
            },
          },
        },
        { $unwind: '$places' },
        { $match: { places: { $in: [...ids] } } },
        { $group: { _id: '$places', count: { $sum: 1 } } },
      ])
      .exec();
    return new Map(rows.map((row) => [row._id.toHexString(), row.count]));
  }

  async findVisibleById(id: string): Promise<StoredLocation | null> {
    return this.model
      .findOne(await this.visibleFilter({ _id: id }))
      .lean<StoredLocation>()
      .exec();
  }

  /**
   * Locations a trip of `operatorId` may use as boarding or dropping points: shared ones and
   * that operator's own. The caller has already been authorised for that operator.
   */
  findUsableBy(
    operatorId: Types.ObjectId,
    ids: readonly Types.ObjectId[],
    session?: ClientSession,
  ): Promise<StoredLocation[]> {
    return this.model
      .find({ _id: { $in: ids }, $or: [{ operatorId: null }, { operatorId }] })
      .session(session ?? null)
      .lean<StoredLocation[]>()
      .exec();
  }
}
