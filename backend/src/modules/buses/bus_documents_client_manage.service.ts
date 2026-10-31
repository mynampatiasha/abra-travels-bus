import { createHash, randomUUID } from 'node:crypto';
import { type Readable } from 'node:stream';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type HydratedDocument, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { normalizePhoneNumber } from '../../common/validation/contact-identifiers';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { OutboxService } from '../../events/outbox.service';
import { displayNameOf, type IncomingFile } from '../files/services/files.service';
import { detectMimeType } from '../files/storage/file-signature';
import { FILE_STORAGE, type FileStorage } from '../files/storage/file-storage';
import { daysLeftOf, parseDay } from '../operator-staff/crew_documents_client_manage.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';

/*
 * Documents of a bus (RC, insurance, permit, fitness, pollution, tax, or any the owner names):
 * several documents per bus, several files per document, each with its own expiry date and its own
 * reminder days. The owner can rename, replace and delete them. The people who run the bus (its usual
 * driver and conductor, and whoever is on its upcoming trips) are told when one is about to expire and can
 * open the documents of their bus. Files go to the same private storage as the other uploads.
 */

// ===== 1. RULES =====

export const BUS_DOC_TYPES = ['RC', 'INSURANCE', 'PERMIT', 'FITNESS', 'POLLUTION', 'ROAD_TAX', 'OTHER'] as const;
export type BusDocType = (typeof BUS_DOC_TYPES)[number];

export const BUS_DOC_LABELS: Readonly<Record<BusDocType, string>> = {
  RC: 'Registration certificate (RC)',
  INSURANCE: 'Insurance',
  PERMIT: 'Permit',
  FITNESS: 'Fitness certificate',
  POLLUTION: 'Pollution certificate (PUC)',
  ROAD_TAX: 'Road tax',
  OTHER: 'Other',
};

/** The documents a bus must have before its trips can go on sale. */
export const REQUIRED_BUS_DOC_TYPES: readonly BusDocType[] = ['RC', 'INSURANCE', 'PERMIT', 'FITNESS'];

export const MAX_FILES_PER_BUS_DOC = 10;
export const MAX_BUS_DOC_BYTES = 5 * 1024 * 1024;
/** Days before the expiry date when a reminder goes out, unless the owner chooses others. */
export const DEFAULT_REMIND_DAYS: readonly number[] = [30, 15, 7, 1];
const MAX_REMIND_DAYS = 6;
const BUS_DOC_MIME_TYPES = ['application/pdf', 'image/jpeg', 'image/png'] as const;
const EXTENSIONS: Readonly<Record<string, string>> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};
const DAY_MS = 24 * 60 * 60 * 1000;
export const BUS_DOCUMENT_EXPIRING_EVENT = 'bus.document-expiring';

export const BUS_DOCUMENT_MODEL = 'bus_documents';
export const BUS_DOC_REMINDER_MODEL = 'bus_document_reminders';

// ===== 2. STORED SHAPES =====

export interface BusDocFile {
  fileId: string;
  storageKey: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  uploadedAt: Date;
}

export interface BusDocumentRecord {
  operatorId: Types.ObjectId;
  busId: Types.ObjectId;
  docType: BusDocType;
  docName: string;
  validTill: Date;
  /** Days before `validTill` when reminders go out. */
  remindDaysBefore: number[];
  files: BusDocFile[];
  isDeleted?: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredBusDocument = BusDocumentRecord & { _id: Types.ObjectId };

const BusDocFileSchema = new Schema<BusDocFile>(
  {
    fileId: { type: String, required: true },
    storageKey: { type: String, required: true },
    originalName: { type: String, required: true },
    mimeType: { type: String, required: true },
    sizeBytes: { type: Number, required: true },
    sha256: { type: String, required: true },
    uploadedAt: { type: Date, required: true },
  },
  { _id: false },
);

export const BusDocumentSchema = new Schema<BusDocumentRecord>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true, index: true },
    busId: { type: Schema.Types.ObjectId, required: true, index: true },
    docType: { type: String, enum: BUS_DOC_TYPES, required: true },
    docName: { type: String, required: true, trim: true, maxlength: 100 },
    validTill: { type: Date, required: true },
    remindDaysBefore: { type: [Number], default: () => [...DEFAULT_REMIND_DAYS] },
    files: { type: [BusDocFileSchema], default: [] },
    isDeleted: { type: Boolean, default: false, index: true },
  },
  { timestamps: true, collection: 'bus_documents' },
);
BusDocumentSchema.index({ operatorId: 1, validTill: 1 });

