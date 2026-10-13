import { Module } from '@nestjs/common';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { DocumentTypesExportController } from './kyc_config_admin_manage';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { DocumentTypesController } from './controllers/document-types.controller';
import { DocumentTypesManageController } from './kyc_config_admin_manage';
import { DocumentTypesManageService } from './kyc_config_admin_manage.service';
import { DocumentTypeRepository } from './repositories/document-type.repository';
import { DOCUMENT_TYPE_MODEL, documentTypeSchema } from './schemas/document-type.schema';
import { DocumentTypeSeeder } from './services/document-type-seeder.service';
import { DocumentTypesService } from './services/document-types.service';

/**
 * `document-types` — Supply domain (documentation/architecture.md §5). The documents a bus
 * operator and its buses must provide to be approved, managed by platform staff
 * (documentation/client-onboarding.md).
 */
@Module({
  imports: [CatalogueSharedModule, 
    MongooseModule.forFeature([{ name: DOCUMENT_TYPE_MODEL, schema: documentTypeSchema }]),
    RbacModule,
  ],
  controllers: [DocumentTypesExportController, DocumentTypesController, DocumentTypesManageController],
  providers: [
    DocumentTypeRepository,
    DocumentTypesService,
    DocumentTypeSeeder,
    DocumentTypesManageService,
  ],
  exports: [DocumentTypeRepository, MongooseModule],
})
export class DocumentTypesModule {}
