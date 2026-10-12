import { Body, Controller, Get, HttpCode, Injectable, Post, Put, Req } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Schema, Types, type Model } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ApiException } from '../../common/errors/api-exception';
import { clientRequestInfo, type ClientRequestInfo } from '../../common/http/client-request-info';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { AuditLogService } from '../audit-logs/services/audit-log.service';
import {
  DOCUMENT_TYPE_MODEL,
  type DocumentType,
} from '../document-types/schemas/document-type.schema';
import {
  documentTypeViewOf,
  type DocumentTypeView,
} from '../document-types/services/document-types.service';
import { type StoredDocumentType } from '../document-types/repositories/document-type.repository';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { EffectivePermissionsService } from '../rbac/services/effective-permissions.service';

const key = z
  .string()
  .min(1)
  .max(40)
  .regex(/^[a-z][a-z0-9_]*$/);
const option = z.object({ value: key, label: z.string().trim().min(1).max(120) }).strict();
const question = z
  .object({
    key,
    label: z.string().trim().min(1).max(200),
    help: z.string().trim().max(500).default(''),
    appliesTo: z.enum(['OPERATOR', 'BUS']),
    type: z.enum(['SINGLE_CHOICE', 'MULTI_CHOICE', 'BOOLEAN']),
    options: z.array(option).max(20),
    required: z.boolean(),
    active: z.boolean(),
    sortOrder: z.number().int().min(0).max(9999),
  })
  .strict()
  .superRefine((q, ctx) => {
    if (q.type === 'BOOLEAN' ? q.options.length !== 0 : q.options.length < 2) {
      ctx.addIssue({
        code: 'custom',
        path: ['options'],
        message: 'Yes/no questions have no custom options; choice questions need at least two.',
      });
    }
    if (new Set(q.options.map((o) => o.value)).size !== q.options.length) {
      ctx.addIssue({ code: 'custom', path: ['options'], message: 'Answer values must be unique.' });
    }
  });
const rule = z
  .object({
    key,
    name: z.string().trim().min(1).max(120),
    appliesTo: z.enum(['OPERATOR', 'BUS']),
    documentKey: z
      .string()
      .min(1)
      .max(40)
      .regex(/^[A-Z][A-Z0-9_]*$/),
    required: z.boolean(),
    active: z.boolean(),
    match: z.enum(['ALL', 'ANY']),
    conditions: z
      .array(
        z
          .object({ questionKey: key, values: z.array(z.string().min(1).max(40)).min(1).max(20) })
          .strict(),
      )
      .max(10),
  })
  .strict();
export const kycConfigurationSchema = z
  .object({
    schemaVersion: z.literal(1),
    questions: z.array(question).max(100),
    rules: z.array(rule).max(500),
  })
  .strict();
export type KycConfiguration = z.output<typeof kycConfigurationSchema>;
export type KycQuestion = KycConfiguration['questions'][number];
export type KycRule = KycConfiguration['rules'][number];
export type KycAnswers = Record<string, string | string[]>;

export class SaveKycConfigurationDto extends createZodDto(
  kycConfigurationSchema.extend({
    expectedVersion: z.number().int().nonnegative(),
    reason: z.string().trim().min(3).max(300),
  }),
) {}
export class PreviewKycDto extends createZodDto(
  z.object({
    appliesTo: z.enum(['OPERATOR', 'BUS']),
    answers: z
      .record(z.string(), z.union([z.string().max(40), z.array(z.string().max(40)).max(20)]))
      .refine((a) => Object.keys(a).length <= 100, 'Too many answers'),
  }),
) {}

export function kycAnswerOptions(q: KycQuestion) {
  return q.type === 'BOOLEAN'
    ? [
        { value: 'true', label: 'Yes' },
        { value: 'false', label: 'No' },
      ]
    : q.options;
}
function invalid(message: string): never {
  throw new ApiException('VALIDATION_FAILED', message);
}

