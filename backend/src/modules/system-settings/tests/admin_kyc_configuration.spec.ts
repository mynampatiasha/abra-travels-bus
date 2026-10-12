import { Types, type Model } from 'mongoose';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { type DocumentType } from '../../document-types/schemas/document-type.schema';
import { type DocumentTypeView } from '../../document-types/services/document-types.service';
import { EffectivePermissionsService } from '../../rbac/services/effective-permissions.service';
import {
  AdminKycConfigurationService,
  kycConfigurationSchema,
  resolveKycRequirements,
  validateKycConfiguration,
  type KycConfiguration,
  type KycQuestion,
  type KycRule,
} from '../admin_kyc_configuration';

const ownership: KycQuestion = {
  key: 'ownership',
  label: 'Do you own or lease buses?',
  help: '',
  appliesTo: 'OPERATOR',
  type: 'SINGLE_CHOICE',
  options: [
    { value: 'own', label: 'Own' },
    { value: 'lease', label: 'Lease' },
  ],
  required: true,
  active: true,
  sortOrder: 0,
};
const document: DocumentTypeView = {
  id: new Types.ObjectId().toHexString(),
  key: 'LEASE_AGREEMENT',
  name: 'Lease agreement',
  appliesTo: 'OPERATOR',
  isRequired: false,
  requiresExpiry: false,
  allowedMimeTypes: ['application/pdf'],
  maxFileSizeMb: 5,
  maxFiles: 1,
  instructions: 'Upload a signed agreement',
  sortOrder: 1,
  isActive: true,
};
const leaseRule: KycRule = {
  key: 'lease_rule',
  name: 'Leased buses',
  appliesTo: 'OPERATOR',
  documentKey: document.key,
  required: true,
  active: true,
  match: 'ALL',
  conditions: [{ questionKey: ownership.key, values: ['lease'] }],
};
const config = (questions = [ownership], rules = [leaseRule]): KycConfiguration => ({
  schemaVersion: 1,
  questions,
  rules,
});

describe('KYC configuration and answer-based checklist', () => {
  it('shows conditional documents only for matching answers', () => {
    validateKycConfiguration(config(), [document]);
    expect(
      resolveKycRequirements(config(), [document], 'OPERATOR', { ownership: 'own' }).documents,
    ).toEqual([]);
    expect(
      resolveKycRequirements(config(), [document], 'OPERATOR', { ownership: 'lease' }).documents,
    ).toEqual([{ ...document, isRequired: true }]);
  });
  it('reports missing required answers without treating them as matching conditions', () => {
    expect(resolveKycRequirements(config(), [document], 'OPERATOR', {})).toEqual({
      missingQuestions: ['ownership'],
      documents: [],
    });
    expect(
      resolveKycRequirements(
        config([{ ...ownership, key: 'constructor' }], []),
        [document],
        'OPERATOR',
        {},
      ).missingQuestions,
    ).toEqual(['constructor']);
  });
  it('combines conditions with ALL and ANY, including yes/no answers', () => {
    const registered: KycQuestion = {
      ...ownership,
      key: 'registered',
      type: 'BOOLEAN',
      options: [],
    };
    const rule: KycRule = {
      ...leaseRule,
      conditions: [...leaseRule.conditions, { questionKey: 'registered', values: ['true'] }],
    };
    const answers = { ownership: 'lease', registered: 'false' };
    expect(
      resolveKycRequirements(
        config([ownership, registered], [rule]),
        [document],
        'OPERATOR',
        answers,
      ).documents,
    ).toHaveLength(0);
    expect(
      resolveKycRequirements(
        config([ownership, registered], [{ ...rule, match: 'ANY' }]),
        [document],
        'OPERATOR',
        answers,
      ).documents,
    ).toHaveLength(1);
  });
  it('matches multiple-choice answers and rejects malformed or repeated answers', () => {
    const multi: KycQuestion = { ...ownership, type: 'MULTI_CHOICE' };
    expect(
      resolveKycRequirements(config([multi]), [document], 'OPERATOR', {
        ownership: ['own', 'lease'],
      }).documents,
    ).toHaveLength(1);
    expect(() =>
      resolveKycRequirements(config([multi]), [document], 'OPERATOR', { ownership: 'lease' }),
    ).toThrow(/format/);
    expect(() =>
      resolveKycRequirements(config([multi]), [document], 'OPERATOR', {
        ownership: ['lease', 'lease'],
      }),
    ).toThrow(/Invalid answer/);
    expect(() =>
      resolveKycRequirements(config(), [document], 'OPERATOR', { ownership: 'other' }),
    ).toThrow(/Invalid answer/);
    expect(() =>
      resolveKycRequirements(config(), [document], 'OPERATOR', { injected: 'lease' }),
    ).toThrow(/Unknown question/);
  });
  it('deduplicates documents and keeps them required if any matching rule requires them', () => {
    const optional: KycRule = { ...leaseRule, key: 'optional', conditions: [], required: false };
    expect(
      resolveKycRequirements(config([ownership], [optional, leaseRule]), [document], 'OPERATOR', {
        ownership: 'lease',
      }).documents,
    ).toEqual([{ ...document, isRequired: true }]);
    expect(
      resolveKycRequirements(config([ownership], [optional]), [document], 'OPERATOR', {
        ownership: 'own',
      }).documents[0]?.isRequired,
    ).toBe(false);
  });
  it('does not show inactive rules, documents or questions and separates company from bus', () => {
    expect(
      resolveKycRequirements(
        config([ownership], [{ ...leaseRule, active: false }]),
        [document],
        'OPERATOR',
        { ownership: 'lease' },
      ).documents,
    ).toHaveLength(0);
    expect(
      resolveKycRequirements(config(), [{ ...document, isActive: false }], 'OPERATOR', {
        ownership: 'lease',
      }).documents,
    ).toHaveLength(0);
    expect(
      resolveKycRequirements(config([{ ...ownership, active: false }]), [document], 'OPERATOR', {})
        .documents,
    ).toHaveLength(0);
    expect(resolveKycRequirements(config(), [document], 'BUS', {}).documents).toHaveLength(0);
  });
  it('rejects deletion or disabling of a question used by a rule', () => {
    expect(() => validateKycConfiguration(config([], [leaseRule]), [document])).toThrow(
      /missing question/,
    );
    expect(() =>
      validateKycConfiguration(config([{ ...ownership, active: false }]), [document]),
    ).toThrow(/Disable rules/);
  });
  it('rejects invalid answer references, document references, subjects and duplicate keys', () => {
    expect(() =>
      validateKycConfiguration(
        config(
          [ownership],
          [{ ...leaseRule, conditions: [{ questionKey: 'ownership', values: ['invalid'] }] }],
        ),
        [document],
      ),
    ).toThrow(/invalid/);
    expect(() => validateKycConfiguration(config(), [])).toThrow(/existing document/);
    expect(() => validateKycConfiguration(config(), [{ ...document, appliesTo: 'BUS' }])).toThrow(
      /same subject/,
    );
    expect(() => validateKycConfiguration(config([ownership, ownership]), [document])).toThrow(
      /unique/,
    );
    expect(() =>
      validateKycConfiguration(config([ownership], [leaseRule, leaseRule]), [document]),
    ).toThrow(/unique/);
    expect(() => validateKycConfiguration(config(), [{ ...document, isActive: false }])).toThrow(
      /Enable document/,
    );
  });
  it('rejects imports with an unknown format, extra fields, empty choice options or repeated answer values', () => {
    for (const input of [
      { ...config(), schemaVersion: 2 },
      { ...config(), version: 5 },
      config([{ ...ownership, options: [] }]),
      config([{ ...ownership, options: [ownership.options[0]!, ownership.options[0]!] }]),
    ])
      expect(kycConfigurationSchema.safeParse(input).success).toBe(false);
    expect(kycConfigurationSchema.parse(config())).toEqual(config());
  });
});

