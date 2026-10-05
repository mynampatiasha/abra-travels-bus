import { Controller, Get, Headers, Param, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { preferredLanguage } from '../../../common/http/preferred-language';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { TripIdParamDto, TripSearchCriteriaDto, TripSearchQueryDto } from '../dto/trip-search.dto';
import { TripDiscoveryService } from '../services/trip-discovery.service';
import {
  type TripDetailView,
  type TripSearchFiltersView,
  type TripSummaryView,
} from '../services/trip-discovery.views';

const ON_SALE =
  'Only trips on sale are returned: published, not yet departed, of an active operator.';

/** Trip discovery for customers and guests. Public: no sign-in, nothing personal in or out. */
@ApiTags('discovery')
@PublicEndpoint()
@Controller('trips')
export class TripDiscoveryController {
  constructor(private readonly discovery: TripDiscoveryService) {}

  @Get('search')
  @ApiOperation({
    summary: 'Search trips between two cities on a date',
    description:
      `Public, limited to 60 requests a minute per client address. ${ON_SALE} ` +
      '`from` and `to` are city ids and must differ; `date` is YYYY-MM-DD in India time, from ' +
      'today up to 90 days ahead. Filters: departureWindows, busTypes, ac, operatorIds, ' +
      'amenities (comma-separated lists), minFare / maxFare (paise), passengers. Sorting: ' +
      'DEPARTURE_EARLIEST (default), DEPARTURE_LATEST, FARE_LOWEST, FARE_HIGHEST, ' +
      'DURATION_SHORTEST. Paginated (meta.page, pageSize, total).',
  })
  @ApiResponse({ status: 200, description: 'Trips on sale (paginated)' })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  @ApiResponse({ status: 429, description: 'RATE_LIMITED (details.retryAfterSeconds)' })
  search(
    @Query() query: TripSearchQueryDto,
    @Req() request: Request,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<PaginatedResult<TripSummaryView>> {
    return this.discovery.search(
      query,
      preferredLanguage(acceptLanguage),
      clientRequestInfo(request).ip,
    );
  }

  @Get('search/filters')
  @ApiOperation({
    summary: 'What a search can be filtered by',
    description:
      `Public. ${ON_SALE} For the same from / to / date as a search: the bus types, operators, ` +
      'amenities and departure windows that occur in it, each with the number of trips, and ' +
      'the lowest and highest starting fare. Counts describe the unfiltered search.',
  })
  @ApiResponse({ status: 200, description: 'Filter values with counts' })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  filters(
    @Query() query: TripSearchCriteriaDto,
    @Req() request: Request,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<TripSearchFiltersView> {
    return this.discovery.filters(
      query,
      preferredLanguage(acceptLanguage),
      clientRequestInfo(request).ip,
    );
  }

  @Get(':tripId')
  @ApiOperation({
    summary: 'One trip: bus, timings, fare, boarding and dropping points',
    description:
      `Public. ${ON_SALE} Anything else answers RESOURCE_NOT_FOUND. Seat-level availability ` +
      'is served by the seat map (not built yet); this response carries seat totals only.',
  })
  @ApiResponse({ status: 200, description: 'Trip details' })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  describe(
    @Param() params: TripIdParamDto,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<TripDetailView> {
    return this.discovery.describe(params.tripId, preferredLanguage(acceptLanguage));
  }
}
