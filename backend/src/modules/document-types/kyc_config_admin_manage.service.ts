import { Injectable } from '@nestjs/common';
import { ApiException } from '../../common/errors/api-exception';
import { DocumentTypeRepository } from './repositories/document-type.repository';
import { type DocumentTypeView, documentTypeViewOf } from './services/document-types.service';

/** Reading one document type for the detail window of the admin page. */
@Injectable()
export class DocumentTypesManageService {
  constructor(private readonly types: DocumentTypeRepository) {}

  async get(id: string): Promise<DocumentTypeView> {
    const found = await this.types.findById(id);
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Document type not found');
    return documentTypeViewOf(found);
  }
}
