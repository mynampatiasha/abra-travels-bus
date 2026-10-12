import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { STORED_FILE_MODEL, type StoredFile } from '../schemas/stored-file.schema';

export type StoredFileRecord = StoredDocument<StoredFile>;

/** `stored_files`, restricted to the operators in the actor's data scope. */
@Injectable()
export class StoredFileRepository extends ScopedRepository<StoredFile> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(STORED_FILE_MODEL) model: Model<StoredFile>) {
    super(model);
  }

  /** Records which submission the files belong to (`null` frees them). Only files in scope. */
  async setAttachment(
    ids: readonly Types.ObjectId[],
    submissionId: Types.ObjectId | null,
    session: ClientSession,
  ): Promise<void> {
    if (ids.length === 0) return;
    await this.model
      .updateMany(await this.scopedFilter({ _id: { $in: [...ids] } }, session), {
        $set: { attachedToId: submissionId },
      })
      .session(session)
      .exec();
  }
}
