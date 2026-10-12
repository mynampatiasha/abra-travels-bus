import { Injectable } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { rejectDuplicates } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type CreateDocumentTypeDto,
  type DocumentTypeListQueryDto,
  type UpdateDocumentTypeDto,
} from '../dto/document-type.dto';
import {
  DocumentTypeRepository,
  type StoredDocumentType,
} from '../repositories/document-type.repository';
import { type DocumentType } from '../schemas/document-type.schema';

export interface DocumentTypeView {
  id: string;
  key: string;
  name: string;
  appliesTo: string;
  isRequired: boolean;
  requiresExpiry: boolean;
  allowedMimeTypes: string[];
  maxFileSizeMb: number;
  maxFiles: number;
  instructions: string;
  sortOrder: number;
  isActive: boolean;
}

export function documentTypeViewOf(type: StoredDocumentType): DocumentTypeView {
  return {
    id: type._id.toHexString(),
    key: type.key,
    name: type.name,
    appliesTo: type.appliesTo,
    isRequired: type.isRequired,
    requiresExpiry: type.requiresExpiry,
    allowedMimeTypes: [...type.allowedMimeTypes],
    maxFileSizeMb: type.maxFileSizeMb,
    maxFiles: type.maxFiles,
    instructions: type.instructions,
    sortOrder: type.sortOrder,
    isActive: type.isActive,
  };
}

const EDITABLE_FIELDS = [
  'name',
  'isRequired',
  'requiresExpiry',
  'allowedMimeTypes',
  'maxFileSizeMb',
  'maxFiles',
  'instructions',
  'sortOrder',
  'isActive',
] as const;

/**
 * The documents operators must provide to be approved (company documents and per-bus
 * documents). Platform staff decide the list; operators only read the active entries.
 */
@Injectable()
export class DocumentTypesService {
  constructor(
    private readonly types: DocumentTypeRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(
    query: DocumentTypeListQueryDto,
    options: { activeOnly: boolean },
  ): Promise<PaginatedResult<DocumentTypeView>> {
    const { items, total } = await this.types.list(
      { appliesTo: query.appliesTo, active: options.activeOnly ? true : query.active },
      { skip: skipOf(query), limit: query.pageSize },
    );
    return new PaginatedResult(items.map(documentTypeViewOf), query.page, query.pageSize, total);
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateDocumentTypeDto,
    client: ClientRequestInfo,
  ): Promise<DocumentTypeView> {
    const created = await rejectDuplicates('A document type with this key already exists.', () =>
      this.changes.run({
        actor,
        client,
        action: 'catalogue.created',
        entityType: 'document_type',
        before: {},
        apply: (session) => this.types.insert({ ...input, isActive: true }, session),
        describe: (record) => ({ ...documentTypeViewOf(record) }),
      }),
    );
    return documentTypeViewOf(created);
  }

  /**
   * Documents already collected keep the rules they were uploaded under; a changed rule applies
   * to uploads from now on. `key` and `appliesTo` never change.
   */
  async update(
    actor: AuthenticatedUserActor,
    id: string,
    change: UpdateDocumentTypeDto & { isActive?: boolean },
    client: ClientRequestInfo,
  ): Promise<DocumentTypeView> {
    const before = await this.types.findById(id);
    if (!before) throw new ApiException('RESOURCE_NOT_FOUND', 'Document type not found');
    const set: Partial<DocumentType> = {};
    for (const field of EDITABLE_FIELDS) {
      if (change[field] !== undefined) Object.assign(set, { [field]: change[field] });
    }
    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    const updated = await this.changes.run({
      actor,
      client,
      action: change.isActive === undefined ? 'catalogue.updated' : 'catalogue.status-changed',
      entityType: 'document_type',
      before: { ...documentTypeViewOf(before) },
      apply: async (session) => {
        const saved = await this.types.update(before._id, set, session);
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Document type not found');
        return saved;
      },
      describe: (record) => ({ ...documentTypeViewOf(record) }),
    });
    return documentTypeViewOf(updated);
  }
}
