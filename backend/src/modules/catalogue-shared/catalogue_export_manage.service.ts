import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { Workbook } from 'exceljs';
import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { AuditLogService } from '../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from '../rbac/services/effective-permissions.service';

/*
 * Server-side export of the admin lists (Phase 1 step 3). A list is exported with the same
 * filters and the same permission as the list itself: the rows come from the list's own service,
 * page by page, so nothing is selected twice in two ways. Every export writes an audit entry.
 */

export const EXPORT_FORMATS = ['csv', 'xlsx'] as const;
export type ExportFormat = (typeof EXPORT_FORMATS)[number];

/** Most rows one export can hold; the person is asked to narrow the filters beyond it. */
export const MAX_EXPORT_ROWS = 20_000;

/** The size of the pages read from a list while exporting (the largest a list allows). */
const READ_PAGE_SIZE = 100;

export type Cell = string | number | boolean | Date | null | undefined;

/** Names of other records, found once for the whole export: `names('City', id)`. */
export type NameLookup = (model: string, id: string | null | undefined) => string;

export interface ExportColumn<Row> {
  readonly header: string;
  readonly value: (row: Row, names: NameLookup) => Cell;
}

export interface ExportKind<Row> {
  /** `entityType` of the audit entry, and the start of the file name. */
  readonly key: string;
  readonly columns: readonly ExportColumn<Row>[];
  /** Records whose names a column shows: model name to the ids used by [rows]. */
  readonly references?: (rows: readonly Row[]) => Readonly<Record<string, readonly string[]>>;
}

export interface ExportFile {
  readonly body: Buffer;
  readonly contentType: string;
  readonly fileName: string;
  readonly rows: number;
}

