import { createHash, randomUUID } from 'node:crypto';
import { type Readable } from 'node:stream';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type HydratedDocument, type Model, Schema, Types } from 'mongoose';
import { normalizePhoneNumber } from '../../common/validation/contact-identifiers';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { USER_MODEL } from '../users/schemas/user.schema';
import { OutboxService } from '../../events/outbox.service';
import { displayNameOf, type IncomingFile } from '../files/services/files.service';
import { detectMimeType } from '../files/storage/file-signature';
import { FILE_STORAGE, type FileStorage } from '../files/storage/file-storage';
import {
  CREW_ROLES,
  CREW_STATUSES,
  type CrewRole,
  type CrewStatus,
  type OperatorCrewDocument,
} from './crew_client_manage.service';

/*
 * Documents of the drivers and crew (licence, ID proof, medical certificate...): several files per
 * document, an optional validity date, view and download. The expiry reminders and the CSV import
 * of people live here too. Files go to the same private storage as the other uploads.
 */

// ===== 1. RULES =====

export const CREW_DOC_TYPES = [
  'DRIVING_LICENCE',
  'AADHAAR',
  'PAN',
  'MEDICAL_FITNESS',
  'POLICE_VERIFICATION',
  'BADGE',
  'OTHER',
] as const;
export type CrewDocType = (typeof CREW_DOC_TYPES)[number];

export const CREW_DOC_LABELS: Readonly<Record<CrewDocType, string>> = {
  DRIVING_LICENCE: 'Driving licence',
  AADHAAR: 'Aadhaar',
  PAN: 'PAN card',
  MEDICAL_FITNESS: 'Medical fitness certificate',
  POLICE_VERIFICATION: 'Police verification',
  BADGE: 'Badge',
  OTHER: 'Other',
};

export const MAX_FILES_PER_CREW_DOC = 10;
export const MAX_CREW_DOC_BYTES = 5 * 1024 * 1024;
export const MAX_CREW_IMPORT_ROWS = 500;
const CREW_DOC_MIME_TYPES = ['application/pdf', 'image/jpeg', 'image/png'] as const;
const EXTENSIONS: Readonly<Record<string, string>> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};
const BOM = String.fromCharCode(0xfeff);
const DAY_MS = 24 * 60 * 60 * 1000;
export const CREW_DOCUMENT_EXPIRING_EVENT = 'crew.document-expiring';

export const CREW_DOCUMENT_MODEL = 'crew_documents';
export const CREW_REMINDER_MODEL = 'crew_expiry_reminders';

// ===== 2. STORED SHAPES =====

export interface CrewDocFile {
  fileId: string;
  storageKey: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  uploadedAt: Date;
}

export interface CrewDocumentRecord {
  _id: Types.ObjectId;
  operatorId: Types.ObjectId;
  crewId: Types.ObjectId;
  docType: CrewDocType;
  docName: string;
  validTill?: Date | null;
  files: CrewDocFile[];
  isDeleted?: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const CrewDocFileSchema = new Schema<CrewDocFile>(
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

export const CrewDocumentSchema = new Schema<CrewDocumentRecord>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true, index: true },
    crewId: { type: Schema.Types.ObjectId, required: true, index: true },
    docType: { type: String, enum: CREW_DOC_TYPES, required: true },
    docName: { type: String, required: true, trim: true, maxlength: 100 },
    validTill: { type: Date, default: null },
    files: { type: [CrewDocFileSchema], default: [] },
    isDeleted: { type: Boolean, default: false, index: true },
  },
  { timestamps: true, collection: 'crew_documents' },
);
CrewDocumentSchema.index({ operatorId: 1, validTill: 1 });

export interface CrewReminderRecord {
  key: string;
  createdAt: Date;
}

/** One row per reminder already sent, so a restart or a second worker never repeats it. */
export const CrewReminderSchema = new Schema<CrewReminderRecord>(
  { key: { type: String, required: true, unique: true } },
  { timestamps: { createdAt: true, updatedAt: false }, collection: 'crew_expiry_reminders' },
);

// ===== 3. VIEWS =====

export type CrewDocStatus = 'NO_DATE' | 'VALID' | 'EXPIRING' | 'EXPIRED';

export interface CrewDocumentView {
  id: string;
  crewId: string;
  docType: CrewDocType;
  docName: string;
  validTill?: string;
  daysLeft?: number;
  status: CrewDocStatus;
  files: Array<{
    id: string;
    originalName: string;
    mimeType: string;
    sizeBytes: number;
    uploadedAt: string;
  }>;
  createdAt?: string;
}

