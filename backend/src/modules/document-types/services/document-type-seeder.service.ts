import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { DocumentTypeRepository } from '../repositories/document-type.repository';
import { type DocumentType } from '../schemas/document-type.schema';

const DOCUMENTS = ['application/pdf', 'image/jpeg', 'image/png'] as const;
const IMAGES = ['image/jpeg', 'image/png'] as const;

type Starter = Omit<DocumentType, 'isActive' | 'sortOrder'>;

/**
 * The documents a bus operator is asked for on first start. Platform staff change this list
 * afterwards in the management app, so these are only a starting point.
 */
export const STARTER_DOCUMENT_TYPES: readonly Starter[] = [
  {
    key: 'BUSINESS_REGISTRATION',
    name: 'Business registration',
    appliesTo: 'OPERATOR',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Company registration, partnership deed or shop establishment certificate.',
  },
  {
    key: 'GST_CERTIFICATE',
    name: 'GST certificate',
    appliesTo: 'OPERATOR',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'The GST registration certificate. Leave out only if you are not GST registered.',
  },
  {
    key: 'PAN_CARD',
    name: 'PAN card',
    appliesTo: 'OPERATOR',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'PAN card of the company or the owner.',
  },
  {
    key: 'OWNER_ID',
    name: 'Owner ID proof',
    appliesTo: 'OPERATOR',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 2,
    instructions: 'Aadhaar, passport or voter ID of the owner. Front and back if two-sided.',
  },
  {
    key: 'BANK_PROOF',
    name: 'Bank account proof',
    appliesTo: 'OPERATOR',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Cancelled cheque or bank statement page showing the account holder name.',
  },
  {
    key: 'BUS_RC',
    name: 'Registration certificate (RC)',
    appliesTo: 'BUS',
    isRequired: true,
    requiresExpiry: true,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 2,
    instructions: 'RC book or smart card of this bus, front and back.',
  },
  {
    key: 'BUS_PERMIT',
    name: 'Route permit',
    appliesTo: 'BUS',
    isRequired: true,
    requiresExpiry: true,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Valid permit for this bus (stage carriage, contract carriage or all-India).',
  },
  {
    key: 'BUS_INSURANCE',
    name: 'Insurance',
    appliesTo: 'BUS',
    isRequired: true,
    requiresExpiry: true,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Current insurance policy of this bus.',
  },
  {
    key: 'BUS_FITNESS',
    name: 'Fitness certificate',
    appliesTo: 'BUS',
    isRequired: true,
    requiresExpiry: true,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Current fitness certificate issued by the transport authority.',
  },
  {
    key: 'BUS_POLLUTION',
    name: 'Pollution certificate (PUC)',
    appliesTo: 'BUS',
    isRequired: false,
    requiresExpiry: true,
    allowedMimeTypes: [...DOCUMENTS],
    maxFileSizeMb: 5,
    maxFiles: 1,
    instructions: 'Current pollution under control certificate.',
  },
  {
    key: 'BUS_PHOTOS',
    name: 'Bus photos',
    appliesTo: 'BUS',
    isRequired: true,
    requiresExpiry: false,
    allowedMimeTypes: [...IMAGES],
    maxFileSizeMb: 5,
    maxFiles: 6,
    instructions: 'Clear photos: front, back, both sides, the inside and the seats.',
  },
];

/**
 * Fills `document_types` with the starter list when the collection is empty. It never adds to or
 * changes a collection that has entries, so what staff edited, disabled or removed stays as they
 * left it. Safe when the API and the worker start together: a duplicate key is ignored.
 */
@Injectable()
export class DocumentTypeSeeder implements OnApplicationBootstrap {
  private readonly logger = new Logger(DocumentTypeSeeder.name);

  constructor(private readonly types: DocumentTypeRepository) {}

  async onApplicationBootstrap(): Promise<void> {
    if ((await this.types.count()) > 0) return;
    let added = 0;
    for (const [index, starter] of STARTER_DOCUMENT_TYPES.entries()) {
      try {
        await this.types.insert({ ...starter, sortOrder: (index + 1) * 10, isActive: true });
        added += 1;
      } catch (error) {
        if ((error as { code?: number }).code !== 11000) throw error;
      }
    }
    this.logger.log({ added }, 'Starter document types added');
  }
}
