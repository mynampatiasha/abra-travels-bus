import { Module } from '@nestjs/common';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { CitiesExportController, CitiesImportController } from './cities_admin_manage';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { CitiesAdminController } from './controllers/cities-admin.controller';
import { CitiesController } from './controllers/cities.controller';
import { CityRepository } from './repositories/city.repository';
import { CITY_MODEL, citySchema } from './schemas/city.schema';
import { CitiesAdminService } from './services/cities-admin.service';
import { CitiesService } from './services/cities.service';

/**
 * `cities` — Supply domain (documentation/architecture.md §5). The catalogue of cities: its
 * public lookup (documentation/discovery.md) and its management by platform staff
 * (documentation/catalogue-management.md).
 */
@Module({
  imports: [CatalogueSharedModule, MongooseModule.forFeature([{ name: CITY_MODEL, schema: citySchema }]), RbacModule],
  controllers: [CitiesExportController, CitiesImportController, CitiesController, CitiesAdminController],
  providers: [CityRepository, CitiesService, CitiesAdminService],
  exports: [CitiesService, CityRepository, MongooseModule],
})
export class CitiesModule {}
