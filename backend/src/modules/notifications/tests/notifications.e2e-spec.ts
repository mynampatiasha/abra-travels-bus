import { randomUUID } from 'node:crypto';
import { type AddressInfo } from 'node:net';
import { Types } from 'mongoose';
import { io, type Socket } from 'socket.io-client';
import { DomainEventHandlerRegistry } from '../../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../../events/domain-event.types';
import { DevelopmentPushProvider } from '../../../integrations/push/development-push.provider';
import { PUSH_PROVIDER } from '../../../integrations/push/push-provider.interface';
import { DevelopmentWhatsAppProvider } from '../../../integrations/whatsapp/development-whatsapp.provider';
import { WhatsAppSettingsStore } from '../../../integrations/whatsapp/whatsapp-settings.store';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { type NotificationView } from '../services/notifications.service';
import { OnboardingNotificationHandler } from '../services/onboarding-notification.handler';

type Person = SeededUser & { tokens: Tokens };

const DEVICE = 'fcm-token-of-the-owners-laptop-aaaaaaaaaaaaaaaa';

/** Notifications: stored list, every channel, retries, and the live socket. */
describe('Notifications e2e', () => {
  let context: AuthTestContext;
  let reviewer: Person;
  let owner: Person;
  let otherOwner: Person;
  let handler: OnboardingNotificationHandler;
  let push: DevelopmentPushProvider;
  let whatsApp: DevelopmentWhatsAppProvider;
  const operatorId = new Types.ObjectId();

  const event = (type: string, payload: Record<string, unknown> = {}): DomainEventMessage => ({
    eventId: randomUUID(),
    type,
    aggregateType: 'onboarding_submission',
    aggregateId: 's1',
    occurredAt: new Date().toISOString(),
    payload: {
      submissionId: new Types.ObjectId().toHexString(),
      operatorId: operatorId.toHexString(),
      subjectType: 'OPERATOR',
      companyName: 'Alpha Lines',
      ...payload,
    },
  });

  const call = (who: Person, method: 'get' | 'post', path: string, body?: object) => {
    const request = client(context)
      [method](`/api/v1${path}`)
      .set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };

  const mine = async (who: Person, query = ''): Promise<NotificationView[]> =>
    dataOf<NotificationView[]>(await call(who, 'get', `/notifications${query}`).expect(200));

  beforeAll(async () => {
    context = await createAuthTestApp();
    reviewer = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    owner = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId });
    otherOwner = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: new Types.ObjectId(),
    });
    handler = context.app.get(OnboardingNotificationHandler);
    push = context.app.get<DevelopmentPushProvider>(PUSH_PROVIDER);
    whatsApp = context.whatsApp as DevelopmentWhatsAppProvider;
  }, 120_000);

  afterAll(async () => {
    await context.connection.collection('notifications').deleteMany({});
    await context.connection.collection('push_tokens').deleteMany({});
    await context.connection.collection('whatsapp_settings').deleteMany({});
    context.app.get(WhatsAppSettingsStore).invalidate();
    await context.close();
  }, 60_000);

  it('is registered for the onboarding events', () => {
    const registry = context.app.get(DomainEventHandlerRegistry);
    for (const type of ['onboarding.submitted', 'onboarding.approved', 'onboarding.rejected']) {
      expect(registry.handlersFor(type).map((item) => item.name)).toContain(
        'onboarding-notifications',
      );
    }
  });

  it('every call needs a sign-in', async () => {
    await client(context).get('/api/v1/notifications').expect(401);
    await client(context).get('/api/v1/notifications/unread-count').expect(401);
    await client(context).post('/api/v1/notifications/read-all').expect(401);
    await client(context).post('/api/v1/notifications/devices').send({}).expect(401);
  });

  it('a file sent for review tells the reviewers, not the owners', async () => {
    await handler.handle(event('onboarding.submitted'));
    const forReviewer = await mine(reviewer);
    expect(forReviewer[0]).toMatchObject({
      type: 'onboarding.submitted',
      title: 'New documents to review',
      body: 'Alpha Lines sent documents for review.',
      read: false,
    });
    expect(await mine(owner)).toEqual([]);
    expect(await mine(otherOwner)).toEqual([]);
  });

  describe('a decision tells the owner of that company only', () => {
    it('with the reasons', async () => {
      await call(owner, 'post', '/notifications/devices', {
        token: DEVICE,
        platform: 'WEB',
      }).expect(200);
      push.sent.length = 0;
      await handler.handle(
        event('onboarding.rejected', {
          note: 'Please fix the GST certificate',
          rejectedDocuments: [{ name: 'GST', reason: 'The image is blurred' }],
        }),
      );

      const list = await mine(owner);
      expect(list[0]?.title).toBe('Documents need fixing');
      expect(list[0]?.body).toContain('GST: The image is blurred');
      expect(list[0]?.data.route).toMatch(/^\/onboarding\//);
      expect(await mine(otherOwner)).toEqual([]);
      expect(await mine(reviewer)).toHaveLength(1);

      // the push went to the owner's registered browser, with the same words
      expect(push.sent).toHaveLength(1);
      expect(push.sent[0]?.tokens).toEqual([DEVICE]);
      expect(push.sent[0]?.message.title).toBe('Documents need fixing');
    });

    it('records what happened on each channel', async () => {
      const row = await context.connection
        .collection('notifications')
        .findOne({ userId: new Types.ObjectId(owner.id), type: 'onboarding.rejected' });
      const byChannel = Object.fromEntries(
        (row?.deliveries as Array<{ channel: string; status: string }>).map((item) => [
          item.channel,
          item.status,
        ]),
      );
      expect(byChannel).toEqual({
        REALTIME: 'SENT',
        PUSH: 'SENT',
        EMAIL: 'SENT',
        // no WhatsApp notification template is set up yet
        WHATSAPP: 'SKIPPED',
      });
    });
  });

  it('delivering the same event again does not repeat anything', async () => {
    const repeated = event('onboarding.approved');
    push.sent.length = 0;
    await handler.handle(repeated);
    await handler.handle(repeated);
    const approved = (await mine(owner)).filter((item) => item.type === 'onboarding.approved');
    expect(approved).toHaveLength(1);
    expect(push.sent).toHaveLength(1);
  });

  it('a push problem is retried, and only the push is repeated', async () => {
    const failing = event('onboarding.approved', {
      subjectType: 'BUS',
      busRegistrationNumber: 'KA01AB1234',
    });
    const spy = jest.spyOn(push, 'send').mockRejectedValueOnce(new Error('FCM is down'));
    await expect(handler.handle(failing)).rejects.toThrow(/will retry/);
    expect(spy).toHaveBeenCalledTimes(1);

    // the notification exists already, with the failed channel marked
    const row = await context.connection
      .collection('notifications')
      .findOne({ userId: new Types.ObjectId(owner.id), eventId: failing.eventId });
    expect(
      (row?.deliveries as Array<{ channel: string; status: string }>).find(
        (item) => item.channel === 'PUSH',
      )?.status,
    ).toBe('FAILED');

    await handler.handle(failing);
    expect(spy).toHaveBeenCalledTimes(2);
    const after = await context.connection
      .collection('notifications')
      .findOne({ userId: new Types.ObjectId(owner.id), eventId: failing.eventId });
    const statuses = (after?.deliveries as Array<{ channel: string; status: string }>).map(
      (item) => `${item.channel}:${item.status}`,
    );
    expect(statuses.sort()).toEqual([
      'EMAIL:SENT',
      'PUSH:SENT',
      'REALTIME:SENT',
      'WHATSAPP:SKIPPED',
    ]);
    spy.mockRestore();
  });

  it('sends WhatsApp once an administrator sets the notification template', async () => {
    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    await call(superAdmin, 'put' as never, '/settings/integrations/whatsapp').catch(
      () => undefined,
    );
    await context.connection.collection('whatsapp_settings').updateOne(
      { key: 'default' },
      {
        $set: {
          notificationTemplateName: 'abra_notification',
          notificationTemplateLanguage: 'en',
        },
      },
      { upsert: true },
    );
    context.app.get(WhatsAppSettingsStore).invalidate();

    const phone = (await context.users.findById(owner.id))?.phone ?? '';
    await handler.handle(event('onboarding.approved'));
    const sent = whatsApp.lastMessageTo(phone);
    expect(sent).toMatchObject({
      templateName: 'abra_notification',
      languageCode: 'en',
      purpose: 'NOTIFICATION',
    });
    expect(sent?.bodyParameters[0]).toBe('Company approved');
  });

  describe('the list belongs to its person', () => {
    it('counts, reads one, reads all', async () => {
      const unread = dataOf<{ count: number }>(
        await call(owner, 'get', '/notifications/unread-count').expect(200),
      ).count;
      expect(unread).toBeGreaterThan(2);
      expect(await mine(owner, '?unread=true')).toHaveLength(unread);

      const first = (await mine(owner))[0] as NotificationView;
      const afterOne = dataOf<{ count: number }>(
        await call(owner, 'post', `/notifications/${first.id}/read`).expect(200),
      );
      expect(afterOne.count).toBe(unread - 1);

      await call(owner, 'post', '/notifications/read-all').expect(200);
      expect(await mine(owner, '?unread=true')).toEqual([]);
      expect((await mine(owner)).length).toBe(unread);
    });

    it('nobody can read, or even find, someone else’s notification', async () => {
      const first = (await mine(reviewer))[0] as NotificationView;
      await call(owner, 'post', `/notifications/${first.id}/read`).expect(404);
      await call(owner, 'post', `/notifications/${new Types.ObjectId().toHexString()}/read`).expect(
        404,
      );
      await call(owner, 'post', '/notifications/not-an-id/read').expect(400);
      expect((await mine(reviewer))[0]?.read).toBe(false);
    });

    it('pages the list', async () => {
      const page = await call(owner, 'get', '/notifications?pageSize=2&page=1').expect(200);
      expect((page.body as { data: unknown[]; meta: { total: number } }).data).toHaveLength(2);
      expect((page.body as { meta: { total: number } }).meta.total).toBeGreaterThan(2);
    });
  });

  describe('devices', () => {
    const token = 'another-device-token-bbbbbbbbbbbbbbbbbbbbbbbb';

    it('are registered, move to whoever signs in last, and are removed at sign-out', async () => {
      await call(owner, 'post', '/notifications/devices', { token, platform: 'ANDROID' }).expect(
        200,
      );
      await call(reviewer, 'post', '/notifications/devices', { token, platform: 'ANDROID' }).expect(
        200,
      );
      const rows = await context.connection.collection('push_tokens').find({ token }).toArray();
      expect(rows).toHaveLength(1);
      expect(String(rows[0]?.userId)).toBe(reviewer.id);

      // the previous person cannot remove it any more
      await call(owner, 'post', '/notifications/devices/remove', { token }).expect(200);
      expect(await context.connection.collection('push_tokens').countDocuments({ token })).toBe(1);
      await call(reviewer, 'post', '/notifications/devices/remove', { token }).expect(200);
      expect(await context.connection.collection('push_tokens').countDocuments({ token })).toBe(0);
    });

    it('refuse nonsense', async () => {
      await call(owner, 'post', '/notifications/devices', {
        token: 'short',
        platform: 'WEB',
      }).expect(400);
      await call(owner, 'post', '/notifications/devices', { token, platform: 'FAX' }).expect(400);
    });
  });

  describe('the live socket', () => {
    let port: number;
    const sockets: Socket[] = [];

    beforeAll(async () => {
      const httpServer = context.app.getHttpServer();
      if (!httpServer.listening) {
        await new Promise<void>((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
      }
      port = (httpServer.address() as AddressInfo).port;
    });

    afterAll(() => {
      for (const socket of sockets) socket.close();
    });

    const connect = (token: string): Socket => {
      const socket = io(`http://127.0.0.1:${port}`, {
        auth: { token },
        transports: ['websocket'],
        reconnection: false,
      });
      sockets.push(socket);
      return socket;
    };

    const once = <T>(socket: Socket, name: string): Promise<T> =>
      new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`No "${name}" within 5 s`)), 5000);
        socket.once(name, (value: T) => {
          clearTimeout(timer);
          resolve(value);
        });
      });

    it('refuses a connection without a valid token', async () => {
      const socket = connect('not-a-token');
      const closed = new Promise((resolve) => socket.once('disconnect', resolve));
      await once(socket, 'unauthorized');
      await closed;
      expect(socket.connected).toBe(false);
    });

    it('tells the signed-in person the moment something happens, and nobody else', async () => {
      const mineSocket = connect(owner.tokens.accessToken);
      const otherSocket = connect(otherOwner.tokens.accessToken);
      await Promise.all([once(mineSocket, 'ready'), once(otherSocket, 'ready')]);

      let strangerHeard = false;
      otherSocket.on('notification', () => {
        strangerHeard = true;
      });
      const heard = once<{ title: string; body: string; data: { route: string } }>(
        mineSocket,
        'notification',
      );
      // handled by the same code the worker runs; Redis carries it to the API's sockets
      await handler.handle(event('onboarding.approved'));

      const message = await heard;
      expect(message.title).toBe('Company approved');
      expect(message.data.route).toMatch(/^\/onboarding\//);
      await new Promise((resolve) => setTimeout(resolve, 300));
      expect(strangerHeard).toBe(false);
    });
  });
});
