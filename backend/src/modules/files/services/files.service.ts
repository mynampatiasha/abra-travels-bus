import { createHash, randomUUID } from 'node:crypto';
import { type Readable } from 'node:stream';
import { Inject, Injectable } from '@nestjs/common';
import { type ClientSession, Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { DocumentTypeRepository } from '../../document-types/repositories/document-type.repository';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { type UploadFileDto } from '../dto/file.dto';
import {
  StoredFileRepository,
  type StoredFileRecord,
} from '../repositories/stored-file.repository';
import { FILE_EXTENSIONS, detectMimeType } from '../storage/file-signature';
import { FILE_STORAGE, type FileStorage } from '../storage/file-storage';

const BYTES_PER_MB = 1024 * 1024;

export interface FileView {
  id: string;
  operatorId: string;
  documentTypeId: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  uploadedAt: string;
}

export function fileViewOf(file: StoredFileRecord): FileView {
  return {
    id: file._id.toHexString(),
    operatorId: file.operatorId.toHexString(),
    documentTypeId: file.documentTypeId.toHexString(),
    originalName: file.originalName,
    mimeType: file.mimeType,
    sizeBytes: file.sizeBytes,
    uploadedAt: (file.createdAt ?? new Date()).toISOString(),
  };
}

/** The uploaded file as the multipart parser hands it over. */
export interface IncomingFile {
  originalname: string;
  size: number;
  buffer: Buffer;
}

/**
 * Receives, checks and stores document files, and serves them back only to people allowed to see
 * them. A file is checked against the rules of the document type it is uploaded for: size, and
 * its real type read from the bytes. Reaching a file is limited to the operator that owns it
 * (and platform staff) by the repository's data scope.
 */
@Injectable()
export class FilesService {
  constructor(
    private readonly files: StoredFileRepository,
    private readonly documentTypes: DocumentTypeRepository,
    private readonly operators: OperatorRepository,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
  ) {}

  async upload(
    actor: AuthenticatedUserActor,
    input: UploadFileDto,
    file: IncomingFile | undefined,
  ): Promise<FileView> {
    if (!file) {
      throw new ApiException('VALIDATION_FAILED', 'Attach the file in the "file" field.');
    }
    if (file.size === 0) throw new ApiException('VALIDATION_FAILED', 'The file is empty.');

    const operatorId = input.operatorId ?? actor.operatorId;
    if (!operatorId) {
      throw new ApiException('VALIDATION_FAILED', 'Say which operator this file belongs to.');
    }
    // Scoped: an operator's staff cannot name another operator (reads as "not found")
    await this.operators.getById(operatorId);

    const documentType = await this.documentTypes.findById(input.documentTypeId);
    if (!documentType?.isActive) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Document type not found');
    }
    if (file.size > documentType.maxFileSizeMb * BYTES_PER_MB) {
      throw new ApiException(
        'PAYLOAD_TOO_LARGE',
        `This file is larger than the ${documentType.maxFileSizeMb} MB allowed for ${documentType.name}.`,
      );
    }
    const mimeType = detectMimeType(file.buffer);
    if (!mimeType || !documentType.allowedMimeTypes.includes(mimeType)) {
      throw new ApiException(
        'UNSUPPORTED_MEDIA_TYPE',
        `${documentType.name} accepts ${documentType.allowedMimeTypes
          .map((type) => FILE_EXTENSIONS[type].toUpperCase())
          .join(', ')} files only.`,
      );
    }

    const storageKey = `${operatorId}/${randomUUID()}.${FILE_EXTENSIONS[mimeType]}`;
    await this.storage.put(storageKey, file.buffer, mimeType);
    try {
      const stored = await this.files.insertOne({
        operatorId: new Types.ObjectId(operatorId),
        documentTypeId: documentType._id,
        uploadedBy: new Types.ObjectId(actor.userId),
        originalName: displayNameOf(file.originalname, FILE_EXTENSIONS[mimeType]),
        mimeType,
        sizeBytes: file.size,
        sha256: createHash('sha256').update(file.buffer).digest('hex'),
        storageKey,
      });
      return fileViewOf(stored);
    } catch (error) {
      // no record, so nothing could ever reach the bytes: do not leave them behind
      await this.storage.remove(storageKey);
      throw error;
    }
  }

  /**
   * Puts uploaded files into an onboarding submission. Each must exist in the caller's scope, belong
   * to `operatorId`, have been uploaded for `documentTypeId` and not be part of another
   * submission. Runs in the caller's transaction.
   */
  async attachToSubmission(
    input: {
      ids: readonly string[];
      operatorId: Types.ObjectId;
      documentTypeId: Types.ObjectId;
      submissionId: Types.ObjectId;
    },
    session: ClientSession,
  ): Promise<StoredFileRecord[]> {
    const ids = [...new Set(input.ids)];
    const found = await this.files.findMany({ _id: { $in: ids } }, { session });
    if (found.length !== ids.length) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'One of the files was not found. Upload it again.',
      );
    }
    for (const file of found) {
      if (!file.operatorId.equals(input.operatorId)) {
        throw new ApiException(
          'VALIDATION_FAILED',
          'One of the files belongs to another operator.',
        );
      }
      if (!file.documentTypeId.equals(input.documentTypeId)) {
        throw new ApiException(
          'VALIDATION_FAILED',
          `"${file.originalName}" was uploaded for a different document.`,
        );
      }
      if (file.attachedToId && !file.attachedToId.equals(input.submissionId)) {
        throw new ApiException('VALIDATION_FAILED', `"${file.originalName}" is already in use.`);
      }
    }
    await this.files.setAttachment(
      found.map((file) => file._id),
      input.submissionId,
      session,
    );
    return ids.map((id) => found.find((file) => file._id.toHexString() === id) as StoredFileRecord);
  }

  /** Frees files that are no longer part of a submission. */
  releaseFromSubmission(ids: readonly Types.ObjectId[], session: ClientSession): Promise<void> {
    return this.files.setAttachment(ids, null, session);
  }

  /** The files with these ids that the caller may see, in the order asked. */
  async describeMany(ids: readonly Types.ObjectId[]): Promise<FileView[]> {
    if (ids.length === 0) return [];
    const found = await this.files.findMany({ _id: { $in: [...ids] } });
    return ids.flatMap((id) => {
      const file = found.find((candidate) => candidate._id.equals(id));
      return file ? [fileViewOf(file)] : [];
    });
  }

  async describe(id: string): Promise<FileView> {
    return fileViewOf(await this.files.getById(id));
  }

  /** The file's bytes, for a person whose scope includes the owning operator. */
  async open(id: string): Promise<{ file: StoredFileRecord; content: Readable }> {
    const file = await this.files.getById(id);
    return { file, content: await this.storage.open(file.storageKey) };
  }
}

/**
 * A safe name to show: no folders, no control characters, bounded length. Multer reads names as
 * Latin-1, so a UTF-8 name (Indian-language file names) is decoded back first.
 */
export function displayNameOf(rawName: string, extension: string): string {
  const decoded = Buffer.from(rawName, 'latin1').toString('utf8');
  const name = (decoded.includes('�') ? rawName : decoded)
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .split(/[\\/]/)
    .pop()
    ?.trim()
    .slice(0, 200);
  return name && name !== '.' && name !== '..' ? name : `document.${extension}`;
}
