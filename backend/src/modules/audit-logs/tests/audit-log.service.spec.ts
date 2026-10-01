import { type ClientSession, Types } from 'mongoose';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { type AuditLogRepository } from '../repositories/audit-log.repository';
import { type AuditLog } from '../schemas/audit-log.schema';
import { type AuditEntryInput, AuditLogService } from '../services/audit-log.service';

const ACTOR: AuthenticatedUserActor = {
  actorType: 'USER',
  userId: new Types.ObjectId().toHexString(),
  dataScope: { type: 'ALL', operatorIds: [] },
  userType: 'STAFF',
  sessionId: 'session',
  permissionVersion: 1,
  roleIds: [],
  mfaEnrollmentPending: false,
};

const inTransaction = { inTransaction: () => true } as unknown as ClientSession;
const noTransaction = { inTransaction: () => false } as unknown as ClientSession;

function setup() {
  const appended: AuditLog[] = [];
  const findMany = jest.fn().mockResolvedValue([]);
  const search = jest.fn().mockResolvedValue([]);
  const count = jest.fn().mockResolvedValue(0);
  const repository = {
    append: (entry: AuditLog) => {
      appended.push(entry);
      return Promise.resolve();
    },
    findMany,
    search,
    count,
  } as unknown as AuditLogRepository;
  return { service: new AuditLogService(repository), appended, search, count };
}

function entry(overrides: Partial<AuditEntryInput> = {}): AuditEntryInput {
  return {
    actor: ACTOR,
    actorRoleKeys: ['ADMIN'],
    action: 'user.roles.changed',
    entityType: 'user',
    entityId: new Types.ObjectId(),
    before: { roleKeys: ['BOOKING_STAFF'] },
    after: { roleKeys: ['OPERATOR_MANAGER'] },
    ...overrides,
  };
}

describe('AuditLogService', () => {
  it('records who, what, target, before, after, reason, request id and client', async () => {
    const { service, appended } = setup();
    const operatorId = new Types.ObjectId();
    const input = entry({
      operatorId,
      reason: 'Promoted to manager',
      client: { ip: '203.0.113.7', userAgent: 'AbraAdmin/1.0' },
    });

    await RequestContextService.run({ requestId: 'req-audit-1' }, () =>
      service.record(input, inTransaction),
    );

    expect(appended).toHaveLength(1);
    expect(appended[0]).toMatchObject({
      actor: { userType: 'STAFF', roleKeys: ['ADMIN'] },
      action: 'user.roles.changed',
      entityType: 'user',
      entityId: input.entityId,
      operatorId,
      before: { roleKeys: ['BOOKING_STAFF'] },
      after: { roleKeys: ['OPERATOR_MANAGER'] },
      reason: 'Promoted to manager',
      requestId: 'req-audit-1',
      ip: '203.0.113.7',
      userAgent: 'AbraAdmin/1.0',
    });
    expect(appended[0]?.actor.userId.toHexString()).toBe(ACTOR.userId);
    expect(appended[0]?.at).toBeInstanceOf(Date);
  });

  it('refuses to record outside a transaction (an entry must never outlive a rolled-back change)', async () => {
    const { service, appended } = setup();
    await expect(service.record(entry(), noTransaction)).rejects.toThrow('inside the transaction');
    expect(appended).toHaveLength(0);
  });

  it('omits optional fields instead of storing empty values', async () => {
    const { service, appended } = setup();
    await service.record(entry(), inTransaction);
    const stored = appended[0] as unknown as Record<string, unknown>;
    for (const field of ['operatorId', 'partnerId', 'reason', 'requestId', 'ip', 'userAgent']) {
      expect(stored).not.toHaveProperty(field);
    }
  });

  it('stores only what it is given: no session, token or credential fields', async () => {
    const { service, appended } = setup();
    await service.record(entry(), inTransaction);
    const serialized = JSON.stringify(appended[0]);
    expect(serialized).not.toContain('session');
    expect(serialized).not.toMatch(/password|token|secret|otp|recovery/i);
  });

  it('turns filters into a query that can only narrow, and paginates', async () => {
    const { service, search, count } = setup();
    const entityId = new Types.ObjectId().toHexString();
    const result = await service.search({
      action: 'user.permission-override.set',
      entityId,
      page: 3,
      pageSize: 10,
    });

    expect(search).toHaveBeenCalledWith(
      { action: 'user.permission-override.set', entityId: new Types.ObjectId(entityId) },
      { skip: 20, limit: 10 },
    );
    expect(count).toHaveBeenCalledTimes(1);
    expect(result).toMatchObject({ items: [], page: 3, pageSize: 10, total: 0 });
  });

  it('an id filter that cannot exist matches nothing instead of being dropped', async () => {
    const { service, search } = setup();
    await service.search({ operatorId: 'not-an-id', page: 1, pageSize: 20 });
    expect(search).toHaveBeenCalledWith({ operatorId: { $in: [] } }, { skip: 0, limit: 20 });
  });
});
