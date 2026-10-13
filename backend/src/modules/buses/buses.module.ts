import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AmenitiesModule } from '../amenities/amenities_admin_manage';
import { BusTypesModule } from '../bus-types/bus-types.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { BusesController } from './controllers/buses.controller';
import { BusRepository } from './repositories/bus.repository';
import { BUS_MODEL, busSchema } from './schemas/bus.schema';
import { BusesService } from './services/buses.service';

/**
 * `buses` — Supply domain (documentation/architecture.md §5). An operator's vehicles
 * (documentation/catalogue-management.md). Seat layouts arrive with seat inventory.
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: BUS_MODEL, schema: busSchema }]),
    RbacModule,
    BusTypesModule,
    AmenitiesModule,
    OperatorsModule,
  ],
  controllers: [BusesController],
  providers: [BusRepository, BusesService],
  exports: [BusRepository, MongooseModule],
})
export class BusesModule {}
