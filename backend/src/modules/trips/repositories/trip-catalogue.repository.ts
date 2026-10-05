import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, type PipelineStage, Types } from 'mongoose';
import { OPERATOR_MODEL, type Operator } from '../../operators/schemas/operator.schema';
import { DEPARTURE_WINDOWS, type DepartureWindow, type TripSort } from '../dto/trip-search.dto';
import { BOOKABLE_TRIP_STATUSES, TRIP_MODEL, type Trip } from '../schemas/trip.schema';

/** A trip on sale, with the name of its (active) operator. */
export type CatalogueTrip = Trip & {
  _id: Types.ObjectId;
  operator: { _id: Types.ObjectId; companyName: string; displayName?: string };
};

export interface TripCriteria {
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  travelDate: string;
  passengers?: number | undefined;
}

export interface TripFilters {
  departureWindows?: DepartureWindow[] | undefined;
  busTypeKeys?: string[] | undefined;
  isAc?: boolean | undefined;
  operatorIds?: Types.ObjectId[] | undefined;
  amenities?: string[] | undefined;
  minFarePaise?: number | undefined;
  maxFarePaise?: number | undefined;
}

export interface TripFacets {
  total: number;
  busTypes: { key: string; name: string; isAc: boolean; berthType: string; count: number }[];
  operators: { id: Types.ObjectId; companyName: string; displayName?: string; count: number }[];
  amenities: { key: string; count: number }[];
  departureWindows: { key: DepartureWindow; count: number }[];
  fare: { minPaise: number; maxPaise: number } | null;
}

const SORT_STAGES: Record<TripSort, Record<string, 1 | -1>> = {
  // _id makes the order total, so paging never repeats or skips a trip
  DEPARTURE_EARLIEST: { departureAt: 1, _id: 1 },
  DEPARTURE_LATEST: { departureAt: -1, _id: 1 },
  FARE_LOWEST: { startingFarePaise: 1, departureAt: 1, _id: 1 },
  FARE_HIGHEST: { startingFarePaise: -1, departureAt: 1, _id: 1 },
  DURATION_SHORTEST: { durationMinutes: 1, departureAt: 1, _id: 1 },
};

/**
 * Read-only view of `trips` for customers: the catalogue of trips on sale.
 *
 * It is deliberately not a ScopedRepository. The catalogue is public, so there is no actor scope
 * to apply; instead every query here is restricted to what may be shown to anyone: trips that
 * are published and bookable, have not departed, and belong to an ACTIVE operator. Operator
 * staff manage their own trips through a scoped repository (operator portal), never through
 * this class.
 */
@Injectable()
export class TripCatalogueRepository {
  private readonly operatorCollection: string;

  constructor(
    @InjectModel(TRIP_MODEL) private readonly trips: Model<Trip>,
    @InjectModel(OPERATOR_MODEL) operators: Model<Operator>,
  ) {
    this.operatorCollection = operators.collection.name;
  }

  async search(
    criteria: TripCriteria,
    filters: TripFilters,
    sort: TripSort,
    page: { skip: number; limit: number },
    now: Date,
  ): Promise<{ items: CatalogueTrip[]; total: number }> {
    const [result] = await this.trips
      .aggregate<{ items: CatalogueTrip[]; total: { count: number }[] }>([
        ...this.onSale(this.criteriaMatch(criteria), now),
        { $match: this.filterMatch(filters) },
        {
          $facet: {
            items: [{ $sort: SORT_STAGES[sort] }, { $skip: page.skip }, { $limit: page.limit }],
            total: [{ $count: 'count' }],
          },
        },
      ])
      .exec();
    return { items: result?.items ?? [], total: result?.total[0]?.count ?? 0 };
  }