/** Used by ordinary edits and bulk imports, so neither can leave dangling rules. */
export function validateKycConfiguration(
  config: KycConfiguration,
  documents: DocumentTypeView[],
): void {
  if (new Set(config.questions.map((q) => q.key)).size !== config.questions.length)
    invalid('Question keys must be unique.');
  if (new Set(config.rules.map((r) => r.key)).size !== config.rules.length)
    invalid('Rule keys must be unique.');
  const questions = new Map(config.questions.map((q) => [q.key, q]));
  const types = new Map(documents.map((d) => [d.key, d]));
  for (const r of config.rules) {
    const doc = types.get(r.documentKey);
    if (!doc || doc.appliesTo !== r.appliesTo)
      invalid(`Rule "${r.name}" needs an existing document for the same subject.`);
    if (r.active && !doc.isActive)
      invalid(`Enable document "${doc.name}" before enabling rule "${r.name}".`);
    if (new Set(r.conditions.map((c) => c.questionKey)).size !== r.conditions.length)
      invalid(`Rule "${r.name}" repeats a question.`);
    for (const c of r.conditions) {
      const q = questions.get(c.questionKey);
      if (!q || q.appliesTo !== r.appliesTo)
        invalid(`Rule "${r.name}" refers to a missing question or a different subject.`);
      if (r.active && !q.active)
        invalid(`Disable rules using "${q.label}" before disabling the question.`);
      const options = new Set(kycAnswerOptions(q).map((o) => o.value));
      if (new Set(c.values).size !== c.values.length || c.values.some((v) => !options.has(v)))
        invalid(`Rule "${r.name}" refers to an invalid or repeated answer.`);
    }
  }
}

/** Server-owned evaluation; a matching required rule wins over optional rules for one document. */
export function resolveKycRequirements(
  config: KycConfiguration,
  documents: DocumentTypeView[],
  subject: 'OPERATOR' | 'BUS',
  answers: KycAnswers,
) {
  const questions = config.questions.filter((q) => q.active && q.appliesTo === subject);
  const byKey = new Map(questions.map((q) => [q.key, q]));
  for (const [name, answer] of Object.entries(answers)) {
    const q = byKey.get(name);
    if (!q) invalid(`Unknown question "${name}".`);
    if (q.type === 'MULTI_CHOICE' ? !Array.isArray(answer) : typeof answer !== 'string')
      invalid(`Invalid answer format for "${q.label}".`);
    const values = Array.isArray(answer) ? answer : [answer];
    const allowed = new Set(kycAnswerOptions(q).map((o) => o.value));
    if (new Set(values).size !== values.length || values.some((v) => !allowed.has(v)))
      invalid(`Invalid answer for "${q.label}".`);
  }
  const missingQuestions = questions
    .filter((q) => {
      const answer = Object.hasOwn(answers, q.key) ? answers[q.key] : undefined;
      return q.required && (answer === undefined || (Array.isArray(answer) && answer.length === 0));
    })
    .map((q) => q.key);
  const required = new Map<string, boolean>();
  for (const r of config.rules.filter((r) => r.active && r.appliesTo === subject)) {
    // A disabled or removed question must never accidentally enable a document.
    const matches = r.conditions.map((c) => {
      if (!byKey.has(c.questionKey)) return false;
      const answer = Object.hasOwn(answers, c.questionKey) ? answers[c.questionKey] : undefined;
      const selected = answer === undefined ? [] : Array.isArray(answer) ? answer : [answer];
      return c.values.some((v) => selected.includes(v));
    });
    if (
      r.conditions.length === 0 ||
      (r.match === 'ALL' ? matches.every(Boolean) : matches.some(Boolean))
    )
      required.set(r.documentKey, (required.get(r.documentKey) ?? false) || r.required);
  }
  return {
    missingQuestions,
    documents: documents
      .filter((d) => d.isActive && d.appliesTo === subject && required.has(d.key))
      .map((d) => ({ ...d, isRequired: required.get(d.key)! }))
      .sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name)),
  };
}

export const KYC_CONFIGURATION_MODEL = 'KycConfiguration';
const CONFIG_ID = new Types.ObjectId('0000000000000000000000c1');
interface StoredConfiguration extends KycConfiguration {
  _id: Types.ObjectId;
  version: number;
  updatedAt?: Date;
}
export const kycConfigurationMongoSchema = new Schema<StoredConfiguration>(
  {
    schemaVersion: { type: Number, required: true, enum: [1] },
    version: { type: Number, required: true },
    questions: { type: Schema.Types.Mixed, required: true },
    rules: { type: Schema.Types.Mixed, required: true },
  },
  { collection: 'kyc_configuration', timestamps: true, versionKey: false },
);
const emptyConfig = (): KycConfiguration => ({ schemaVersion: 1, questions: [], rules: [] });

@Injectable()
export class AdminKycConfigurationService {
  constructor(
    @InjectModel(KYC_CONFIGURATION_MODEL) private readonly configs: Model<StoredConfiguration>,
    @InjectModel(DOCUMENT_TYPE_MODEL) private readonly documentTypes: Model<DocumentType>,
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly permissions: EffectivePermissionsService,
  ) {}

