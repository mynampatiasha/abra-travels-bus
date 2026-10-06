import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CitiesModule } from '../cities/cities.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { RoutesController } from './controllers/routes.controller';
import { RouteRepository } from './repositories/route.repository';
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
  ],
  controllers: [RoutesController],
  providers: [RouteRepository, RoutesService],
  exports: [RouteRepository, MongooseModule],
})
export class RoutesModule {}
