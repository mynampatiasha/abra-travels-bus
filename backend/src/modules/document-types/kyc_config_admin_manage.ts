import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CatalogueIdParamDto } from '../cities/dto/city-admin.dto';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { DocumentTypesManageService } from './kyc_config_admin_manage.service';
import { type DocumentTypeView } from './services/document-types.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind } from '../catalogue-shared/catalogue_export_manage.service';
import { DocumentTypeListQueryDto } from './dto/document-type.dto';
import { DocumentTypesService } from './services/document-types.service';

/** Required documents page of the admin portal: the routes the list does not have. */
@ApiTags('catalogue')
@Controller('catalogue/document-types')
export class DocumentTypesManageController {
  constructor(private readonly manage: DocumentTypesManageService) {}

  @Get(':id')
  @RequirePermission('documents.read')
  @ApiOperation({
    summary: 'One document type',
    description: 'Requires documents.read. A deleted document type is not found.',
  })
  get(@Param() params: CatalogueIdParamDto): Promise<DocumentTypeView> {
    return this.manage.get(params.id);
  }
}

/** The required documents list as a file. */
export const DOCUMENT_TYPES_EXPORT_KIND: ExportKind<DocumentTypeView> = {
  key: 'document-types',
  columns: [
    { header: 'Document', value: (type) => type.name },
    { header: 'Key', value: (type) => type.key },
    { header: 'For', value: (type) => (type.appliesTo === 'BUS' ? 'Bus' : 'Operator') },
    { header: 'Required', value: (type) => type.isRequired },
    { header: 'Has expiry', value: (type) => type.requiresExpiry },
    { header: 'File types', value: (type) => type.allowedMimeTypes.join(', ') },
    { header: 'Max size (MB)', value: (type) => type.maxFileSizeMb },
    { header: 'Max files', value: (type) => type.maxFiles },
    { header: 'Instructions', value: (type) => type.instructions },
    { header: 'Status', value: (type) => (type.isActive ? 'Active' : 'Inactive') },
  ],
};

/** `GET catalogue/document-types/export`. Register it before the module's other controllers. */
export const DocumentTypesExportController = exportController({
  base: 'catalogue/document-types',
  permission: 'documents.export',
  kind: DOCUMENT_TYPES_EXPORT_KIND,
  service: DocumentTypesService,
  query: DocumentTypeListQueryDto,
  title: 'required documents',
  // The admin list shows every type, active or not
  load: (service, query) => service.list(query as never, { activeOnly: false }),
});
