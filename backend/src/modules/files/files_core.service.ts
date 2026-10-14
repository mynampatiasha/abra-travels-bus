import { createHash, randomUUID } from 'node:crypto';
import { type Readable } from 'node:stream';
import { Inject, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type ScopeFields } from '../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../database/scoped-repository.base';
import { displayNameOf, type IncomingFile } from './services/files.service';
import { detectMimeType } from './storage/file-signature';
import { FILE_STORAGE, type FileStorage } from './storage/file-storage';

/*
 * Proof files: the picture, PDF or text note a person attaches to a sensitive action (cancel a
 * trip, reject a refund, block a customer, hold a settlement...). Same storage as the documents of
 * the onboarding, but their own collection and rules: up to 5 files per action, 600 KB each.
 * A proof is seen by Abra staff, by the operator it concerns, by the person who uploaded it and by
 * the people the action names (for example the customer a booking belongs to).
 */

export const PROOF_FILE_MODEL = 'ProofFile';

/** Most files one action can carry. */
export const MAX_PROOFS_PER_SUBJECT = 5;
/** Largest proof file (600 KB), as the demos allow. */
export const MAX_PROOF_BYTES = 600 * 1024;

export const PROOF_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'application/pdf',
  'text/plain',
] as const;
export type ProofMimeType = (typeof PROOF_MIME_TYPES)[number];

const PROOF_EXTENSIONS: Readonly<Record<ProofMimeType, string>> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'application/pdf': 'pdf',
  'text/plain': 'txt',
};

export interface ProofFile {
  uploadedBy: Types.ObjectId;
  /** Operator the proof concerns; operator staff reach only their own operator's proofs. */
  operatorId?: Types.ObjectId;
  originalName: string;
  mimeType: ProofMimeType;
  sizeBytes: number;
  sha256: string;
  /** Where the bytes are in storage. Never sent to clients. */
  storageKey: string;
  /** What the proof belongs to, once attached (for example `trip-cancel` and the trip id). */
  subjectType?: string | null;
  subjectId?: Types.ObjectId | null;
  /** People other than the uploader who may open it (for example the customer concerned). */
  sharedWith: Types.ObjectId[];
  createdAt?: Date;
  updatedAt?: Date;
}

/** `proof_files`. */
export const proofFileSchema = new Schema<ProofFile>(
  {
    uploadedBy: { type: Schema.Types.ObjectId, required: true },
    operatorId: { type: Schema.Types.ObjectId },
    originalName: { type: String, required: true, trim: true, maxlength: 200 },
    mimeType: { type: String, enum: PROOF_MIME_TYPES, required: true },
    sizeBytes: { type: Number, required: true, min: 1, max: MAX_PROOF_BYTES },
    sha256: { type: String, required: true, match: /^[0-9a-f]{64}$/ },
    storageKey: { type: String, required: true },
    subjectType: { type: String, maxlength: 60, default: null },
    subjectId: { type: Schema.Types.ObjectId, default: null },
    sharedWith: { type: [Schema.Types.ObjectId], default: [] },
  },
  { collection: 'proof_files', timestamps: true, versionKey: false },
);
proofFileSchema.index({ storageKey: 1 }, { unique: true });
proofFileSchema.index({ subjectType: 1, subjectId: 1 });
proofFileSchema.index({ uploadedBy: 1, createdAt: -1 });
proofFileSchema.index({ sharedWith: 1 });

export type ProofFileRecord = StoredDocument<ProofFile>;

export interface ProofFileView {
  id: string;
  originalName: string;
  mimeType: ProofMimeType;
  sizeBytes: number;
  attached: boolean;
  uploadedAt: string;
}

export function proofViewOf(file: ProofFileRecord): ProofFileView {
  return {
    id: file._id.toHexString(),
    originalName: file.originalName,
    mimeType: file.mimeType,
    sizeBytes: file.sizeBytes,
    attached: Boolean(file.subjectId),
    uploadedAt: (file.createdAt ?? new Date()).toISOString(),
  };
}

