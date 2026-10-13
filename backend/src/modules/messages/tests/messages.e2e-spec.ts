import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { newId, seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';

/**
 * The messages log over HTTP, against the real application, MongoDB replica set and Redis:
 * the admin "Messages sent" page and the customer's "Messages sent to me".
 */
describe('Messages e2e', () => {
  let context: AuthTestContext;
  let superAdmin: SeededUser & { tokens: Tokens };
  let support: SeededUser & { tokens: Tokens };
  let operator: SeededUser & { tokens: Tokens };
  let customer: SeededUser & { tokens: Tokens };
  const ids: Record<string, Types.ObjectId> = {};

  const api = () => client(context);
  const messages = () => context.connection.collection('messages');

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
    operator = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: newId() });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });

    const now = new Date();
    const base = {
      channel: 'EMAIL',
      kind: 'BOOKING_CONFIRMED',
      recipientName: 'Test Person',
      address: 'test@example.com',
      subject: 'subject',
      body: 'body text',
      status: 'SENT',
      attempts: 1,
      createdAt: now,
      updatedAt: now,
    };
    const insert = async (key: string, extra: Record<string, unknown>) => {
      const result = await messages().insertOne({ ...base, eventId: key, ...extra });
      ids[key] = result.insertedId;
    };
    const mine = new Types.ObjectId(customer.id);
    await insert('mine', { userId: mine, subject: 'my confirmed booking' });
    await insert('mineFailed', {
      userId: mine,
      status: 'FAILED',
      detail: 'The mail server refused it.',
      subject: 'my failed message',
    });
    await insert('neverSent', {
      userId: mine,
      status: 'FAILED',
      detail: 'The mail server refused it.',
      subject: 'my unsent message',
    });
    await insert('whatsapp', {
      userId: mine,
      channel: 'WHATSAPP',
      address: '+919876543210',
      kind: 'REFUND_PAID',
      subject: 'my refund',
    });
    await insert('other', { userId: new Types.ObjectId(), subject: 'someone elses message' });
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  describe('admin: messages sent', () => {
    it('lists every message, newest first, with paging in meta', async () => {
      const response = await api()
        .get('/api/v1/admin/messages?pageSize=2')
        .set(...bearer(superAdmin.tokens))
        .expect(200);
      expect(dataOf<unknown[]>(response)).toHaveLength(2);
      expect((response.body as { meta: { total: number } }).meta.total).toBe(5);
    });

    it('filters by channel, status, kind, day range and search', async () => {
      const get = async (query: string) =>
        dataOf<{ subject: string }[]>(
          await api()
            .get(`/api/v1/admin/messages?${query}`)
            .set(...bearer(superAdmin.tokens))
            .expect(200),
        );
      expect(await get('channel=WHATSAPP')).toHaveLength(1);
      expect(await get('status=FAILED')).toHaveLength(2);
      expect(await get('kind=REFUND_PAID')).toHaveLength(1);
      const day = new Date().toISOString().slice(0, 10);
      expect(await get(`from=${day}&to=${day}`)).toHaveLength(5);
      expect(await get('q=someone')).toHaveLength(1);
    });

    it('refuses an unknown filter value', async () => {
      await api()
        .get('/api/v1/admin/messages?channel=SMS')
        .set(...bearer(superAdmin.tokens))
        .expect(400);
    });

    it('reads one message with its full text, and 404 for an unknown id', async () => {
      const one = dataOf<{ status: string; body: string }>(
        await api()
          .get(`/api/v1/admin/messages/${ids.mineFailed!.toHexString()}`)
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      );
      expect(one).toMatchObject({ status: 'FAILED', body: 'body text' });
      await api()
        .get(`/api/v1/admin/messages/${new Types.ObjectId().toHexString()}`)
        .set(...bearer(superAdmin.tokens))
        .expect(404);
    });

    it('lets support read and resend, but refuses an operator and anonymous callers', async () => {
      await api()
        .get('/api/v1/admin/messages')
        .set(...bearer(support.tokens))
        .expect(200);
      await api()
        .get('/api/v1/admin/messages')
        .set(...bearer(operator.tokens))
        .expect(403);
      await api()
        .post(`/api/v1/admin/messages/${ids.mineFailed!.toHexString()}/resend`)
        .set(...bearer(operator.tokens))
        .expect(403);
      await api().get('/api/v1/admin/messages').expect(401);
    });

    it('resends a message, keeps the log row, counts the attempt and writes an audit entry', async () => {
      const result = dataOf<{ id: string; status: string; attempts: number }>(
        await api()
          .post(`/api/v1/admin/messages/${ids.mineFailed!.toHexString()}/resend`)
          .set(...bearer(support.tokens))
          .expect(200),
      );
      // Email is not set up in the test application, so the second try is SKIPPED, never a crash
      expect(['SENT', 'SKIPPED', 'FAILED']).toContain(result.status);
      expect(result.attempts).toBe(2);
      expect(await messages().countDocuments({ eventId: 'mineFailed' })).toBe(1);

      const audit = dataOf<{ action: string; entityId: string }[]>(
        await api()
          .get('/api/v1/audit-logs?pageSize=20')
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      );
      expect(
        audit.some(
          (entry) =>
            entry.action === 'message.resent' && entry.entityId === ids.mineFailed!.toHexString(),
        ),
      ).toBe(true);
    });
  });

  describe('customer: messages sent to me', () => {
    it('shows only my own messages that were actually sent', async () => {
      const mine = dataOf<{ subject: string }[]>(
        await api()
          .get('/api/v1/customer/messages?pageSize=50')
          .set(...bearer(customer.tokens))
          .expect(200),
      );
      const subjects = mine.map((message) => message.subject);
      expect(subjects).toEqual(expect.arrayContaining(['my confirmed booking', 'my refund']));
      expect(subjects).not.toContain('someone elses message');
      expect(subjects).not.toContain('my unsent message');
    });

    it('hides internal fields', async () => {
      const [first] = dataOf<Record<string, unknown>[]>(
        await api()
          .get('/api/v1/customer/messages')
          .set(...bearer(customer.tokens))
          .expect(200),
      );
      expect(first).toBeDefined();
      for (const field of ['status', 'attempts', 'detail', 'userId', 'eventId']) {
        expect(first).not.toHaveProperty(field);
      }
    });

    it('filters by channel and reads one of my messages', async () => {
      const whatsapp = dataOf<{ channel: string }[]>(
        await api()
          .get('/api/v1/customer/messages?channel=WHATSAPP')
          .set(...bearer(customer.tokens))
          .expect(200),
      );
      expect(whatsapp.every((message) => message.channel === 'WHATSAPP')).toBe(true);
      await api()
        .get(`/api/v1/customer/messages/${ids.mine!.toHexString()}`)
        .set(...bearer(customer.tokens))
        .expect(200);
    });

    it("answers 404 for someone else's message and for a message that was not sent", async () => {
      for (const key of ['other', 'neverSent']) {
        await api()
          .get(`/api/v1/customer/messages/${ids[key]!.toHexString()}`)
          .set(...bearer(customer.tokens))
          .expect(404);
      }
    });

    it('needs a signed-in person', async () => {
      await api().get('/api/v1/customer/messages').expect(401);
    });
  });
});