export interface CrewDocCounts {
  documentsCount: number;
  documentsExpiring: number;
  documentsExpired: number;
}

export interface CrewImportSkippedRow {
  row: number;
  name: string;
  phone: string;
  reason: string;
}

export interface CrewImportResult {
  total: number;
  imported: number;
  skipped: number;
  skippedRows: CrewImportSkippedRow[];
}

function startOfTodayUtc(now: Date): number {
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
}

export function daysLeftOf(validTill: Date, now: Date): number {
  return Math.round((validTill.getTime() - startOfTodayUtc(now)) / DAY_MS);
}

function statusOf(daysLeft: number | undefined): CrewDocStatus {
  if (daysLeft === undefined) return 'NO_DATE';
  if (daysLeft < 0) return 'EXPIRED';
  return daysLeft <= 30 ? 'EXPIRING' : 'VALID';
}

export function documentViewOf(doc: CrewDocumentRecord, now = new Date()): CrewDocumentView {
  const validTill = doc.validTill ? new Date(doc.validTill) : undefined;
  const daysLeft = validTill ? daysLeftOf(validTill, now) : undefined;
  return {
    id: doc._id.toHexString(),
    crewId: doc.crewId.toHexString(),
    docType: doc.docType,
    docName: doc.docName,
    ...(validTill ? { validTill: validTill.toISOString().slice(0, 10) } : {}),
    ...(daysLeft !== undefined ? { daysLeft } : {}),
    status: statusOf(daysLeft),
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

/** `YYYY-MM-DD` as a date at midnight UTC; undefined when it is not a real calendar day. */
export function parseDay(text: string): Date | undefined {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return undefined;
  const date = new Date(`${text}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== text ? undefined : date;
}

// ===== 4. CSV =====

/** Reads CSV text (quotes, doubled quotes, comma / semicolon / tab / pipe) into rows of cells. */
export function parseCsv(text: string): string[][] {
  const clean = text.charAt(0) === BOM ? text.slice(1) : text;
  const firstLine = clean.split(/\r?\n/, 1)[0] ?? '';
  let delimiter = ',';
  let best = 0;
  for (const candidate of [',', ';', '\t', '|']) {
    const count = firstLine.split(candidate).length - 1;
    if (count > best) {
      best = count;
      delimiter = candidate;
    }
  }
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < clean.length; i++) {
    const char = clean.charAt(i);
    if (quoted) {
      if (char === '"' && clean.charAt(i + 1) === '"') {
        cell += '"';
        i++;
      } else if (char === '"') quoted = false;
      else cell += char;
    } else if (char === '"') quoted = true;
    else if (char === delimiter) {
      row.push(cell);
      cell = '';
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && clean.charAt(i + 1) === '\n') i++;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else cell += char;
  }
  if (cell !== '' || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

const csvCell = (value: string): string =>
  /[",\n\r]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;

export function crewSampleCsv(now = new Date()): string {
  const valid = new Date(now.getTime() + 400 * DAY_MS).toISOString().slice(0, 10);
  const rows = [
    ['Name*', 'Phone*', 'Role', 'Licence Number', 'Licence Valid Till', 'Badge Number', 'Status'],
    ['Ramesh Kumar', '9876543210', 'DRIVER', 'TS0920190012345', valid, 'B-1042', 'ACTIVE'],
    ['Suresh Reddy', '9812345678', 'CONDUCTOR', '', '', 'B-2210', 'ACTIVE'],
    ['Imran Khan', '9700012345', 'DRIVER', 'KA0120180098765', valid, '', 'ON_LEAVE'],
  ];
  return `${BOM}${rows.map((cells) => cells.map(csvCell).join(',')).join('\r\n')}\r\n`;
}

const headerKey = (text: string): string => text.toLowerCase().replace(/[^a-z0-9]/g, '');

const HEADER_ALIASES: Readonly<Record<string, readonly string[]>> = {
  name: ['name', 'fullname', 'personname', 'drivername'],
  phone: ['phone', 'phonenumber', 'mobile', 'mobilenumber', 'contact'],
  role: ['role', 'designation'],
  licenceNumber: ['licencenumber', 'licensenumber', 'licence', 'license', 'drivinglicencenumber'],
  licenceValidTill: ['licencevalidtill', 'licensevalidtill', 'licenceexpiry', 'licenseexpiry', 'validtill'],
  badgeNumber: ['badgenumber', 'badge'],
  status: ['status'],
};

// ===== 5. THE SERVICE =====

@Injectable()
export class CrewDocumentsClientManageService {
  private readonly logger = new Logger(CrewDocumentsClientManageService.name);

  constructor(
    @InjectModel(CREW_DOCUMENT_MODEL) private readonly documents: Model<CrewDocumentRecord>,
    @InjectModel(CREW_REMINDER_MODEL) private readonly reminders: Model<CrewReminderRecord>,
    @InjectModel('operator_crew') private readonly crew: Model<OperatorCrewDocument>,
    @InjectModel(USER_MODEL) private readonly users: Model<{ phone?: string; userType?: string }>,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
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

  private async crewOf(actor: AuthenticatedUserActor, crewId: string): Promise<OperatorCrewDocument> {
    const operatorId = this.operatorOf(actor);
    const found = Types.ObjectId.isValid(crewId)
      ? await this.crew.findOne({ _id: crewId, operatorId, isDeleted: { $ne: true } }).exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record not found');
    return found;
  }

  private async documentOf(
    actor: AuthenticatedUserActor,
    crewId: string,
    docId: string,
  ): Promise<HydratedDocument<CrewDocumentRecord>> {
    await this.crewOf(actor, crewId);
    const found = Types.ObjectId.isValid(docId)
      ? await this.documents
          .findOne({ _id: docId, crewId, operatorId: this.operatorOf(actor), isDeleted: { $ne: true } })
          .exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Document not found');
    return found;
  }

  private checkFiles(files: readonly IncomingFile[], existing: number): Array<{
    file: IncomingFile;
    mimeType: string;
  }> {
    if (files.length === 0) throw new ApiException('VALIDATION_FAILED', 'Attach at least one file.');
    if (existing + files.length > MAX_FILES_PER_CREW_DOC) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `A document can have at most ${MAX_FILES_PER_CREW_DOC} files.`,
      );
    }
    return files.map((file) => {
      if (file.size === 0) {
        throw new ApiException('VALIDATION_FAILED', `${file.originalname || 'A file'} is empty.`);
      }
      if (file.size > MAX_CREW_DOC_BYTES) {
        throw new ApiException(
          'PAYLOAD_TOO_LARGE',
          `A file can be at most ${MAX_CREW_DOC_BYTES / 1024 / 1024} MB.`,
        );
      }
      const mimeType = detectMimeType(file.buffer);
      if (!mimeType || !(CREW_DOC_MIME_TYPES as readonly string[]).includes(mimeType)) {
        throw new ApiException(
          'UNSUPPORTED_MEDIA_TYPE',
          'A document can be a PDF, a JPG or a PNG picture.',
        );
      }
      return { file, mimeType };
    });
  }

  private async store(
    checked: ReadonlyArray<{ file: IncomingFile; mimeType: string }>,
  ): Promise<CrewDocFile[]> {
    const saved: CrewDocFile[] = [];
    try {
      for (const { file, mimeType } of checked) {
        const extension = EXTENSIONS[mimeType] ?? 'bin';
        const storageKey = `crew-documents/${randomUUID()}.${extension}`;
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

  /** The licence date shown in the crew list follows the driving licence document. */
  private async syncLicenceDate(crewId: Types.ObjectId, doc: CrewDocumentRecord): Promise<void> {
    if (doc.docType !== 'DRIVING_LICENCE' || !doc.validTill) return;
    await this.crew.updateOne({ _id: crewId }, { $set: { licenseExpiryDate: doc.validTill } }).exec();
  }

  // ----- documents -----

  async list(actor: AuthenticatedUserActor, crewId: string): Promise<CrewDocumentView[]> {
    await this.crewOf(actor, crewId);
    const found = await this.documents
      .find({ crewId, operatorId: this.operatorOf(actor), isDeleted: { $ne: true } })
      .sort({ createdAt: -1 })
      .exec();
    return found.map((doc) => documentViewOf(doc));
  }

  async countsFor(
    actor: AuthenticatedUserActor,
    crewIds: readonly string[],
  ): Promise<Map<string, CrewDocCounts>> {
    const result = new Map<string, CrewDocCounts>();
    if (crewIds.length === 0) return result;
    const found = await this.documents
      .find({
        operatorId: this.operatorOf(actor),
        crewId: { $in: crewIds.map((id) => new Types.ObjectId(id)) },
        isDeleted: { $ne: true },
      })
      .select('crewId validTill')
      .lean()
      .exec();
    const now = new Date();
    for (const doc of found) {
      const key = doc.crewId.toHexString();
      const counts = result.get(key) ?? { documentsCount: 0, documentsExpiring: 0, documentsExpired: 0 };
      counts.documentsCount += 1;
      if (doc.validTill) {
        const left = daysLeftOf(new Date(doc.validTill), now);
        if (left < 0) counts.documentsExpired += 1;
        else if (left <= 30) counts.documentsExpiring += 1;
      }
      result.set(key, counts);
    }
    return result;
  }

  async add(
    actor: AuthenticatedUserActor,
    crewId: string,
    input: { docType: CrewDocType; docName?: string | undefined; validTill?: string | undefined },
    files: readonly IncomingFile[],
  ): Promise<CrewDocumentView> {
    await this.crewOf(actor, crewId);
    const docName =
      input.docType === 'OTHER' ? (input.docName ?? '').trim() : CREW_DOC_LABELS[input.docType];
    if (!docName) throw new ApiException('VALIDATION_FAILED', 'Type the name of the document.');
    const validTill = input.validTill ? parseDay(input.validTill) : undefined;
    if (input.validTill && !validTill) {
      throw new ApiException('VALIDATION_FAILED', 'Valid till must be a date like 2027-03-31.');
    }
    const stored = await this.store(this.checkFiles(files, 0));
    try {
      const created = await this.documents.create({
        operatorId: this.operatorOf(actor),
        crewId: new Types.ObjectId(crewId),
        docType: input.docType,
        docName,
        validTill: validTill ?? null,
        files: stored,
        isDeleted: false,
      });
      await this.syncLicenceDate(new Types.ObjectId(crewId), created);
      return documentViewOf(created);
    } catch (error) {
      await Promise.allSettled(stored.map((file) => this.storage.remove(file.storageKey)));
      throw error;
    }
  }

  async addFiles(
    actor: AuthenticatedUserActor,
    crewId: string,
    docId: string,
    files: readonly IncomingFile[],
  ): Promise<CrewDocumentView> {
    const doc = await this.documentOf(actor, crewId, docId);
    const stored = await this.store(this.checkFiles(files, doc.files.length));
    doc.files.push(...stored);
    await doc.save();
    return documentViewOf(doc);
  }

  async update(
    actor: AuthenticatedUserActor,
    crewId: string,
    docId: string,
    input: { docName?: string | undefined; validTill?: string | null | undefined },
  ): Promise<CrewDocumentView> {
    const doc = await this.documentOf(actor, crewId, docId);
    if (input.docName !== undefined && doc.docType === 'OTHER') {
      if (!input.docName.trim()) throw new ApiException('VALIDATION_FAILED', 'Type the name of the document.');
      doc.docName = input.docName.trim();
    }
    if (input.validTill !== undefined) {
      if (input.validTill === null || input.validTill === '') doc.validTill = null;
      else {
        const parsed = parseDay(input.validTill);
        if (!parsed) throw new ApiException('VALIDATION_FAILED', 'Valid till must be a date like 2027-03-31.');
        doc.validTill = parsed;
      }
    }
    await doc.save();
    await this.syncLicenceDate(new Types.ObjectId(crewId), doc);
    return documentViewOf(doc);
  }

  async removeFile(
    actor: AuthenticatedUserActor,
    crewId: string,
    docId: string,
    fileId: string,
  ): Promise<CrewDocumentView> {
    const doc = await this.documentOf(actor, crewId, docId);
    const file = doc.files.find((candidate) => candidate.fileId === fileId);
    if (!file) throw new ApiException('RESOURCE_NOT_FOUND', 'File not found');
    if (doc.files.length === 1) {
      throw new ApiException('VALIDATION_FAILED', 'A document needs at least one file. Delete the document instead.');
    }
    doc.files = doc.files.filter((candidate) => candidate.fileId !== fileId);
    await doc.save();
    await this.storage.remove(file.storageKey).catch(() => undefined);
    return documentViewOf(doc);
  }

  async remove(actor: AuthenticatedUserActor, crewId: string, docId: string): Promise<{ success: boolean }> {
    const doc = await this.documentOf(actor, crewId, docId);
    doc.isDeleted = true;
    await doc.save();
    await Promise.allSettled(doc.files.map((file) => this.storage.remove(file.storageKey)));
    return { success: true };
  }

  async openFile(
    actor: AuthenticatedUserActor,
    crewId: string,
    docId: string,
    fileId: string,
  ): Promise<{ file: CrewDocFile; content: Readable }> {
    const doc = await this.documentOf(actor, crewId, docId);
    const file = doc.files.find((candidate) => candidate.fileId === fileId);
    if (!file) throw new ApiException('RESOURCE_NOT_FOUND', 'File not found');
    return { file, content: await this.storage.open(file.storageKey) };
  }

  // ----- import -----

  async importCsv(actor: AuthenticatedUserActor, file: IncomingFile | undefined): Promise<CrewImportResult> {
    const operatorId = this.operatorOf(actor);
    if (!file || file.size === 0) throw new ApiException('VALIDATION_FAILED', 'Please upload a CSV file.');
    if (!/\.csv$/i.test(file.originalname)) {
      throw new ApiException('VALIDATION_FAILED', 'Only CSV files (.csv) can be imported.');
    }
    const table = parseCsv(file.buffer.toString('utf8')).filter((cells) =>
      cells.some((cell) => cell.trim() !== ''),
    );
    const header = table.shift();
    if (!header) throw new ApiException('VALIDATION_FAILED', 'The CSV file is empty.');
    if (table.length > MAX_CREW_IMPORT_ROWS) {
      throw new ApiException('VALIDATION_FAILED', `A file can have at most ${MAX_CREW_IMPORT_ROWS} people.`);
    }
    const columns = new Map(header.map((cell, index) => [headerKey(cell), index] as const));
    const valueOf = (cells: string[], field: string, fallback: number): string => {
      for (const alias of HEADER_ALIASES[field] ?? []) {
        const index = columns.get(alias);
        if (index !== undefined) return (cells[index] ?? '').trim();
      }
      return (columns.size === 0 ? (cells[fallback] ?? '') : '').trim();
    };
    if (!(HEADER_ALIASES.name ?? []).some((alias) => columns.has(alias)) ||
        !(HEADER_ALIASES.phone ?? []).some((alias) => columns.has(alias))) {
      throw new ApiException('VALIDATION_FAILED', 'The first row must have the columns Name and Phone. Download the sample file.');
    }

    const existing = await this.crew.find({ operatorId, isDeleted: { $ne: true } }).select('phone').lean().exec();
    const seen = new Set(existing.map((person) => normalizePhoneNumber(person.phone) ?? person.phone));
    const result: CrewImportResult = { total: table.length, imported: 0, skipped: 0, skippedRows: [] };

    for (const [index, cells] of table.entries()) {
      const name = valueOf(cells, 'name', 0);
      const phoneText = valueOf(cells, 'phone', 1);
      const reject = (reason: string): void => {
        result.skipped += 1;
        result.skippedRows.push({ row: index + 2, name, phone: phoneText, reason });
      };
      if (!name) { reject('Name is missing'); continue; }
      if (name.length > 100) { reject('Name is longer than 100 characters'); continue; }
      const phone = normalizePhoneNumber(phoneText);
      if (!phoneText) { reject('Phone is missing'); continue; }
      if (!phone) { reject('Phone number is not valid'); continue; }
      if (seen.has(phone)) { reject('This phone number already exists'); continue; }

      const roleText = valueOf(cells, 'role', 2).toUpperCase().replace(/\s+/g, '_');
      const role = (roleText || 'DRIVER') as CrewRole;
      if (!(CREW_ROLES as readonly string[]).includes(role)) {
        reject(`Role must be ${CREW_ROLES.join(', ')}`);
        continue;
      }
      const statusText = valueOf(cells, 'status', 6).toUpperCase().replace(/\s+/g, '_');
      const status = (statusText || 'ACTIVE') as CrewStatus;
      if (!(CREW_STATUSES as readonly string[]).includes(status)) {
        reject(`Status must be ${CREW_STATUSES.join(', ')}`);
        continue;
      }
      const validText = valueOf(cells, 'licenceValidTill', 4);
      const validTill = validText ? parseDay(validText) : undefined;
      if (validText && !validTill) { reject('Licence valid till must be a date like 2027-03-31'); continue; }
      const licence = valueOf(cells, 'licenceNumber', 3);
      const badge = valueOf(cells, 'badgeNumber', 5);

      try {
        await this.crew.create({
          operatorId,
          name,
          role,
          phone,
          ...(licence ? { licenseNumber: licence.slice(0, 50) } : {}),
          ...(validTill ? { licenseExpiryDate: validTill } : {}),
          ...(badge ? { badgeNumber: badge.slice(0, 50) } : {}),
          status,
          isDeleted: false,
        });
        seen.add(phone);
        result.imported += 1;
      } catch {
        reject('Could not be saved');
      }
    }
    return result;
  }

  // ----- reminders -----

  /**
   * Finds documents (and licence dates) that are 30 days, 7 days, 0 days away or past, and records
   * one reminder event for each stage that has not been sent yet. The event router tells the owner
   * and the driver. Returns how many events were recorded.
   */
  async scanExpiries(now = new Date()): Promise<{ checked: number; sent: number }> {
    const horizon = new Date(startOfTodayUtc(now) + 30 * DAY_MS);
    const docs = await this.documents
      .find({ isDeleted: { $ne: true }, validTill: { $ne: null, $lte: horizon } })
      .exec();
    const licenceDocCrews = new Set(
      (
        await this.documents
          .find({ isDeleted: { $ne: true }, docType: 'DRIVING_LICENCE', validTill: { $ne: null } })
          .select('crewId')
          .lean()
          .exec()
      ).map((doc) => doc.crewId.toHexString()),
    );
    const licences = await this.crew
      .find({ isDeleted: { $ne: true }, status: { $ne: 'INACTIVE' }, licenseExpiryDate: { $ne: null, $lte: horizon } })
      .exec();

    const candidates: Array<{
      source: string;
      crew: OperatorCrewDocument;
      documentName: string;
      validTill: Date;
    }> = [];
    const crewById = new Map<string, OperatorCrewDocument>();
    const crewIds = [...new Set(docs.map((doc) => doc.crewId.toHexString()))];
    if (crewIds.length > 0) {
      for (const person of await this.crew
        .find({ _id: { $in: crewIds }, isDeleted: { $ne: true }, status: { $ne: 'INACTIVE' } })
        .exec()) {
        crewById.set(person._id.toHexString(), person);
      }
    }
    for (const doc of docs) {
      const person = crewById.get(doc.crewId.toHexString());
      if (person && doc.validTill) {
        candidates.push({ source: `DOC:${doc._id.toHexString()}`, crew: person, documentName: doc.docName, validTill: new Date(doc.validTill) });
      }
    }
    for (const person of licences) {
      if (person.licenseExpiryDate && !licenceDocCrews.has(person._id.toHexString())) {
        candidates.push({ source: `LIC:${person._id.toHexString()}`, crew: person, documentName: 'Driving licence', validTill: new Date(person.licenseExpiryDate) });
      }
    }

    let sent = 0;
    for (const candidate of candidates) {
      const daysLeft = daysLeftOf(candidate.validTill, now);
      const stage = daysLeft < 0 ? 'EXPIRED' : daysLeft === 0 ? 'DAY0' : daysLeft <= 7 ? '7' : '30';
      const key = `${candidate.source}:${candidate.validTill.toISOString().slice(0, 10)}:${stage}`;
      if (await this.reminders.exists({ key })) continue;
      try {
        await this.recordReminder(key, candidate, stage, daysLeft);
        sent += 1;
      } catch (error) {
        this.logger.warn({ key, message: error instanceof Error ? error.message : 'unknown' }, 'Expiry reminder not recorded');
      }
    }
    return { checked: candidates.length, sent };
  }

  private async driverUserId(person: OperatorCrewDocument): Promise<string> {
    if (person.userId) return person.userId.toHexString();
    const phone = normalizePhoneNumber(person.phone) ?? person.phone;
    const user = await this.users.findOne({ phone, userType: 'DRIVER' }).select('_id').lean().exec();
    return user ? String((user as { _id: Types.ObjectId })._id) : '';
  }

  private async recordReminder(
    key: string,
    candidate: { crew: OperatorCrewDocument; documentName: string; validTill: Date },
    stage: string,
    daysLeft: number,
  ): Promise<void> {
    const person = candidate.crew;
    const driverId = await this.driverUserId(person);
    const phone = normalizePhoneNumber(person.phone) ?? '';
    await this.transactions.run(async (session) => {
      await this.reminders.create([{ key }], { session });
      await this.outbox.record(
        {
          type: CREW_DOCUMENT_EXPIRING_EVENT,
          aggregateType: 'crew',
          aggregateId: person._id.toHexString(),
          payload: {
            operatorId: person.operatorId.toHexString(),
            crewId: person._id.toHexString(),
            driverId,
            driverName: person.name,
            driverPhone: phone,
            documentName: candidate.documentName,
            validTillText: candidate.validTill.toISOString().slice(0, 10),
            stage,
            daysLeft,
          },
        },
        session,
      );
    });
  }
}