/** What an action says about the proofs it attaches. */
export interface ProofSubject {
  /** A short name of the kind of action, e.g. `trip-cancel`. */
  type: string;
  id: Types.ObjectId;
  operatorId?: Types.ObjectId | undefined;
  /** People who concern the action and may open its proofs (the customer, the owner...). */
  shareWith?: readonly Types.ObjectId[] | undefined;
}

/**
 * `proof_files`, read through the data scope: platform staff see all, operator staff their own
 * operator's, anyone else their own uploads. People an action names are let in by [findShared].
 */
@Injectable()
export class ProofFileRepository extends ScopedRepository<ProofFile> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId', owner: 'uploadedBy' };

  constructor(@InjectModel(PROOF_FILE_MODEL) model: Model<ProofFile>) {
    super(model);
  }

  /** A proof that was shared with this person, outside the scope they otherwise have. */
  findShared(id: string, userId: string): Promise<ProofFileRecord | null> {
    if (!Types.ObjectId.isValid(id) || !Types.ObjectId.isValid(userId))
      return Promise.resolve(null);
    return this.model
      .findOne({ _id: id, sharedWith: new Types.ObjectId(userId) })
      .lean<ProofFileRecord>()
      .exec();
  }

  /** Proofs of one action, whoever may see them: the caller decides what to show. */
  findBySubject(
    subjectType: string,
    subjectId: Types.ObjectId,
    session?: ClientSession,
  ): Promise<ProofFileRecord[]> {
    return this.model
      .find({ subjectType, subjectId }, null, { session })
      .sort({ createdAt: 1 })
      .lean<ProofFileRecord[]>()
      .exec();
  }

  /** Marks proofs as belonging to an action. Only unattached ones, or ones of the same action. */
  async setSubject(
    ids: readonly Types.ObjectId[],
    subject: ProofSubject,
    session: ClientSession | undefined,
  ): Promise<number> {
    const result = await this.model
      .updateMany(
        {
          _id: { $in: [...ids] },
          $or: [{ subjectId: null }, { subjectType: subject.type, subjectId: subject.id }],
        },
        {
          $set: {
            subjectType: subject.type,
            subjectId: subject.id,
            ...(subject.operatorId ? { operatorId: subject.operatorId } : {}),
          },
          ...(subject.shareWith?.length
            ? { $addToSet: { sharedWith: { $each: [...subject.shareWith] } } }
            : {}),
        },
        { session },
      )
      .exec();
    return result.matchedCount;
  }
}

/** Whether the bytes are plain text a person can read: valid UTF-8, no NUL, few control characters. */
export function looksLikeText(data: Buffer): boolean {
  if (data.includes(0)) return false;
  let text: string;
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(data);
  } catch {
    return false;
  }
  // eslint-disable-next-line no-control-regex
  return !/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text);
}

@Injectable()
export class ProofFilesService {
  constructor(
    private readonly proofs: ProofFileRepository,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
  ) {}

  /** Checks and stores one proof file. It stays unattached until an action attaches it. */
  async upload(
    actor: AuthenticatedUserActor,
    file: IncomingFile | undefined,
  ): Promise<ProofFileView> {
    if (!file) throw new ApiException('VALIDATION_FAILED', 'Attach the file in the "file" field.');
    if (file.size === 0) throw new ApiException('VALIDATION_FAILED', 'The file is empty.');
    if (file.size > MAX_PROOF_BYTES) {
      throw new ApiException(
        'PAYLOAD_TOO_LARGE',
        `A proof file can be at most ${MAX_PROOF_BYTES / 1024} KB.`,
      );
    }
    const mimeType: ProofMimeType | undefined =
      detectMimeType(file.buffer) ?? (looksLikeText(file.buffer) ? 'text/plain' : undefined);
    if (!mimeType) {
      throw new ApiException(
        'UNSUPPORTED_MEDIA_TYPE',
        'A proof can be a picture (JPG or PNG), a PDF or a text file.',
      );
    }

    const storageKey = `proofs/${randomUUID()}.${PROOF_EXTENSIONS[mimeType]}`;
    await this.storage.put(storageKey, file.buffer, mimeType);
    try {
      const stored = await this.proofs.insertOne({
        uploadedBy: new Types.ObjectId(actor.userId),
        ...(actor.operatorId ? { operatorId: new Types.ObjectId(actor.operatorId) } : {}),
        originalName: displayNameOf(file.originalname, PROOF_EXTENSIONS[mimeType]),
        mimeType,
        sizeBytes: file.size,
        sha256: createHash('sha256').update(file.buffer).digest('hex'),
        storageKey,
        sharedWith: [],
      });
      return proofViewOf(stored);
    } catch (error) {
      await this.storage.remove(storageKey);
      throw error;
    }
  }

