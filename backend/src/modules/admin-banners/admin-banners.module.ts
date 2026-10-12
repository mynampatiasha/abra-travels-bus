import { Module } from '@nestjs/common';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { BannersExportController } from './banners_admin_manage';
import { MongooseModule } from '@nestjs/mongoose';
import { AppConfigService } from '../../config/app-config.service';
import { createFileStorage } from '../files/files.module';
import { FILE_STORAGE } from '../files/storage/file-storage';
import { RbacModule } from '../rbac/rbac.module';
import { AdminBannersController, PublicBannersController } from './admin-banners.controller';
import { BANNER_MODEL, bannerSchema } from './admin-banners.model';
import { AdminBannersService } from './admin-banners.service';
import { BannersManageController } from './banners_admin_manage';
import { BannersManageService } from './banners_admin_manage.service';

/**
 * `banners` — Content domain (documentation/architecture.md §5). Promotional banners managed by
 * platform staff and shown, while live, at the top of the customer app.
 */
@Module({
  imports: [CatalogueSharedModule, MongooseModule.forFeature([{ name: BANNER_MODEL, schema: bannerSchema }]), RbacModule],
  controllers: [BannersExportController, AdminBannersController, BannersManageController, PublicBannersController],
  providers: [
    AdminBannersService,
    BannersManageService,
    { provide: FILE_STORAGE, inject: [AppConfigService], useFactory: createFileStorage },
  ],
})
export class AdminBannersModule {}
