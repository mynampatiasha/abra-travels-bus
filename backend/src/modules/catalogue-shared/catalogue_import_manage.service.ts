import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { Workbook } from 'exceljs';
import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { AuditLogService } from '../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from '../rbac/services/effective-permissions.service';
import { CSV_BOM, csvOf, type ExportFormat, xlsxOf } from './catalogue_export_manage.service';

/*
 * Import of a list from a file (Phase 1 step 3): a template to fill in, a dry run that checks
 * every row and says what is wrong with each one, and the save, which creates the rows that are
 * right and says again what was left out. Each row is created by the same service, with the same
 * rules and the same audit entry, as adding one record on the screen.
 */

/** The largest file taken (the same 1 MB as a request body). */
export const IMPORT_MAX_BYTES = 1024 * 1024;
/** Most rows one file may hold. */
export const IMPORT_MAX_ROWS = 500;

export interface ImportColumn {
  /** The name the row is read by, such as `contact_phone`. */
  readonly key: string;
  /** The heading in the template: the same words the export uses. */
  readonly header: string;
  readonly required?: boolean;
  /** Other headings that mean the same column. */
  readonly aliases?: readonly string[];
  /** The example row of the template. */
  readonly sample: string;
}

/** What a row is checked against: whatever the import loaded once, and what earlier rows used. */
export interface ImportContext<Service> {
  readonly connection: Connection;
  readonly service: Service;
  /** Free space for the import to remember what the file has used so far (names seen). */
  readonly state: Record<string, unknown>;
}

export type PreparedRow<Dto> = { dto: Dto; label: string } | { errors: string[]; label: string };

export interface ImportSpec<Dto, Service> {
  /** `entityType` of the audit entry and the start of the template's file name. */
  readonly key: string;
  readonly columns: readonly ImportColumn[];
  /** Loads what rows are checked against, once, before the first row. */
  begin?(context: ImportContext<Service>): Promise<void>;
  /** Checks one row without saving anything. */
  prepare(
    raw: Readonly<Record<string, string>>,
    context: ImportContext<Service>,
    rowNumber: number,
  ): Promise<PreparedRow<Dto>>;
  /** Saves one checked row. A refusal (ApiException) becomes that row's error. */
  create(
    context: ImportContext<Service>,
    actor: AuthenticatedUserActor,
    dto: Dto,
    client: ClientRequestInfo,
  ): Promise<void>;
}

export type RowStatus = 'OK' | 'CREATED' | 'ERROR';

export interface ImportRowResult {
  /** Row number as a spreadsheet shows it: the heading is row 1. */
  readonly row: number;
  readonly label: string;
  readonly status: RowStatus;
  readonly errors: readonly string[];
}

export interface ImportResult {
  readonly dryRun: boolean;
  readonly total: number;
  /** Rows that are right (dry run) or were created (save). */
  readonly accepted: number;
  readonly rejected: number;
  readonly ignoredColumns: readonly string[];
  readonly rows: readonly ImportRowResult[];
}

// ------------------------------------------------------------------------------- reading files

/** CSV text as rows of cells: quotes, doubled quotes and line breaks inside quotes are handled. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  const source = text.startsWith(CSV_BOM) ? text.slice(1) : text;
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index]!;
    if (quoted) {
      if (char === '"' && source[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        cell += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ',') {
      row.push(cell);
      cell = '';
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && source[index + 1] === '\n') index += 1;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += char;
    }
  }
  if (cell !== '' || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

/** True for a file that starts like a zip, which is what an .xlsx file is. */
export function looksLikeXlsx(data: Buffer): boolean {
  return data.length > 4 && data[0] === 0x50 && data[1] === 0x4b;
}

/** Every row of the first sheet of an Excel file, as text. */
async function parseXlsx(data: Buffer): Promise<string[][]> {
  const workbook = new Workbook();
  try {
    await workbook.xlsx.load(data as unknown as ArrayBuffer);
  } catch {
    throw new ApiException('VALIDATION_FAILED', 'This Excel file could not be read.');
  }
  const sheet = workbook.worksheets[0];
  if (!sheet) throw new ApiException('VALIDATION_FAILED', 'The Excel file has no sheet.');
  const rows: string[][] = [];
  sheet.eachRow({ includeEmpty: true }, (row, rowNumber) => {
    const cells: string[] = [];
    for (let column = 1; column <= sheet.columnCount; column += 1) {
      cells.push(row.getCell(column).text.trim());
    }
    rows[rowNumber - 1] = cells;
  });
  // A sheet can skip a row number: keep the row numbers, with an empty row in between
  return Array.from(rows, (row) => row ?? []);
}

/** The rows of an uploaded file: CSV or Excel, told apart by the first bytes. */
export async function readTable(data: Buffer | undefined): Promise<string[][]> {
  if (!data || data.length === 0) {
    throw new ApiException('VALIDATION_FAILED', 'Attach the file in the "file" field.');
  }
  if (data.length > IMPORT_MAX_BYTES) {
    throw new ApiException('PAYLOAD_TOO_LARGE', 'The file can be at most 1 MB.');
  }
  return looksLikeXlsx(data) ? parseXlsx(data) : parseCsv(data.toString('utf8'));
}

/**
 * What a rule of the form says about a cell, in words for the person who filled the file in: a
 * missing value is "is required", not the parser's own sentence.
 */
