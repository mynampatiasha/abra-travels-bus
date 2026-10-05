import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { RateLimiterService } from '../../../common/rate-limit/rate-limiter.service';
import { sha256Hex } from '../../../common/crypto/secure-hash';
import { CitiesService } from '../../cities/services/cities.service';
import {
  DEPARTURE_WINDOWS,
  type TripSearchCriteriaDto,
  type TripSearchQueryDto,
} from '../dto/trip-search.dto';
import {
  type TripCriteria,
  TripCatalogueRepository,
} from '../repositories/trip-catalogue.repository';
import {
  operatorName,
  type TripDetailView,
  tripDetailOf,
  type TripSearchFiltersView,
  type TripSummaryView,
  tripSummaryOf,
} from './trip-discovery.views';
import { isCalendarDate, searchableDates } from './travel-date';

/** Anonymous search requests allowed per client address (api-architecture.md §1). */
const SEARCHES_PER_MINUTE = 60;

type Criteria = Pick<TripSearchCriteriaDto, 'from' | 'to' | 'date' | 'passengers'>;

/**
 * What customers and guests can find: trips on sale between two cities on a date, the values
 * they can filter by, and the details of one trip. Read-only and public; nothing here depends on
 * who is asking.
 */
@Injectable()
export class TripDiscoveryService {
  constructor(
    private readonly catalogue: TripCatalogueRepository,
    private readonly cities: CitiesService,
    private readonly rateLimiter: RateLimiterService,
  ) {}

  async search(
    query: TripSearchQueryDto,
    language: string | undefined,
    clientIp: string,
  ): Promise<PaginatedResult<TripSummaryView>> {
    await this.enforceRate(clientIp);
    if (
      query.minFare !== undefined &&
      query.maxFare !== undefined &&
      query.minFare > query.maxFare
    ) {
      throw new ApiException('VALIDATION_FAILED', 'minFare must not be greater than maxFare.');
    }
    const { criteria, cityNames } = await this.resolve(query, language);

    const { items, total } = await this.catalogue.search(
      criteria,
      {
        departureWindows: query.departureWindows,
        busTypeKeys: query.busTypes,
        isAc: query.ac === undefined ? undefined : query.ac === 'true',
        operatorIds: query.operatorIds?.map((id) => new Types.ObjectId(id)),
        amenities: query.amenities,
        minFarePaise: query.minFare,
        maxFarePaise: query.maxFare,
      },
      query.sort,
      { skip: (query.page - 1) * query.pageSize, limit: query.pageSize },
      new Date(),
    );
    return new PaginatedResult(
      items.map((trip) => tripSummaryOf(trip, cityNames)),
      query.page,
      query.pageSize,
      total,
    );
  }

  async filters(
    query: Criteria,
    language: string | undefined,
    clientIp: string,
  ): Promise<TripSearchFiltersView> {
    await this.enforceRate(clientIp);
    const { criteria } = await this.resolve(query, language);
    const facets = await this.catalogue.facets(criteria, new Date());
    return {
      total: facets.total,
      busTypes: facets.busTypes,
      operators: facets.operators.map((operator) => ({
        id: operator.id.toHexString(),
        name: operatorName({ _id: operator.id, ...operator }),
        count: operator.count,
      })),
      amenities: facets.amenities,
      departureWindows: facets.departureWindows.map(({ key, count }) => ({
        key,
        ...DEPARTURE_WINDOWS[key],
        count,
      })),
      fare: facets.fare ? { ...facets.fare, currency: 'INR' } : null,
    };
  }

  async describe(tripId: string, language: string | undefined): Promise<TripDetailView> {
    const trip = await this.catalogue.findOnSale(new Types.ObjectId(tripId), new Date());
    // Draft, cancelled, departed and unknown trips all look the same from outside
    if (!trip) throw new ApiException('RESOURCE_NOT_FOUND', 'This trip is not available.');
    const cityIds = [
      trip.originCityId,
      trip.destinationCityId,
      ...trip.stopCityIds,
      ...trip.boardingPoints.map((point) => point.cityId),
      ...trip.droppingPoints.map((point) => point.cityId),
    ];
    return tripDetailOf(trip, await this.cities.byId(cityIds, language));
  }

  /** Validates what a DTO cannot (cross-field rules, the date range, that the cities exist). */
  private async resolve(query: Criteria, language: string | undefined) {
    if (query.from.toLowerCase() === query.to.toLowerCase()) {
      throw new ApiException('VALIDATION_FAILED', 'Origin and destination must be different.');
    }
    const { first, last } = searchableDates(new Date());
    if (!isCalendarDate(query.date) || query.date < first || query.date > last) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `The travel date must be between ${first} and ${last}.`,
        { firstDate: first, lastDate: last },
      );
    }
    const originCityId = new Types.ObjectId(query.from);
    const destinationCityId = new Types.ObjectId(query.to);
    const cityNames = await this.cities.activeById([originCityId, destinationCityId], language);
    if (cityNames.size !== 2) {
      throw new ApiException('VALIDATION_FAILED', 'Origin or destination is not a known city.');
    }
    const criteria: TripCriteria = {
      originCityId,
      destinationCityId,
      travelDate: query.date,
      passengers: query.passengers,
    };
    return { criteria, cityNames };
  }

  private async enforceRate(clientIp: string): Promise<void> {
    const decision = await this.rateLimiter.hit(
      this.rateLimiter.key('trips', 'search', 'ip', sha256Hex(clientIp).slice(0, 32)),
      SEARCHES_PER_MINUTE,
      60,
    );
    if (!decision.allowed) {
      throw new ApiException('RATE_LIMITED', 'Too many searches. Please wait a moment.', {
        retryAfterSeconds: decision.retryAfterSeconds,
      });
    }
  }
}
