import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CatalogueIdParamDto } from '../cities/dto/city-admin.dto';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { DocumentTypesManageService } from './kyc_config_admin_manage.service';
import { type DocumentTypeView } from './services/document-types.service';

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
