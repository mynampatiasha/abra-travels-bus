import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CitiesController } from './controllers/cities.controller';
import { CityRepository } from './repositories/city.repository';
import { CITY_MODEL, citySchema } from './schemas/city.schema';
import { CitiesService } from './services/cities.service';

/**
 * `cities` — Supply domain (documentation/architecture.md §5). The catalogue of cities and
 * its public lookup (documentation/discovery.md). Managing cities arrives with the admin portal.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: CITY_MODEL, schema: citySchema }])],
  controllers: [CitiesController],
  providers: [CityRepository, CitiesService],
  exports: [CitiesService, MongooseModule],
})
export class CitiesModule {}