  /** What the unfiltered search contains: the values a customer can filter by, with counts. */
  async facets(criteria: TripCriteria, now: Date): Promise<TripFacets> {
    const windows = Object.entries(DEPARTURE_WINDOWS) as [
      DepartureWindow,
      { fromMinute: number; toMinute: number },
    ][];
    const [result] = await this.trips
      .aggregate<{
        total: { count: number }[];
        busTypes: { _id: string; name: string; isAc: boolean; berthType: string; count: number }[];
        operators: {
          _id: Types.ObjectId;
          companyName: string;
          displayName?: string;
          count: number;
        }[];
        amenities: { _id: string; count: number }[];
        departureWindows: { _id: number; count: number }[];
        fare: { minPaise: number; maxPaise: number }[];
      }>([
        ...this.onSale(this.criteriaMatch(criteria), now),
        {
          $facet: {
            total: [{ $count: 'count' }],
            busTypes: [
              {
                $group: {
                  _id: '$bus.busTypeKey',
                  name: { $first: '$bus.busTypeName' },
                  isAc: { $first: '$bus.isAc' },
                  berthType: { $first: '$bus.berthType' },
                  count: { $sum: 1 },
                },
              },
              { $sort: { _id: 1 } },
            ],
            operators: [
              {
                $group: {
                  _id: '$operator._id',
                  companyName: { $first: '$operator.companyName' },
                  displayName: { $first: '$operator.displayName' },
                  count: { $sum: 1 },
                },
              },
              { $sort: { companyName: 1 } },
            ],
            amenities: [
              { $unwind: '$bus.amenities' },
              { $group: { _id: '$bus.amenities', count: { $sum: 1 } } },
              { $sort: { _id: 1 } },
            ],
            departureWindows: [
              {
                $bucket: {
                  groupBy: '$departureMinuteOfDay',
                  boundaries: [...windows.map(([, window]) => window.fromMinute), 1440],
                  output: { count: { $sum: 1 } },
                },
              },
            ],
            fare: [
              {
                $group: {
                  _id: null,
                  minPaise: { $min: '$startingFarePaise' },
                  maxPaise: { $max: '$startingFarePaise' },
                },
              },
            ],
          },
        },
      ])
      .exec();

    const countByStart = new Map(
      (result?.departureWindows ?? []).map((bucket) => [bucket._id, bucket.count]),
    );
    const fare = result?.fare[0];
    return {
      total: result?.total[0]?.count ?? 0,
      busTypes: (result?.busTypes ?? []).map(({ _id, ...rest }) => ({ key: _id, ...rest })),
      operators: (result?.operators ?? []).map(({ _id, ...rest }) => ({ id: _id, ...rest })),
      amenities: (result?.amenities ?? []).map(({ _id, count }) => ({ key: _id, count })),
      departureWindows: windows.map(([key, window]) => ({
        key,
        count: countByStart.get(window.fromMinute) ?? 0,
      })),
      fare: fare ? { minPaise: fare.minPaise, maxPaise: fare.maxPaise } : null,
    };
  }

  /** The trip, if it is on sale. Null otherwise (draft, cancelled, departed, operator inactive). */
  async findOnSale(tripId: Types.ObjectId, now: Date): Promise<CatalogueTrip | null> {
    const [trip] = await this.trips
      .aggregate<CatalogueTrip>(this.onSale({ _id: tripId }, now))
      .exec();
    return trip ?? null;
  }

  /** `match`, narrowed to trips that may be shown to anyone. */
  private onSale(match: Record<string, unknown>, now: Date): PipelineStage[] {
    return [
      {
        $match: {
          ...match,
          status: { $in: [...BOOKABLE_TRIP_STATUSES] },
          departureAt: { $gt: now },
        },
      },
      {
        $lookup: {
          from: this.operatorCollection,
          let: { operatorId: '$operatorId' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [{ $eq: ['$_id', '$$operatorId'] }, { $eq: ['$status', 'ACTIVE'] }],
                },
              },
            },
            { $project: { companyName: 1, displayName: 1 } },
          ],
          as: 'operator',
        },
      },
      // Drops trips whose operator is not active
      { $unwind: '$operator' },
    ];
  }

  private criteriaMatch(criteria: TripCriteria): Record<string, unknown> {
    return {
      originCityId: criteria.originCityId,
      destinationCityId: criteria.destinationCityId,
      travelDate: criteria.travelDate,
      ...(criteria.passengers ? { 'seatCounts.available': { $gte: criteria.passengers } } : {}),
    };
  }

  private filterMatch(filters: TripFilters): Record<string, unknown> {
    const match: Record<string, unknown> = {};
    if (filters.departureWindows?.length) {
      match.$or = filters.departureWindows.map((key) => ({
        departureMinuteOfDay: {
          $gte: DEPARTURE_WINDOWS[key].fromMinute,
          $lt: DEPARTURE_WINDOWS[key].toMinute,
        },
      }));
    }
    if (filters.busTypeKeys?.length) match['bus.busTypeKey'] = { $in: filters.busTypeKeys };
    if (filters.isAc !== undefined) match['bus.isAc'] = filters.isAc;
    if (filters.operatorIds?.length) match.operatorId = { $in: filters.operatorIds };
    if (filters.amenities?.length) match['bus.amenities'] = { $all: filters.amenities };
    if (filters.minFarePaise !== undefined || filters.maxFarePaise !== undefined) {
      match.startingFarePaise = {
        ...(filters.minFarePaise !== undefined ? { $gte: filters.minFarePaise } : {}),
        ...(filters.maxFarePaise !== undefined ? { $lte: filters.maxFarePaise } : {}),
      };
    }
    return match;
  }
}
