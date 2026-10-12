import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, type Types } from 'mongoose';
import {
  DOCUMENT_TYPE_MODEL,
  type DocumentSubject,
  type DocumentType,
} from '../schemas/document-type.schema';

export type StoredDocumentType = DocumentType & { _id: Types.ObjectId };

/** `document_types`. Platform catalogue without a tenant; access is decided by permission. */
@Injectable()
export class DocumentTypeRepository {
  constructor(@InjectModel(DOCUMENT_TYPE_MODEL) private readonly model: Model<DocumentType>) {}

  findById(
    id: string | Types.ObjectId,
    session?: ClientSession,
  ): Promise<StoredDocumentType | null> {
    return this.model
      .findById(id)
      .session(session ?? null)
      .lean<StoredDocumentType>()
      .exec();
  }

  async list(
    filter: { appliesTo?: DocumentSubject | undefined; active?: boolean | undefined },
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredDocumentType[]; total: number }> {
    const match: QueryFilter<DocumentType> = {
      ...(filter.appliesTo === undefined ? {} : { appliesTo: filter.appliesTo }),
      ...(filter.active === undefined ? {} : { isActive: filter.active }),
    };
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ appliesTo: 1, sortOrder: 1, name: 1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredDocumentType[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  /** Every type currently asked for about `subject`, in display order. */
  activeFor(subject: DocumentSubject, session?: ClientSession): Promise<StoredDocumentType[]> {
    return this.model
      .find({ appliesTo: subject, isActive: true })
      .sort({ sortOrder: 1, name: 1 })
      .session(session ?? null)
      .lean<StoredDocumentType[]>()
      .exec();
  }

  count(): Promise<number> {
    return this.model.estimatedDocumentCount().exec();
  }

  async insert(documentType: DocumentType, session?: ClientSession): Promise<StoredDocumentType> {
    const [created] = await this.model.create([documentType], { session: session ?? null });
    if (!created) throw new Error('Document type was not created');
    return created.toObject();
  }

  update(
    id: Types.ObjectId,
    set: Partial<DocumentType>,
    session: ClientSession,
  ): Promise<StoredDocumentType | null> {
    return this.model
      .findOneAndUpdate(
        { _id: id },
        { $set: set },
        { returnDocument: 'after', session, runValidators: true },
      )
      .lean<StoredDocumentType>()
      .exec();
  }
}