export function issueMessage(issue: { code: string; message: string }): string {
  return issue.code === 'invalid_type' && /undefined/.test(issue.message)
    ? 'is required.'
    : issue.message;
}

/** `Country code` as `country_code`. */
export function normalizeHeader(header: string): string {
  return header
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

/** Yes, true, 1 or y as true; no, false, 0 or n as false; empty as undefined; else null. */
export function parseYesNo(value: string): boolean | undefined | null {
  const text = value.trim().toLowerCase();
  if (text === '') return undefined;
  if (['yes', 'true', '1', 'y'].includes(text)) return true;
  if (['no', 'false', '0', 'n'].includes(text)) return false;
  return null;
}

/** A number from text; empty as undefined; not a number as null. */
export function parseNumber(value: string): number | undefined | null {
  const text = value.trim();
  if (text === '') return undefined;
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : null;
}

@Injectable()
export class CatalogueImportService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly permissions: EffectivePermissionsService,
  ) {}

  /** The empty template: the headings, and one example row. */
  async template<Dto, Service>(
    spec: ImportSpec<Dto, Service>,
    format: ExportFormat,
  ): Promise<{ body: Buffer; contentType: string; fileName: string }> {
    const headers = spec.columns.map((column) => column.header);
    const sample = [spec.columns.map((column) => column.sample)];
    const body =
      format === 'csv'
        ? Buffer.from(csvOf(headers, sample), 'utf8')
        : await xlsxOf(spec.key, headers, sample);
    return {
      body,
      contentType:
        format === 'csv'
          ? 'text/csv; charset=utf-8'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      fileName: `${spec.key}-import-template.${format}`,
    };
  }

  /** Checks (dryRun) or saves a file. The result lists every row with what is wrong with it. */
  async run<Dto, Service>(
    spec: ImportSpec<Dto, Service>,
    service: Service,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    data: Buffer | undefined,
    dryRun: boolean,
  ): Promise<ImportResult> {
    const table = await readTable(data);
    const headerCells = table.find((row) => row.some((cell) => cell.trim() !== '')) ?? [];
    const headerIndex = table.indexOf(headerCells);

    // Which column of the file is which column of the spec
    const byKey = new Map<string, number>();
    const ignored: string[] = [];
    headerCells.forEach((header, index) => {
      const normal = normalizeHeader(header);
      if (normal === '') return;
      const column = spec.columns.find(
        (candidate) =>
          candidate.key === normal ||
          normalizeHeader(candidate.header) === normal ||
          candidate.aliases?.some((alias) => normalizeHeader(alias) === normal),
      );
      if (column && !byKey.has(column.key)) byKey.set(column.key, index);
      else ignored.push(header.trim());
    });
    const missing = spec.columns.filter((column) => column.required && !byKey.has(column.key));
    if (missing.length > 0) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `The first row of the file must name these columns: ${missing
          .map((column) => `"${column.header}"`)
          .join(', ')}.`,
      );
    }

    const dataRows = table
      .map((cells, index) => ({ cells, number: index + 1 }))
      .filter(
        (row) => row.number > headerIndex + 1 && row.cells.some((cell) => cell.trim() !== ''),
      );
    if (dataRows.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'The file has no rows below the column names.');
    }
    if (dataRows.length > IMPORT_MAX_ROWS) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `The file has ${dataRows.length} rows; at most ${IMPORT_MAX_ROWS} can be imported at once.`,
      );
    }

    const context: ImportContext<Service> = { connection: this.connection, service, state: {} };
    await spec.begin?.(context);

    const rows: ImportRowResult[] = [];
    for (const { cells, number } of dataRows) {
      const raw: Record<string, string> = {};
      for (const [key, index] of byKey) raw[key] = (cells[index] ?? '').trim();
      const prepared = await spec.prepare(raw, context, number);
      if ('errors' in prepared) {
        rows.push({ row: number, label: prepared.label, status: 'ERROR', errors: prepared.errors });
        continue;
      }
      if (dryRun) {
        rows.push({ row: number, label: prepared.label, status: 'OK', errors: [] });
        continue;
      }
      try {
        await spec.create(context, actor, prepared.dto, client);
        rows.push({ row: number, label: prepared.label, status: 'CREATED', errors: [] });
      } catch (error) {
        if (!(error instanceof ApiException)) throw error;
        rows.push({ row: number, label: prepared.label, status: 'ERROR', errors: [error.message] });
      }
    }

    const accepted = rows.filter((row) => row.status !== 'ERROR').length;
    if (!dryRun && accepted > 0) await this.record(spec.key, actor, client, rows.length, accepted);
    return {
      dryRun,
      total: rows.length,
      accepted,
      rejected: rows.length - accepted,
      ignoredColumns: ignored,
      rows,
    };
  }

  private async record(
    key: string,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    total: number,
    created: number,
  ): Promise<void> {
    const roleKeys = (await this.permissions.forActor(actor)).roleKeys;
    await this.transactions.run((session) =>
      this.audit.record(
        {
          actor,
          actorRoleKeys: roleKeys,
          action: 'catalogue.imported',
          entityType: key,
          entityId: new Types.ObjectId(),
          before: {},
          after: { total, created, skipped: total - created },
          client,
        },
        session,
      ),
    );
  }
}
