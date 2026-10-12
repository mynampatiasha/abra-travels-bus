import { z } from 'zod';
import { activeFlag, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { DOCUMENT_MIME_TYPES, DOCUMENT_SUBJECTS } from '../schemas/document-type.schema';

const name = z.string().trim().min(2).max(80);
const mimeTypes = z
  .array(z.enum(DOCUMENT_MIME_TYPES))
  .min(1)
  .max(DOCUMENT_MIME_TYPES.length)
  .refine((list) => new Set(list).size === list.length, {
    message: 'must not repeat a file type',
  });

const fields = {
  name,
  isRequired: z.boolean(),
  requiresExpiry: z.boolean(),
  allowedMimeTypes: mimeTypes,
  maxFileSizeMb: z.number().int().min(1).max(25),
  maxFiles: z.number().int().min(1).max(10),
  instructions: z.string().trim().max(500),
  sortOrder: z.number().int().min(0).max(100_000),
};

export class CreateDocumentTypeDto extends createZodDto(
  z.object({
    /** Stable key, e.g. VEHICLE_INSURANCE. Cannot be changed later. */
    key: z.string().regex(/^[A-Z][A-Z0-9_]{1,39}$/, 'upper-case letters, digits and underscores'),
    /** Cannot be changed later: documents already collected would no longer match. */
    appliesTo: z.enum(DOCUMENT_SUBJECTS),
    name: fields.name,
    isRequired: fields.isRequired.default(true),
    requiresExpiry: fields.requiresExpiry.default(false),
    allowedMimeTypes: fields.allowedMimeTypes.default([...DOCUMENT_MIME_TYPES]),
    maxFileSizeMb: fields.maxFileSizeMb.default(5),
    maxFiles: fields.maxFiles.default(1),
    instructions: fields.instructions.default(''),
    sortOrder: fields.sortOrder.default(0),
  }),
) {}

export class UpdateDocumentTypeDto extends createZodDto(
  z.object({
    name: fields.name.optional(),
    isRequired: fields.isRequired.optional(),
    requiresExpiry: fields.requiresExpiry.optional(),
    allowedMimeTypes: fields.allowedMimeTypes.optional(),
    maxFileSizeMb: fields.maxFileSizeMb.optional(),
    maxFiles: fields.maxFiles.optional(),
    instructions: fields.instructions.optional(),
    sortOrder: fields.sortOrder.optional(),
  }),
) {}

export class DocumentTypeListQueryDto extends createZodDto(
  z.object({
    appliesTo: z.enum(DOCUMENT_SUBJECTS).optional(),
    active: activeFlag,
    ...pagingShape,
  }),
) {}
