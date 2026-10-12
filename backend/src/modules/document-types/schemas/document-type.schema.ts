import { Schema } from 'mongoose';

export const DOCUMENT_TYPE_MODEL = 'DocumentType';

/** What a document is attached to: the bus-owning company, or one of its buses. */
export const DOCUMENT_SUBJECTS = ['OPERATOR', 'BUS'] as const;
export type DocumentSubject = (typeof DOCUMENT_SUBJECTS)[number];

/** File formats a document type can accept. Anything else is refused at upload. */
export const DOCUMENT_MIME_TYPES = ['application/pdf', 'image/jpeg', 'image/png'] as const;
export type DocumentMimeType = (typeof DOCUMENT_MIME_TYPES)[number];

/**
 * A kind of document the platform asks for during onboarding, e.g. "Insurance". Managed by
 * platform staff, so what operators must upload changes without a release.
 */
export interface DocumentType {
  /** Stable key, upper snake case. Never changes; `name` is the label people read. */
  key: string;
  name: string;
  appliesTo: DocumentSubject;
  /** A submission cannot be sent for review without every required document. */
  isRequired: boolean;
  /** The document expires (insurance, permit...), so the client must enter an expiry date. */
  requiresExpiry: boolean;
  allowedMimeTypes: DocumentMimeType[];
  maxFileSizeMb: number;
  /** How many files one document may hold, e.g. several bus photos. */
  maxFiles: number;
  /** Shown to the client next to the upload field. */
  instructions: string;
  sortOrder: number;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `document_types`. */
export const documentTypeSchema = new Schema<DocumentType>(
  {
    key: { type: String, required: true, match: /^[A-Z][A-Z0-9_]*$/, maxlength: 40 },
    name: { type: String, required: true, trim: true, maxlength: 80 },
    appliesTo: { type: String, enum: DOCUMENT_SUBJECTS, required: true },
    isRequired: { type: Boolean, required: true },
    requiresExpiry: { type: Boolean, required: true },
    allowedMimeTypes: {
      type: [{ type: String, enum: DOCUMENT_MIME_TYPES }],
      required: true,
      validate: (list: string[]) => list.length > 0,
    },
    maxFileSizeMb: { type: Number, required: true, min: 1, max: 25 },
    maxFiles: { type: Number, required: true, min: 1, max: 10 },
    instructions: { type: String, trim: true, maxlength: 500, default: '' },
    sortOrder: { type: Number, required: true, default: 0 },
    isActive: { type: Boolean, required: true, default: true },
  },
  { collection: 'document_types', timestamps: true, versionKey: false },
);

documentTypeSchema.index({ key: 1 }, { unique: true });
documentTypeSchema.index({ appliesTo: 1, isActive: 1, sortOrder: 1 });