const CONTENT_TYPES: Readonly<Record<ExportFormat, string>> = {
  csv: 'text/csv; charset=utf-8',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/** `PENDING_APPROVAL` as "Pending approval": a code as a person reads it. */
export function readable(value: string | null | undefined): string {
  if (!value) return '';
  const text = value.replace(/[_-]+/g, ' ').toLowerCase();
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** The time an ISO text stands for, or null. */
export function timeOf(value: string | null | undefined): Date | null {
  const time = value ? new Date(value) : null;
  return time && !Number.isNaN(time.getTime()) ? time : null;
}

/** A day in India time as `YYYY-MM-DD`. */
function dayOf(date: Date): string {
  const india = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  return india.toISOString().slice(0, 10);
}

/**
 * The text of a cell. A text that a spreadsheet would run as a formula (`=`, `+`, `-`, `@`, tab or
 * return at the start) gets a quote in front, so a name typed as `=HYPERLINK(...)` stays a name.
 */
export function cellText(cell: Cell): string {
  if (cell === null || cell === undefined) return '';
  if (typeof cell === 'boolean') return cell ? 'Yes' : 'No';
  if (cell instanceof Date) return dayOf(cell);
  if (typeof cell === 'number') return String(cell);
  return /^[=+\-@\t\r]/.test(cell) ? `'${cell}` : cell;
}

/** One CSV line: a value with a comma, quote or line break is quoted. */
export function csvLine(values: readonly string[]): string {
  return values
    .map((value) => (/[",\r\n]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value))
    .join(',');
}

/** The byte order mark that tells Excel a CSV file is UTF-8 (Telugu and Hindi names stay readable). */
export const CSV_BOM = String.fromCharCode(0xfeff);

/** The table as CSV text, with the byte order mark first. */
export function csvOf(headers: readonly string[], rows: readonly (readonly string[])[]): string {
  return `${CSV_BOM}${[headers, ...rows].map(csvLine).join('\r\n')}\r\n`;
}

/** The table as an Excel file: a bold header row, a frozen top row and readable column widths. */
export async function xlsxOf(
  sheetName: string,
  headers: readonly string[],
  rows: readonly (readonly string[])[],
): Promise<Buffer> {
  const workbook = new Workbook();
  const sheet = workbook.addWorksheet(sheetName.slice(0, 31));
  sheet.addRow([...headers]).font = { bold: true };
  for (const row of rows) sheet.addRow([...row]);
  sheet.views = [{ state: 'frozen', ySplit: 1 }];
  headers.forEach((header, index) => {
    const longest = rows.reduce(
      (max, row) => Math.max(max, (row[index] ?? '').length),
      header.length,
    );
    sheet.getColumn(index + 1).width = Math.min(60, Math.max(10, longest + 2));
  });
  return Buffer.from(await workbook.xlsx.writeBuffer());
}

/** Every row of a list, page by page; refuses beyond [MAX_EXPORT_ROWS]. */
export async function collectAll<Row>(
  page: (pageNumber: number) => Promise<PaginatedResult<Row>>,
): Promise<Row[]> {
  const rows: Row[] = [];
  for (let pageNumber = 1; ; pageNumber += 1) {
    const result = await page(pageNumber);
    if (result.total > MAX_EXPORT_ROWS) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `This list has ${result.total} rows; an export holds at most ${MAX_EXPORT_ROWS}. Narrow the filters and try again.`,
      );
    }
    rows.push(...result.items);
    if (result.items.length === 0 || rows.length >= result.total) return rows;
  }
}

@Injectable()
export class CatalogueExportService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly permissions: EffectivePermissionsService,
  ) {}

  /**
   * Exports a list: reads every matching row through [page] (the list's own query), builds the
   * file and writes the audit entry. [filters] are what the person chose, kept in the entry.
   */
  async export<Row>(
    kind: ExportKind<Row>,
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    format: ExportFormat,
    filters: Readonly<Record<string, unknown>>,
    page: (pageNumber: number, pageSize: number) => Promise<PaginatedResult<Row>>,
  ): Promise<ExportFile> {
    const rows = await collectAll((pageNumber) => page(pageNumber, READ_PAGE_SIZE));
    const names = await this.namesFor(kind, rows);
    const table = rows.map((row) =>
      kind.columns.map((column) => cellText(column.value(row, names))),
    );
    const headers = kind.columns.map((column) => column.header);
    const body =
      format === 'csv'
        ? Buffer.from(csvOf(headers, table), 'utf8')
        : await xlsxOf(kind.key, headers, table);

    const roleKeys = (await this.permissions.forActor(actor)).roleKeys;
    await this.transactions.run((session) =>
      this.audit.record(
        {
          actor,
          actorRoleKeys: roleKeys,
          action: 'catalogue.exported',
          entityType: kind.key,
          entityId: new Types.ObjectId(),
          before: {},
          after: { format, rows: rows.length, filters: { ...filters } },
          client,
        },
        session,
      ),
    );
    return {
      body,
      contentType: CONTENT_TYPES[format],
      fileName: `${kind.key}-${dayOf(new Date())}.${format}`,
      rows: rows.length,
    };
  }

  private async namesFor<Row>(kind: ExportKind<Row>, rows: readonly Row[]): Promise<NameLookup> {
    const found = new Map<string, string>();
    for (const [model, ids] of Object.entries(kind.references?.(rows) ?? {})) {
      const unique = [...new Set(ids)].filter((id) => Types.ObjectId.isValid(id));
      if (unique.length === 0) continue;
      const records = await this.connection
        .model<Record<string, unknown>>(model)
        .find({ _id: { $in: unique.map((id) => new Types.ObjectId(id)) } })
        .setOptions({ withDeleted: true })
        .lean<Array<Record<string, unknown> & { _id: Types.ObjectId }>>()
        .exec();
      for (const record of records) {
        const name = record.name ?? record.companyName ?? record.title;
        found.set(`${model}:${record._id.toHexString()}`, typeof name === 'string' ? name : '');
      }
    }
    return (model, id) => (id ? (found.get(`${model}:${id}`) ?? '') : '');
  }
}
