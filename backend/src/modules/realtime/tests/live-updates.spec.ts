import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  LivePublisher,
  type LiveSubject,
  LiveUpdatesService,
  MAX_TOPICS_PER_SOCKET,
  parseTopic,
  TopicAuthorizerRegistry,
} from '../live_updates_channel.service';

const oid = () => new Types.ObjectId();

describe('parseTopic', () => {
  it('splits well-formed topics', () => {
    expect(parseTopic('trip:abc123')).toEqual({ kind: 'trip', id: 'abc123' });
    expect(parseTopic('sos-board:64f0a1b2c3d4e5f6a7b8c9d0')).toEqual({
      kind: 'sos-board',
      id: '64f0a1b2c3d4e5f6a7b8c9d0',
    });
  });

  it.each([
    undefined,
    null,
    5,
    '',
    'trip',
    'trip:',
    ':abc',
    'Trip:abc',
    'trip:a b',
    'trip:a/b',
    'trip:' + 'x'.repeat(65),
    '1trip:abc',
  ])('refuses %p', (value) => {
    expect(parseTopic(value)).toBeUndefined();
  });
});

describe('TopicAuthorizerRegistry', () => {
  it('registers a kind once and refuses bad kinds', () => {
    const registry = new TopicAuthorizerRegistry();
    registry.register({ kind: 'trip', authorize: () => Promise.resolve(true) });
    expect(registry.get('trip')).toBeDefined();
    expect(registry.get('booking')).toBeUndefined();
    expect(() =>
      registry.register({ kind: 'trip', authorize: () => Promise.resolve(true) }),
    ).toThrow('twice');
    expect(() =>
      registry.register({ kind: 'Bad Kind', authorize: () => Promise.resolve(true) }),
    ).toThrow('Invalid topic kind');
  });
});

describe('LivePublisher', () => {
  function build() {
    const emitted: Array<{ room: string; event: string; message: Record<string, unknown> }> = [];
    const publisher = new LivePublisher({ publish: jest.fn() } as never);
    (publisher as unknown as { emitter: unknown }).emitter = {
      to: (room: string) => ({
        emit: (event: string, message: Record<string, unknown>) =>
          emitted.push({ room, event, message }),
      }),
    };
    return { publisher, emitted };
  }

  it('publishes to the right room, in one event named live, with the time', () => {
    const { publisher, emitted } = build();
    publisher.toUser('u1', 'report.approved', { id: 'r1' });
    publisher.toStaff('sos.raised', { id: 's1' });
    publisher.toOperator('op1', 'booking.created', {});
    publisher.toTopic('trip', 't1', 'seat.held', { seat: '1A' });
    expect(emitted.map((e) => [e.room, e.event, e.message.type])).toEqual([
      ['user:u1', 'live', 'report.approved'],
      ['staff', 'live', 'sos.raised'],
      ['operator:op1', 'live', 'booking.created'],
      ['topic:trip:t1', 'live', 'seat.held'],
    ]);
    expect(emitted[3]!.message).toMatchObject({ topic: 'trip:t1', data: { seat: '1A' } });
    expect(emitted[0]!.message).not.toHaveProperty('topic');
    expect(new Date(emitted[0]!.message.at as string).getTime()).not.toBeNaN();
  });

  it('refuses a badly named type and a record-sized payload', () => {
    const { publisher } = build();
    expect(() => publisher.toStaff('Bad Type')).toThrow('Invalid live event type');
    expect(() => publisher.toStaff('nodots')).toThrow('Invalid live event type');
    expect(() => publisher.toStaff('big.thing', { blob: 'x'.repeat(20_000) })).toThrow('too large');
  });
});