export interface BusReminderRecord {
  key: string;
  createdAt: Date;
}

/** One row per reminder already sent, so a restart or a second worker never repeats it. */
export const BusDocReminderSchema = new Schema<BusReminderRecord>(
  { key: { type: String, required: true, unique: true } },
  { timestamps: { createdAt: true, updatedAt: false }, collection: 'bus_document_reminders' },
);

// ===== 3. VIEWS =====

export type BusDocStatus = 'VALID' | 'EXPIRING' | 'EXPIRED';

export interface BusDocumentView {
  id: string;
  busId: string;
  docType: BusDocType;
  docName: string;
  validTill: string;
  daysLeft: number;
  status: BusDocStatus;
  remindDaysBefore: number[];
  files: Array<{ id: string; originalName: string; mimeType: string; sizeBytes: number; uploadedAt: string }>;
  createdAt?: string;
}

/** A bus as a driver or conductor sees it: only what they need. */
export interface DriverBusView {
  id: string;
  registrationNumber: string;
  name: string;
  documentsExpiring: number;
  documentsExpired: number;
}

export interface BusDocTypeView {
  key: BusDocType;
  label: string;
  required: boolean;
}

export function statusOf(daysLeft: number, remindDaysBefore: readonly number[]): BusDocStatus {
  if (daysLeft < 0) return 'EXPIRED';
  const window = remindDaysBefore.length > 0 ? Math.max(...remindDaysBefore) : 30;
  return daysLeft <= window ? 'EXPIRING' : 'VALID';
}

export function busDocumentViewOf(doc: BusDocumentRecord & { _id: Types.ObjectId }, now = new Date()): BusDocumentView {
  const validTill = new Date(doc.validTill);
  const daysLeft = daysLeftOf(validTill, now);
  return {
    id: doc._id.toHexString(),
    busId: doc.busId.toHexString(),
    docType: doc.docType,
    docName: doc.docName,
    validTill: validTill.toISOString().slice(0, 10),
    daysLeft,
    status: statusOf(daysLeft, doc.remindDaysBefore),
    remindDaysBefore: [...doc.remindDaysBefore],
    files: doc.files.map((file) => ({
      id: file.fileId,
      originalName: file.originalName,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      uploadedAt: new Date(file.uploadedAt).toISOString(),
    })),
    ...(doc.createdAt ? { createdAt: new Date(doc.createdAt).toISOString() } : {}),
  };
}

/** Reminder days written by the owner: whole days, 1 to 365, no repeats, at most six, largest first. */
export function cleanRemindDays(days: readonly number[] | undefined): number[] {
  if (days === undefined) return [...DEFAULT_REMIND_DAYS];
  const unique = [...new Set(days)];
  if (unique.length === 0 || unique.length > MAX_REMIND_DAYS) {
    throw new ApiException('VALIDATION_FAILED', `Choose between 1 and ${MAX_REMIND_DAYS} reminder days.`);
  }
  if (unique.some((day) => !Number.isInteger(day) || day < 1 || day > 365)) {
    throw new ApiException('VALIDATION_FAILED', 'Reminder days must be whole numbers from 1 to 365.');
  }
  return unique.sort((a, b) => b - a);
}

/**
 * Which reminder stage a document is in today, or null when it is too early for the first reminder.
 * The stage is the smallest reminder day the document has reached, so each chosen day sends once.
 */
