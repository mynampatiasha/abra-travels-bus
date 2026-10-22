import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { CitiesModule } from '../cities/cities.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { RoutesController } from './controllers/routes.controller';
import { RouteRepository } from './repositories/route.repository';
import {
  RoutesClientController,
  RoutesClientExportController,
} from './routes_client_manage';
import { RoutesClientManageService } from './routes_client_manage.service';
import { ROUTE_MODEL, routeSchema } from './schemas/route.schema';
import { RoutesService } from './services/routes.service';

/**
 * `routes` — Supply domain (documentation/architecture.md §5). The paths operators run
 * between cities (documentation/catalogue-management.md).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: ROUTE_MODEL, schema: routeSchema }]),
    RbacModule,
    CitiesModule,
    OperatorsModule,
    CatalogueSharedModule,
  ],
  controllers: [
    RoutesClientExportController,
    RoutesClientController,
    RoutesController,
  ],
  providers: [RouteRepository, RoutesService, RoutesClientManageService],
  exports: [RouteRepository, RoutesService, RoutesClientManageService, MongooseModule],
})
export class RoutesModule {}
