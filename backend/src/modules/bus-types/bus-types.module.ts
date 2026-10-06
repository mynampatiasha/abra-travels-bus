import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { BusTypesController } from './controllers/bus-types.controller';
import { BusTypeRepository } from './repositories/bus-type.repository';
import { BUS_TYPE_MODEL, busTypeSchema } from './schemas/bus-type.schema';
import { BusTypesService } from './services/bus-types.service';

/**
 * `bus-types` — Supply domain (documentation/architecture.md §5). The kinds of bus, managed
 * by platform staff (documentation/catalogue-management.md).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: BUS_TYPE_MODEL, schema: busTypeSchema }]),
    RbacModule,
  ],
  controllers: [BusTypesController],
  providers: [BusTypeRepository, BusTypesService],
  exports: [BusTypeRepository, MongooseModule],
})
export class BusTypesModule {}