  async describe(actor: AuthenticatedUserActor, id: string): Promise<ProofFileView> {
    return proofViewOf(await this.accessible(actor, id));
  }

  /** The bytes of a proof, for someone who may see it. */
  async open(
    actor: AuthenticatedUserActor,
    id: string,
  ): Promise<{ file: ProofFileRecord; content: Readable }> {
    const file = await this.accessible(actor, id);
    return { file, content: await this.storage.open(file.storageKey) };
  }

  /**
   * Fails early, before an action changes anything, when its proofs are not acceptable: at most
   * five, no repeats, all of them uploaded and visible to the caller. Features call this first.
   */
  async check(ids: readonly string[] | undefined): Promise<Types.ObjectId[]> {
    const unique = [...new Set(ids ?? [])];
    if (unique.length > MAX_PROOFS_PER_SUBJECT) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `Attach at most ${MAX_PROOFS_PER_SUBJECT} proof files.`,
      );
    }
    if (unique.length === 0) return [];
    if (unique.some((id) => !Types.ObjectId.isValid(id))) {
      throw new ApiException('VALIDATION_FAILED', 'One of the proof files was not found.');
    }
    const found = await this.proofs.findMany({ _id: { $in: unique } });
    if (found.length !== unique.length) {
      throw new ApiException('VALIDATION_FAILED', 'One of the proof files was not found.');
    }
    return unique.map((id) => new Types.ObjectId(id));
  }

  /**
   * Attaches proofs to an action (call it inside the action's transaction). A proof can belong to
   * one action only; the action can carry at most five.
   */
  async attach(
    ids: readonly string[] | undefined,
    subject: ProofSubject,
    session?: ClientSession,
  ): Promise<void> {
    const objectIds = await this.check(ids);
    if (objectIds.length === 0) return;
    const already = await this.proofs.findBySubject(subject.type, subject.id, session);
    const total = new Set([
      ...already.map((file) => file._id.toHexString()),
      ...objectIds.map((id) => id.toHexString()),
    ]).size;
    if (total > MAX_PROOFS_PER_SUBJECT) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `An action can carry at most ${MAX_PROOFS_PER_SUBJECT} proof files.`,
      );
    }
    const matched = await this.proofs.setSubject(objectIds, subject, session);
    if (matched !== objectIds.length) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'A proof file is already used by another action.',
      );
    }
  }

  /** The proofs of one action, newest last. Callers check that the person may see the action. */
  async listFor(subjectType: string, subjectId: Types.ObjectId): Promise<ProofFileView[]> {
    return (await this.proofs.findBySubject(subjectType, subjectId)).map(proofViewOf);
  }

  /** A proof the person may open: in their data scope, or shared with them by an action. */
  private async accessible(actor: AuthenticatedUserActor, id: string): Promise<ProofFileRecord> {
    const inScope = await this.proofs.findById(id);
    if (inScope) return inScope;
    const shared = await this.proofs.findShared(id, actor.userId);
    if (shared) return shared;
    // Not found and not allowed read the same, so ids cannot be probed
    throw new ApiException('RESOURCE_NOT_FOUND', 'Proof file not found');
  }
}