describe('KYC administration authorization and concurrent edits', () => {
  const staff = {
    userType: 'STAFF',
    userId: new Types.ObjectId().toHexString(),
  } as AuthenticatedUserActor;
  function service(version: number) {
    const writes: unknown[] = [];
    const audits: unknown[] = [];
    const stored = { ...config(), version, _id: new Types.ObjectId() };
    const query = { session: () => query, lean: () => query, exec: () => Promise.resolve(stored) };
    const configs = {
      findById: () => query,
      findOneAndUpdate: (_filter: unknown, update: unknown) => {
        writes.push(update);
        return {
          lean: () => ({ exec: () => Promise.resolve({ ...stored, version: version + 1 }) }),
        };
      },
    };
    const docs = {
      find: () => ({
        sort: () => ({
          lean: () => ({
            exec: () => Promise.resolve([{ ...document, _id: new Types.ObjectId(document.id) }]),
          }),
        }),
      }),
    };
    const instance = new AdminKycConfigurationService(
      configs as unknown as ConstructorParameters<typeof AdminKycConfigurationService>[0],
      docs as unknown as Model<DocumentType>,
      {
        run: (work: (session: object) => Promise<unknown>) => work({}),
      } as unknown as TransactionRunner,
      {
        record: (entry: unknown) => {
          audits.push(entry);
          return Promise.resolve();
        },
      } as unknown as AuditLogService,
      {
        forActor: () => Promise.resolve({ roleKeys: ['ADMIN'] }),
      } as unknown as EffectivePermissionsService,
    );
    return { instance, writes, audits };
  }
  it('refuses operator accounts even if they hold document permissions', async () => {
    const { instance } = service(1);
    await expect(instance.describe({ ...staff, userType: 'OPERATOR_STAFF' })).rejects.toMatchObject(
      { code: 'PERMISSION_DENIED' },
    );
    await expect(
      instance.validate(
        { ...staff, userType: 'OPERATOR_STAFF' },
        { ...config(), expectedVersion: 1, reason: 'Import config' },
      ),
    ).rejects.toMatchObject({ code: 'PERMISSION_DENIED' });
  });
  it('refuses stale writes and makes no database or audit changes', async () => {
    const { instance, writes, audits } = service(2);
    await expect(
      instance.save(
        staff,
        { ...config(), expectedVersion: 1, reason: 'Update config' },
        { ip: '127.0.0.1' },
      ),
    ).rejects.toMatchObject({ code: 'INVALID_STATE_TRANSITION' });
    expect(writes).toHaveLength(0);
    expect(audits).toHaveLength(0);
  });
  it('records the configuration change and its reason with the write', async () => {
    const { instance, writes, audits } = service(2);
    await instance.save(
      staff,
      { ...config(), expectedVersion: 2, reason: 'Updated lease rule' },
      { ip: '127.0.0.1' },
    );
    expect(writes).toHaveLength(1);
    expect(audits).toHaveLength(1);
    expect(audits[0]).toMatchObject({
      entityType: 'kyc_configuration',
      reason: 'Updated lease rule',
      after: { version: 3 },
    });
  });
});
