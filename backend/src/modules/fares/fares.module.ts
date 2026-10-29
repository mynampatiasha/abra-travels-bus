import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { RbacModule } from '../rbac/rbac.module';
import {
  FaresClientController,
  FaresClientExportController,
  fareSchema,
} from './fares_client_manage';
import { FARE_MODEL, FaresClientManageService } from './fares_client_manage.service';

/**
 * `fares` - Supply domain (documentation/architecture.md §5).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: FARE_MODEL, schema: fareSchema }]),
    RbacModule,
    CatalogueSharedModule,
  ],
  controllers: [
    FaresClientExportController,
    FaresClientController,
  ],
  providers: [FaresClientManageService],
  exports: [FaresClientManageService, MongooseModule],
})
export class FaresModule {}
