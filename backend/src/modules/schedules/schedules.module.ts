import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { RbacModule } from '../rbac/rbac.module';
import {
  SchedulesClientController,
  SchedulesClientExportController,
  scheduleSchema,
} from './schedules_client_manage';
import { SCHEDULE_MODEL, SchedulesClientManageService } from './schedules_client_manage.service';

/**
 * `schedules` - Supply domain (documentation/architecture.md §5).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: SCHEDULE_MODEL, schema: scheduleSchema }]),
    RbacModule,
    CatalogueSharedModule,
  ],
  controllers: [
    SchedulesClientExportController,
    SchedulesClientController,
  ],
  providers: [SchedulesClientManageService],
  exports: [SchedulesClientManageService, MongooseModule],
})
export class SchedulesModule {}
