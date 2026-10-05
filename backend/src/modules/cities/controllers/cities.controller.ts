import { Controller, Get, Headers, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { preferredLanguage } from '../../../common/http/preferred-language';
import { CityQueryDto } from '../dto/city-query.dto';
import { CitiesService, type CityView } from '../services/cities.service';

@ApiTags('discovery')
@PublicEndpoint()
@Controller('cities')
export class CitiesController {
  constructor(private readonly cities: CitiesService) {}

  @Get()
  @ApiOperation({
    summary: 'Cities to travel from and to',
    description:
      'Public. With `query`: active cities whose name starts with it (English name, or the ' +
      'name in the Accept-Language language). Without `query`: the popular cities. Names are ' +
      'returned in the Accept-Language language when a translation exists.',
  })
  @ApiResponse({ status: 200, description: 'Cities: id, name, state, slug' })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  search(
    @Query() query: CityQueryDto,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<CityView[]> {
    return this.cities.search(query.query, preferredLanguage(acceptLanguage), query.limit);
  }
}