export function reminderStageOf(daysLeft: number, remindDaysBefore: readonly number[]): string | null {
  if (daysLeft < 0) return 'EXPIRED';
  if (daysLeft === 0) return 'DAY0';
  const reached = [...remindDaysBefore].filter((day) => daysLeft <= day).sort((a, b) => a - b);
  return reached[0] === undefined ? null : String(reached[0]);
}

// ===== 4. THE SERVICE =====

interface CrewRow {
  _id: Types.ObjectId;
  operatorId: Types.ObjectId;
  name: string;
  role: string;
  phone: string;
  status: string;
  userId?: Types.ObjectId;
}

@Injectable()
export class BusDocumentsClientManageService {
  private readonly logger = new Logger(BusDocumentsClientManageService.name);

  constructor(
    @InjectModel(BUS_DOCUMENT_MODEL) private readonly documents: Model<BusDocumentRecord>,
    @InjectModel(BUS_DOC_REMINDER_MODEL) private readonly reminders: Model<BusReminderRecord>,
    @InjectConnection() private readonly connection: Connection,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
    private readonly changes: AuditedChangeRunner,
    private readonly transactions: TransactionRunner,
    private readonly outbox: OutboxService,
  ) {}

  // ----- helpers -----

  private operatorOf(actor: AuthenticatedUserActor): Types.ObjectId {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator identification missing from session actor');
    }
    return new Types.ObjectId(actor.operatorId);
  }

  private async busOf(
    actor: AuthenticatedUserActor,
    busId: string,
  ): Promise<{ _id: Types.ObjectId; registrationNumber: string; name: string }> {
    const operatorId = this.operatorOf(actor);
    const found = Types.ObjectId.isValid(busId)
      ? await this.connection
          .collection<{ _id: Types.ObjectId; registrationNumber: string; name: string }>('buses')
          .findOne({ _id: new Types.ObjectId(busId), operatorId, isDeleted: { $ne: true } })
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found');
    return found;
  }

  private async documentOf(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
  ): Promise<HydratedDocument<BusDocumentRecord>> {
    const bus = await this.busOf(actor, busId);
    const found = Types.ObjectId.isValid(docId)
      ? await this.documents
          .findOne({ _id: docId, busId: bus._id, operatorId: this.operatorOf(actor), isDeleted: { $ne: true } })
          .exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
    return found;
  }

  private checkFiles(files: readonly IncomingFile[], existing: number): Array<{ file: IncomingFile; mimeType: string }> {
    if (files.length === 0) throw new ApiException('VALIDATION_FAILED', 'Attach at least one file.');
    if (existing + files.length > MAX_FILES_PER_BUS_DOC) {
      throw new ApiException('VALIDATION_FAILED', `A document can have at most ${MAX_FILES_PER_BUS_DOC} files.`);
    }
    return files.map((file) => {
      if (file.size === 0) throw new ApiException('VALIDATION_FAILED', `${file.originalname || 'A file'} is empty.`);
      if (file.size > MAX_BUS_DOC_BYTES) {
        throw new ApiException('PAYLOAD_TOO_LARGE', `A file can be at most ${MAX_BUS_DOC_BYTES / 1024 / 1024} MB.`);
      }
      const mimeType = detectMimeType(file.buffer);
      if (!mimeType || !(BUS_DOC_MIME_TYPES as readonly string[]).includes(mimeType)) {
        throw new ApiException('UNSUPPORTED_MEDIA_TYPE', 'A document can be a PDF, a JPG or a PNG picture.');
      }
      return { file, mimeType };
    });
  }

  private async store(checked: ReadonlyArray<{ file: IncomingFile; mimeType: string }>): Promise<BusDocFile[]> {
    const saved: BusDocFile[] = [];
    try {
      for (const { file, mimeType } of checked) {
        const extension = EXTENSIONS[mimeType] ?? 'bin';
        const storageKey = `bus-documents/${randomUUID()}.${extension}`;
        await this.storage.put(storageKey, file.buffer, mimeType);
        saved.push({
          fileId: randomUUID(),
          storageKey,
          originalName: displayNameOf(file.originalname, extension),
          mimeType,
          sizeBytes: file.size,
          sha256: createHash('sha256').update(file.buffer).digest('hex'),
          uploadedAt: new Date(),
        });
      }
    } catch (error) {
      await Promise.allSettled(saved.map((file) => this.storage.remove(file.storageKey)));
      throw error;
    }
    return saved;
  }

  private validDay(text: string | undefined): Date {
    const day = text ? parseDay(text) : undefined;
    if (!day) throw new ApiException('VALIDATION_FAILED', 'Valid till must be a date like 2027-03-31.');
    return day;
  }

  // ----- the owner's side -----

  types(): BusDocTypeView[] {
    return BUS_DOC_TYPES.map((key) => ({ key, label: BUS_DOC_LABELS[key], required: REQUIRED_BUS_DOC_TYPES.includes(key) }));
  }

  async list(actor: AuthenticatedUserActor, busId: string): Promise<BusDocumentView[]> {
    const bus = await this.busOf(actor, busId);
    const found = await this.documents
      .find({ busId: bus._id, operatorId: this.operatorOf(actor), isDeleted: { $ne: true } })
      .sort({ validTill: 1 })
      .lean<StoredBusDocument[]>()
      .exec();
    return found.map((doc) => busDocumentViewOf(doc));
  }

  async add(
    actor: AuthenticatedUserActor,
    busId: string,
    input: {
      docType: BusDocType;
      docName?: string | undefined;
      validTill?: string | undefined;
      remindDaysBefore?: number[] | undefined;
    },
    files: readonly IncomingFile[],
    client: ClientRequestInfo,
  ): Promise<BusDocumentView> {
    const bus = await this.busOf(actor, busId);
    const docName = (input.docName ?? '').trim() || (input.docType === 'OTHER' ? '' : BUS_DOC_LABELS[input.docType]);
    if (!docName) throw new ApiException('VALIDATION_FAILED', 'Type the name of the document.');
    const validTill = this.validDay(input.validTill);
    const remindDaysBefore = cleanRemindDays(input.remindDaysBefore);
    const stored = await this.store(this.checkFiles(files, 0));
    try {
      const created = await this.changes.run<StoredBusDocument>({
        actor,
        client,
        action: 'bus-document.added',
        entityType: 'bus_document',
        before: {},
        operatorIdOf: (record) => record.operatorId,
        apply: async (session) => {
          const [doc] = await this.documents.create(
            [
              {
                operatorId: this.operatorOf(actor),
                busId: bus._id,
                docType: input.docType,
                docName,
                validTill,
                remindDaysBefore,
                files: stored,
                isDeleted: false,
              },
            ],
            { session },
          );
          if (!doc) throw new Error('The document was not created');
          return doc.toObject();
        },
        describe: (record) => ({ bus: bus.registrationNumber, document: record.docName, validTill: validTill.toISOString().slice(0, 10) }),
      });
      return busDocumentViewOf(created);
    } catch (error) {
      await Promise.allSettled(stored.map((file) => this.storage.remove(file.storageKey)));
      throw error;
    }
  }

  async addFiles(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    files: readonly IncomingFile[],
    client: ClientRequestInfo,
  ): Promise<BusDocumentView> {
    const doc = await this.documentOf(actor, busId, docId);
    const stored = await this.store(this.checkFiles(files, doc.files.length));
    try {
      const updated = await this.changes.run<StoredBusDocument>({
        actor,
        client,
        action: 'bus-document.updated',
        entityType: 'bus_document',
        before: { files: doc.files.length },
        operatorIdOf: (record) => record.operatorId,
        apply: async (session) => {
          const saved = await this.documents
            .findOneAndUpdate({ _id: doc._id }, { $push: { files: { $each: stored } } }, { returnDocument: 'after', session })
            .lean<StoredBusDocument>()
            .exec();
          if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
          return saved;
        },
        describe: (record) => ({ document: record.docName, files: record.files.length }),
      });
      return busDocumentViewOf(updated);
    } catch (error) {
      await Promise.allSettled(stored.map((file) => this.storage.remove(file.storageKey)));
      throw error;
    }
  }

  /** The owner can rename a document of any kind, change its date and choose its reminder days. */
  async update(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    input: {
      docName?: string | undefined;
      validTill?: string | undefined;
      remindDaysBefore?: number[] | undefined;
    },
    client: ClientRequestInfo,
  ): Promise<BusDocumentView> {
    const doc = await this.documentOf(actor, busId, docId);
    const set: Partial<BusDocumentRecord> = {};
    if (input.docName !== undefined) {
      const name = input.docName.trim();
      if (!name) throw new ApiException('VALIDATION_FAILED', 'Type the name of the document.');
      set.docName = name;
    }
    if (input.validTill !== undefined) set.validTill = this.validDay(input.validTill);
    if (input.remindDaysBefore !== undefined) set.remindDaysBefore = cleanRemindDays(input.remindDaysBefore);
    if (Object.keys(set).length === 0) throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    const updated = await this.changes.run<StoredBusDocument>({
      actor,
      client,
      action: 'bus-document.updated',
      entityType: 'bus_document',
      before: { document: doc.docName, validTill: new Date(doc.validTill).toISOString().slice(0, 10) },
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const saved = await this.documents
          .findOneAndUpdate({ _id: doc._id }, { $set: set }, { returnDocument: 'after', session })
          .lean<StoredBusDocument>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
        return saved;
      },
      describe: (record) => ({ document: record.docName, validTill: new Date(record.validTill).toISOString().slice(0, 10) }),
    });
    return busDocumentViewOf(updated);
  }

  async removeFile(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    fileId: string,
    client: ClientRequestInfo,
  ): Promise<BusDocumentView> {
    const doc = await this.documentOf(actor, busId, docId);
    const file = doc.files.find((candidate) => candidate.fileId === fileId);
    if (!file) throw new ApiException('RESOURCE_NOT_FOUND', 'File not found');
    if (doc.files.length === 1) {
      throw new ApiException('VALIDATION_FAILED', 'A document needs at least one file. Delete the document instead.');
    }
    const updated = await this.changes.run<StoredBusDocument>({
      actor,
      client,
      action: 'bus-document.updated',
      entityType: 'bus_document',
      before: { files: doc.files.length },
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const saved = await this.documents
          .findOneAndUpdate({ _id: doc._id }, { $pull: { files: { fileId } } }, { returnDocument: 'after', session })
          .lean<StoredBusDocument>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
        return saved;
      },
      describe: (record) => ({ document: record.docName, files: record.files.length }),
    });
    await this.storage.remove(file.storageKey).catch(() => undefined);
    return busDocumentViewOf(updated);
  }

  async remove(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    client: ClientRequestInfo,
  ): Promise<{ success: boolean }> {
    const doc = await this.documentOf(actor, busId, docId);
    await this.changes.run<StoredBusDocument>({
      actor,
      client,
      action: 'bus-document.removed',
      entityType: 'bus_document',
      before: { document: doc.docName },
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const saved = await this.documents
          .findOneAndUpdate({ _id: doc._id }, { $set: { isDeleted: true } }, { returnDocument: 'after', session })
          .lean<StoredBusDocument>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
        return saved;
      },
      describe: (record) => ({ document: record.docName }),
    });
    await Promise.allSettled(doc.files.map((file) => this.storage.remove(file.storageKey)));
    return { success: true };
  }

  async openFile(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    fileId: string,
  ): Promise<{ file: BusDocFile; content: Readable }> {
    const doc = await this.documentOf(actor, busId, docId);
    return this.fileOf(doc, fileId);
  }

  private async fileOf(
    doc: { files: BusDocFile[] },
    fileId: string,
  ): Promise<{ file: BusDocFile; content: Readable }> {
    const file = doc.files.find((candidate) => candidate.fileId === fileId);
    if (!file) throw new ApiException('RESOURCE_NOT_FOUND', 'File not found');
    return { file, content: await this.storage.open(file.storageKey) };
  }

  // ----- who runs a bus -----

  /** The crew record behind a signed-in driver or conductor account. */
  private async crewOfDriver(actor: AuthenticatedUserActor): Promise<CrewRow | null> {
    if (actor.userType !== 'DRIVER') {
      throw new ApiException('PERMISSION_DENIED', 'Only drivers and conductors can open this.');
    }
    const crew = this.connection.collection<CrewRow>('operator_crew');
    const byUser = await crew.findOne({ userId: new Types.ObjectId(actor.userId), isDeleted: { $ne: true } } as object);
    if (byUser) return byUser;
    const user = await this.connection
      .collection<{ _id: Types.ObjectId; phone?: string }>('users')
      .findOne({ _id: new Types.ObjectId(actor.userId) });
    if (!user?.phone) return null;
    return crew.findOne({ phone: normalizePhoneNumber(user.phone) ?? user.phone, isDeleted: { $ne: true } } as object);
  }

  /** The buses this person runs: the buses they are the usual crew of, and the buses of their upcoming trips. */
  private async busIdsOfCrew(person: CrewRow, now: Date): Promise<Types.ObjectId[]> {
    const usual = await this.connection
      .collection<{ _id: Types.ObjectId }>('buses')
      .find({ $or: [{ defaultDriverId: person._id }, { defaultConductorId: person._id }], isDeleted: { $ne: true } } as object)
      .project<{ _id: Types.ObjectId }>({ _id: 1 })
      .toArray();
    const onTrips = await this.connection
      .collection<{ busId: Types.ObjectId }>('trips')
      .find({
        $or: [{ driverId: person._id }, { conductorId: person._id }],
        departureAt: { $gte: new Date(now.getTime() - DAY_MS) },
        status: { $ne: 'CANCELLED' },
      } as object)
      .project<{ busId: Types.ObjectId }>({ busId: 1 })
      .toArray();
    const unique = new Map<string, Types.ObjectId>();
    for (const bus of usual) unique.set(bus._id.toHexString(), bus._id);
    for (const trip of onTrips) unique.set(trip.busId.toHexString(), trip.busId);
    return [...unique.values()];
  }

  async driverBuses(actor: AuthenticatedUserActor, now = new Date()): Promise<DriverBusView[]> {
    const person = await this.crewOfDriver(actor);
    if (!person) return [];
    const ids = await this.busIdsOfCrew(person, now);
    if (ids.length === 0) return [];
    const buses = await this.connection
      .collection<{ _id: Types.ObjectId; registrationNumber: string; name: string }>('buses')
      .find({ _id: { $in: ids }, operatorId: person.operatorId, isDeleted: { $ne: true } })
      .toArray();
    const docs = await this.documents
      .find({ busId: { $in: ids }, operatorId: person.operatorId, isDeleted: { $ne: true } })
      .lean<StoredBusDocument[]>()
      .exec();
    return buses.map((bus) => {
      const views = docs.filter((doc) => doc.busId.equals(bus._id)).map((doc) => busDocumentViewOf(doc, now));
      return {
        id: bus._id.toHexString(),
        registrationNumber: bus.registrationNumber,
        name: bus.name,
        documentsExpiring: views.filter((view) => view.status === 'EXPIRING').length,
        documentsExpired: views.filter((view) => view.status === 'EXPIRED').length,
      };
    });
  }

  /** A bus of this driver or conductor; any other bus is "not found". */
  private async driverBusOf(actor: AuthenticatedUserActor, busId: string, now: Date): Promise<{ person: CrewRow; busId: Types.ObjectId }> {
    const person = await this.crewOfDriver(actor);
    const allowed = person && Types.ObjectId.isValid(busId) ? await this.busIdsOfCrew(person, now) : [];
    const found = allowed.find((id) => id.toHexString() === busId);
    if (!person || !found) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found');
    return { person, busId: found };
  }

  async driverDocuments(actor: AuthenticatedUserActor, busId: string, now = new Date()): Promise<BusDocumentView[]> {
    const { person, busId: id } = await this.driverBusOf(actor, busId, now);
    const found = await this.documents
      .find({ busId: id, operatorId: person.operatorId, isDeleted: { $ne: true } })
      .sort({ validTill: 1 })
      .lean<StoredBusDocument[]>()
      .exec();
    // The reminder settings are the owner's; the driver sees the documents and their dates
    return found.map((doc) => ({ ...busDocumentViewOf(doc, now), remindDaysBefore: [] }));
  }

  async driverOpenFile(
    actor: AuthenticatedUserActor,
    busId: string,
    docId: string,
    fileId: string,
    now = new Date(),
  ): Promise<{ file: BusDocFile; content: Readable }> {
    const { person, busId: id } = await this.driverBusOf(actor, busId, now);
    const doc = Types.ObjectId.isValid(docId)
      ? await this.documents
          .findOne({ _id: docId, busId: id, operatorId: person.operatorId, isDeleted: { $ne: true } })
          .lean<StoredBusDocument>()
          .exec()
      : null;
    if (!doc) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
    return this.fileOf(doc, fileId);
  }

  /** The account of a crew person, from the link on the record or from the phone number. */
  private async userIdOf(person: CrewRow): Promise<string> {
    if (person.userId) return person.userId.toHexString();
    const phone = normalizePhoneNumber(person.phone) ?? person.phone;
    const user = await this.connection
      .collection<{ _id: Types.ObjectId }>('users')
      .findOne({ phone, userType: 'DRIVER' } as object);
    return user ? user._id.toHexString() : '';
  }

  /** Everyone who runs this bus now: its usual driver and conductor, and the crew of its upcoming trips. */
  private async crewOfBus(
    bus: { _id: Types.ObjectId; operatorId: Types.ObjectId; defaultDriverId?: Types.ObjectId; defaultConductorId?: Types.ObjectId },
    now: Date,
  ): Promise<{ driver?: CrewRow; conductor?: CrewRow; all: CrewRow[] }> {
    const trips = await this.connection
      .collection<{ driverId?: Types.ObjectId; conductorId?: Types.ObjectId; departureAt: Date }>('trips')
      .find({ busId: bus._id, departureAt: { $gte: new Date(now.getTime() - DAY_MS) }, status: { $ne: 'CANCELLED' } } as object)
      .sort({ departureAt: 1 })
      .limit(60)
      .toArray();
    const ids = new Map<string, Types.ObjectId>();
    const add = (id: Types.ObjectId | undefined) => {
      if (id) ids.set(id.toHexString(), id);
    };
    add(bus.defaultDriverId);
    add(bus.defaultConductorId);
    for (const trip of trips) {
      add(trip.driverId);
      add(trip.conductorId);
    }
    if (ids.size === 0) return { all: [] };
    const people = await this.connection
      .collection<CrewRow>('operator_crew')
      .find({ _id: { $in: [...ids.values()] }, operatorId: bus.operatorId, status: 'ACTIVE', isDeleted: { $ne: true } } as object)
      .toArray();
    const byId = new Map(people.map((person) => [person._id.toHexString(), person]));
    // The one named for the bus, else the one on the next trip
    const firstOf = (role: 'DRIVER' | 'CONDUCTOR'): CrewRow | undefined => {
      const usual = role === 'DRIVER' ? bus.defaultDriverId : bus.defaultConductorId;
      if (usual && byId.get(usual.toHexString())) return byId.get(usual.toHexString());
      for (const trip of trips) {
        const id = role === 'DRIVER' ? trip.driverId : trip.conductorId;
        if (id && byId.get(id.toHexString())) return byId.get(id.toHexString());
      }
      return people.find((person) => person.role === role);
    };
    const driver = firstOf('DRIVER');
    const conductor = firstOf('CONDUCTOR');
    return { ...(driver ? { driver } : {}), ...(conductor ? { conductor } : {}), all: people };
  }

  // ----- reminders -----

  /**
   * Finds documents that have reached one of the owner's reminder days (or the expiry day, or are past it)
   * and records one reminder event for each stage not sent yet. The event router tells the owner, the
   * operator's staff and the people who run the bus. Returns how many events were recorded.
   */
  async scanExpiries(now = new Date()): Promise<{ checked: number; sent: number }> {
    const horizon = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) + 366 * DAY_MS);
    const docs = await this.documents
      .find({ isDeleted: { $ne: true }, validTill: { $lte: horizon } })
      .lean<StoredBusDocument[]>()
      .exec();
    let checked = 0;
    let sent = 0;
    for (const doc of docs) {
      const daysLeft = daysLeftOf(new Date(doc.validTill), now);
      const stage = reminderStageOf(daysLeft, doc.remindDaysBefore);
      if (!stage) continue;
      checked += 1;
      const key = `${doc._id.toHexString()}:${new Date(doc.validTill).toISOString().slice(0, 10)}:${stage}`;
      if (await this.reminders.exists({ key })) continue;
      try {
        if (await this.recordReminder(key, doc, stage, daysLeft, now)) sent += 1;
      } catch (error) {
        this.logger.warn({ key, message: error instanceof Error ? error.message : 'unknown' }, 'Bus document reminder not recorded');
      }
    }
    return { checked, sent };
  }

  private async recordReminder(
    key: string,
    doc: StoredBusDocument,
    stage: string,
    daysLeft: number,
    now: Date,
  ): Promise<boolean> {
    const bus = await this.connection
      .collection<{
        _id: Types.ObjectId;
        operatorId: Types.ObjectId;
        registrationNumber: string;
        name: string;
        status: string;
        defaultDriverId?: Types.ObjectId;
        defaultConductorId?: Types.ObjectId;
      }>('buses')
      .findOne({ _id: doc.busId, isDeleted: { $ne: true } });
    if (!bus || bus.status === 'RETIRED') return false;
    const crew = await this.crewOfBus(bus, now);
    const crewUserIds: string[] = [];
    for (const person of crew.all) {
      const id = await this.userIdOf(person);
      if (id && !crewUserIds.includes(id)) crewUserIds.push(id);
    }
    const driverUserId = crew.driver ? await this.userIdOf(crew.driver) : '';
    const conductorUserId = crew.conductor ? await this.userIdOf(crew.conductor) : '';
    await this.transactions.run(async (session) => {
      await this.reminders.create([{ key }], { session });
      await this.outbox.record(
        {
          type: BUS_DOCUMENT_EXPIRING_EVENT,
          aggregateType: 'bus',
          aggregateId: bus._id.toHexString(),
          payload: {
            operatorId: bus.operatorId.toHexString(),
            busId: bus._id.toHexString(),
            busRegistration: bus.registrationNumber,
            busName: bus.name,
            documentName: doc.docName,
            validTillText: new Date(doc.validTill).toISOString().slice(0, 10),
            stage,
            daysLeft,
            crewUserIds,
            driverId: driverUserId,
            driverName: crew.driver?.name ?? '',
            driverPhone: crew.driver ? (normalizePhoneNumber(crew.driver.phone) ?? '') : '',
            conductorId: conductorUserId,
            conductorName: crew.conductor?.name ?? '',
            conductorPhone: crew.conductor ? (normalizePhoneNumber(crew.conductor.phone) ?? '') : '',
          },
        },
        session,
      );
    });
    return true;
  }
}