describe('LiveUpdatesService', () => {
  const userId = oid();
  const claims = {
    userId: userId.toHexString(),
    userType: 'STAFF' as const,
    sessionId: 'sess1',
    permissionVersion: 3,
  };

  function build(
    over: { token?: object | Error; session?: object | null; user?: object | null } = {},
  ) {
    const tokens = {
      verify: () =>
        over.token instanceof Error
          ? Promise.reject(over.token)
          : Promise.resolve(over.token ?? claims),
    };
    const sessions = {
      findActive: () =>
        Promise.resolve(
          over.session === undefined ? { mfaEnrollmentPending: false } : over.session,
        ),
    };
    const users = {
      findById: () =>
        Promise.resolve(
          over.user === undefined ? { status: 'ACTIVE', permissionVersion: 3 } : over.user,
        ),
    };
    const registry = new TopicAuthorizerRegistry();
    const service = new LiveUpdatesService(
      tokens as never,
      sessions as never,
      users as never,
      registry,
    );
    return { service, registry };
  }

  const subject = (over: Partial<LiveSubject> = {}): LiveSubject => ({ ...claims, ...over });

  it('accepts a valid token for an active session and user', async () => {
    const { service } = build();
    expect(await service.authenticate('t')).toMatchObject({
      userId: claims.userId,
      sessionId: 'sess1',
    });
  });

  it('keeps the operator id of operator staff', async () => {
    const operatorId = oid();
    const { service } = build({ user: { status: 'ACTIVE', permissionVersion: 3, operatorId } });
    expect((await service.authenticate('t'))?.operatorId).toBe(operatorId.toHexString());
  });

  it.each([
    ['a bad token', { token: new ApiException('UNAUTHENTICATED', 'x') }],
    ['a revoked session', { session: null }],
    ['an unknown user', { user: null }],
    ['a suspended user', { user: { status: 'SUSPENDED', permissionVersion: 3 } }],
    ['changed access', { user: { status: 'ACTIVE', permissionVersion: 4 } }],
    ['a session that still has to set up MFA', { session: { mfaEnrollmentPending: true } }],
  ])('refuses %s', async (_name, over) => {
    const { service } = build(over);
    expect(await service.authenticate('t')).toBeUndefined();
  });

  it('puts each kind of person in their own rooms', () => {
    const { service } = build();
    expect(service.roomsOf(subject())).toEqual([`user:${claims.userId}`, 'staff']);
    expect(service.roomsOf(subject({ userType: 'CUSTOMER' }))).toEqual([`user:${claims.userId}`]);
    expect(service.roomsOf(subject({ userType: 'OPERATOR_STAFF', operatorId: 'op9' }))).toEqual([
      `user:${claims.userId}`,
      'operator:op9',
    ]);
    expect(service.roomsOf(subject({ userType: 'DRIVER', operatorId: 'op9' }))).toEqual([
      `user:${claims.userId}`,
      'operator:op9',
    ]);
    expect(service.roomsOf(subject({ userType: 'OPERATOR_STAFF' }))).toEqual([
      `user:${claims.userId}`,
    ]);
  });

  describe('topics', () => {
    it('lets a person follow what its authorizer allows, and says nothing about why not', async () => {
      const { service, registry } = build();
      registry.register({ kind: 'trip', authorize: (_s, id) => Promise.resolve(id === 'mine') });
      expect(await service.authorizeTopic(subject(), 'trip:mine', 0)).toEqual({
        ok: true,
        room: 'topic:trip:mine',
      });
      expect(await service.authorizeTopic(subject(), 'trip:theirs', 0)).toEqual({
        ok: false,
        reason: 'not-allowed',
      });
      expect(await service.authorizeTopic(subject(), 'booking:mine', 0)).toEqual({
        ok: false,
        reason: 'not-allowed',
      });
    });

    it('refuses a malformed topic and too many topics', async () => {
      const { service, registry } = build();
      registry.register({ kind: 'trip', authorize: () => Promise.resolve(true) });
      expect(await service.authorizeTopic(subject(), 'nonsense', 0)).toEqual({
        ok: false,
        reason: 'bad-topic',
      });
      expect(await service.authorizeTopic(subject(), 'trip:a', MAX_TOPICS_PER_SOCKET)).toEqual({
        ok: false,
        reason: 'too-many',
      });
      expect(
        (await service.authorizeTopic(subject(), 'trip:a', MAX_TOPICS_PER_SOCKET - 1)).ok,
      ).toBe(true);
    });

    it('treats an authorizer that throws as "not allowed"', async () => {
      const { service, registry } = build();
      registry.register({
        kind: 'trip',
        authorize: () => Promise.reject(new Error('database down')),
      });
      expect(await service.authorizeTopic(subject(), 'trip:a', 0)).toEqual({
        ok: false,
        reason: 'not-allowed',
      });
    });
  });

  it('keeps a connection only while the same session and person are still valid', async () => {
    expect(await build().service.stillValid('t', subject())).toBe(true);
    expect(await build({ session: null }).service.stillValid('t', subject())).toBe(false);
    expect(await build().service.stillValid('t', subject({ sessionId: 'other' }))).toBe(false);
  });
});