  private assertPlatform(actor: AuthenticatedUserActor): void {
    if (actor.userType !== 'STAFF')
      throw new ApiException(
        'PERMISSION_DENIED',
        'Only platform staff can manage KYC configuration.',
      );
  }
  private async documentViews() {
    return (
      await this.documentTypes
        .find()
        .sort({ sortOrder: 1, name: 1 })
        .lean<StoredDocumentType[]>()
        .exec()
    ).map(documentTypeViewOf);
  }
  async describe(actor: AuthenticatedUserActor) {
    this.assertPlatform(actor);
    const [stored, documents] = await Promise.all([
      this.configs.findById(CONFIG_ID).lean<StoredConfiguration>().exec(),
      this.documentViews(),
    ]);
    return {
      schemaVersion: 1 as const,
      version: stored?.version ?? 0,
      questions: stored?.questions ?? [],
      rules: stored?.rules ?? [],
      documents,
      updatedAt: stored?.updatedAt?.toISOString() ?? null,
    };
  }
  async validate(actor: AuthenticatedUserActor, input: SaveKycConfigurationDto) {
    this.assertPlatform(actor);
    const config = kycConfigurationSchema.parse({
      schemaVersion: input.schemaVersion,
      questions: input.questions,
      rules: input.rules,
    });
    validateKycConfiguration(config, await this.documentViews());
    return { valid: true, questions: config.questions.length, rules: config.rules.length };
  }
  async save(
    actor: AuthenticatedUserActor,
    input: SaveKycConfigurationDto,
    client: ClientRequestInfo,
  ) {
    await this.validate(actor, input);
    const config = kycConfigurationSchema.parse({
      schemaVersion: input.schemaVersion,
      questions: input.questions,
      rules: input.rules,
    });
    const roles = (await this.permissions.forActor(actor)).roleKeys;
    try {
      await this.transactions.run(async (session) => {
        const before = await this.configs
          .findById(CONFIG_ID)
          .session(session)
          .lean<StoredConfiguration>()
          .exec();
        if ((before?.version ?? 0) !== input.expectedVersion)
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'Another administrator changed the configuration. Refresh and try again.',
          );
        const after = await this.configs
          .findOneAndUpdate(
            { _id: CONFIG_ID, version: input.expectedVersion },
            { $set: config, $inc: { version: 1 } },
            { upsert: before === null, returnDocument: 'after', session, runValidators: true },
          )
          .lean<StoredConfiguration>()
          .exec();
        if (!after)
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'Configuration changed. Refresh and try again.',
          );
        await this.audit.record(
          {
            actor,
            actorRoleKeys: roles,
            action: 'catalogue.updated',
            entityType: 'kyc_configuration',
            entityId: CONFIG_ID,
            before: before
              ? {
                  schemaVersion: 1,
                  version: before.version,
                  questions: before.questions,
                  rules: before.rules,
                }
              : emptyConfig(),
            after: { ...config, version: after.version },
            reason: input.reason,
            client,
          },
          session,
        );
      });
    } catch (error) {
      if ((error as { code?: unknown })?.code === 11000)
        throw new ApiException(
          'INVALID_STATE_TRANSITION',
          'Another administrator changed the configuration. Refresh and try again.',
        );
      throw error;
    }
    return this.describe(actor);
  }
  async preview(actor: AuthenticatedUserActor, input: PreviewKycDto) {
    const config = await this.describe(actor);
    return resolveKycRequirements(config, config.documents, input.appliesTo, input.answers);
  }
}

@ApiTags('settings')
@Controller('settings/kyc-configuration')
export class AdminKycConfigurationController {
  constructor(private readonly settings: AdminKycConfigurationService) {}

  @Get()
  @RequirePermission('documents.read')
  describe(@CurrentActor() actor: AuthenticatedUserActor) {
    return this.settings.describe(actor);
  }

  @Put()
  @RequirePermission('documents.manage')
  @ZodApiBody(SaveKycConfigurationDto)
  save(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() input: SaveKycConfigurationDto,
    @Req() req: Request,
  ) {
    return this.settings.save(actor, input, clientRequestInfo(req));
  }

  @Post('validate-import')
  @HttpCode(200)
  @RequirePermission('documents.manage')
  @ZodApiBody(SaveKycConfigurationDto)
  validate(@CurrentActor() actor: AuthenticatedUserActor, @Body() input: SaveKycConfigurationDto) {
    return this.settings.validate(actor, input);
  }

  @Post('preview')
  @HttpCode(200)
  @RequirePermission('documents.read')
  @ZodApiBody(PreviewKycDto)
  preview(@CurrentActor() actor: AuthenticatedUserActor, @Body() input: PreviewKycDto) {
    return this.settings.preview(actor, input);
  }
}
