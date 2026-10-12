import { Schema, type Types } from 'mongoose';
import {
  DOCUMENT_MIME_TYPES,
  type DocumentMimeType,
} from '../../document-types/schemas/document-type.schema';

export const STORED_FILE_MODEL = 'StoredFile';

/**
 * An uploaded document file. The bytes are in storage; this record says who owns it and what it
 * is. Belongs to one operator, so operator staff only ever reach their own files.
 */
export interface StoredFile {
  operatorId: Types.ObjectId;
  /** The document type the file was uploaded for; its rules were checked at upload. */
  documentTypeId: Types.ObjectId;
  uploadedBy: Types.ObjectId;
  /** The name the uploader's device gave, for display only. Never used as a path. */
  originalName: string;
  /** The real type, read from the file's bytes. */
  mimeType: DocumentMimeType;
  sizeBytes: number;
  /** SHA-256 of the bytes (hex), to spot a changed or repeated file. */
  sha256: string;
  /** Where the bytes are in storage. Never sent to clients. */
  storageKey: string;
  /**
   * The onboarding submission the file is part of. A file belongs to at most one submission; an
   * unattached file was uploaded but never used.
   */
  attachedToId?: Types.ObjectId | null;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `stored_files`. */
export const storedFileSchema = new Schema<StoredFile>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    documentTypeId: { type: Schema.Types.ObjectId, required: true },
    uploadedBy: { type: Schema.Types.ObjectId, required: true },
    originalName: { type: String, required: true, trim: true, maxlength: 200 },
    mimeType: { type: String, enum: DOCUMENT_MIME_TYPES, required: true },
    sizeBytes: { type: Number, required: true, min: 1 },
    sha256: { type: String, required: true, match: /^[0-9a-f]{64}$/ },
    storageKey: { type: String, required: true },
    attachedToId: { type: Schema.Types.ObjectId, default: null },
  },
  { collection: 'stored_files', timestamps: true, versionKey: false },
);

storedFileSchema.index({ storageKey: 1 }, { unique: true });
storedFileSchema.index({ operatorId: 1, createdAt: -1 });
