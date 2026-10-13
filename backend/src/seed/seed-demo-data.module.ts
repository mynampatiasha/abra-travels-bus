import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { LoggerModule } from 'nestjs-pino';
import { createLoggerOptions } from '../common/logging/logger-options.factory';
import { AppConfigModule } from '../config/app-config.module';
import { AppConfigService } from '../config/app-config.service';
import { DatabaseModule } from '../database/database.module';
import { BUS_TYPE_MODEL, busTypeSchema } from '../modules/bus-types/schemas/bus-type.schema';
import { BUS_MODEL, busSchema } from '../modules/buses/schemas/bus.schema';
import { CITY_MODEL, citySchema } from '../modules/cities/schemas/city.schema';
import { LOCATION_MODEL, locationSchema } from '../modules/locations/schemas/location.schema';
import { OPERATOR_MODEL, operatorSchema } from '../modules/operators/schemas/operator.schema';
import { SeedDemoDataService } from './seed-demo-data.service';

/** What the seed command needs and nothing more: configuration, the database and five models. */
@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRootAsync({ inject: [AppConfigService], useFactory: createLoggerOptions }),
    DatabaseModule,
    MongooseModule.forFeature([
      { name: CITY_MODEL, schema: citySchema },
      { name: LOCATION_MODEL, schema: locationSchema },
      { name: BUS_TYPE_MODEL, schema: busTypeSchema },
      { name: OPERATOR_MODEL, schema: operatorSchema },
      { name: BUS_MODEL, schema: busSchema },
    ]),
  ],
  providers: [SeedDemoDataService],
  exports: [SeedDemoDataService],
})
export class SeedDemoDataModule {}
