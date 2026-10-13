import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';

interface ChatBody {
  reply: string;
  turnId: string;
  toolsUsed: string[];
  proposals: Array<{ id: string; description: string }>;
}

/**
 * The assistant over HTTP, against the real application, MongoDB and Redis. The test application
 * uses the development assistant (no AI service), which still runs the real tools, so what is
 * checked here is the part around the model: sign-in, tools, proposals, confirmation, audit.
 */
describe('Assistant e2e', () => {
  let context: AuthTestContext;
  let superAdmin: SeededUser & { tokens: Tokens };
  let customer: SeededUser & { tokens: Tokens };
  let other: SeededUser & { tokens: Tokens };

  const api = () => client(context);
  const as = (who: { tokens: Tokens }) => bearer(who.tokens);
  const chat = (who: { tokens: Tokens }, content: string, language = 'en') =>
    api()
      .post('/api/v1/assistant/chat')
      .set(...as(who))
      .send({ messages: [{ role: 'user', content }], language });

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
    other = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
    const now = new Date();
    await context.connection.collection('notifications').insertMany(
      [1, 2, 3].map((n) => ({
        userId: new Types.ObjectId(customer.id),
        eventId: `assistant-e2e-${n}`,
        type: 'test',
        title: `Test notification ${n}`,
        body: 'body',
        data: {},
        readAt: null,
        deliveries: [],
        createdAt: now,
        updatedAt: now,
      })),
    );
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const setting = (body: object) =>
    api()
      .put('/api/v1/settings/integrations/assistant')
      .set(...as(superAdmin))
      .send(body);

  it('needs a signed-in person', async () => {
    await api().get('/api/v1/assistant/status').expect(401);
    await api()
      .post('/api/v1/assistant/chat')
      .send({ messages: [{ role: 'user', content: 'hi' }] })
      .expect(401);
  });

  it('says it is available for a customer, with the development provider', async () => {
    const status = dataOf<{ available: boolean; provider: string }>(
      await api()
        .get('/api/v1/assistant/status')
        .set(...as(customer))
        .expect(200),
    );
    expect(status).toEqual({ available: true, provider: 'development' });
  });

  it('answers from the real profile tool', async () => {
    const result = dataOf<ChatBody>(await chat(customer, 'who am i?').expect(200));
    expect(result.toolsUsed).toEqual(['my_profile']);
    expect(result.reply).toContain('CUSTOMER');
    expect(result.turnId).toMatch(/^[0-9a-f]{24}$/);
  });

  it('answers from the real notifications tool, with the right count', async () => {
    const result = dataOf<ChatBody>(
      await chat(customer, 'how many notifications do I have?').expect(200),
    );
    expect(result.toolsUsed).toEqual(['my_notifications']);
    expect(result.reply).toContain('3 unread');
    const mine = dataOf<ChatBody>(
      await chat(other, 'how many notifications do I have?').expect(200),
    );
    expect(mine.reply).toContain('0 unread'); // never someone else's data
  });

  it('keeps a turn log without the text of the conversation', async () => {
    const turns = await context.connection
      .collection('assistant_turns')
      .find({ userId: new Types.ObjectId(customer.id) })
      .toArray();
    expect(turns.length).toBeGreaterThanOrEqual(2);
    expect(JSON.stringify(turns)).not.toContain('how many notifications');
    expect(turns[0]).toMatchObject({ status: 'OK', provider: 'development' });
  });

  it('proposes no action until an administrator allows actions', async () => {
    const result = dataOf<ChatBody>(
      await chat(customer, 'please mark my notifications as read').expect(200),
    );
    expect(result.proposals).toEqual([]);
  });

  describe('with actions allowed', () => {
    beforeAll(async () => {
      await setting({ values: { allowActions: true }, reason: 'e2e' }).expect(200);
    });

    it('proposes the change, and nothing changes until the person confirms', async () => {
      const result = dataOf<ChatBody>(
        await chat(customer, 'please mark my notifications as read').expect(200),
      );
      expect(result.proposals).toHaveLength(1);
      expect(result.proposals[0]!.description).toBe('Mark 3 unread notifications as read');
      const count = dataOf<{ count: number }>(
        await api()
          .get('/api/v1/notifications/unread-count')
          .set(...as(customer))
          .expect(200),
      );
      expect(count.count).toBe(3);
    });

    it("does not let someone else confirm or decline another person's proposal", async () => {
      const result = dataOf<ChatBody>(
        await chat(customer, 'mark my notifications as read').expect(200),
      );
      const id = result.proposals[0]!.id;
      await api()
        .post(`/api/v1/assistant/actions/${id}/confirm`)
        .set(...as(other))
        .expect(404);
      await api()
        .post(`/api/v1/assistant/actions/${id}/decline`)
        .set(...as(other))
        .expect(404);
    });

    it('declining leaves everything as it was', async () => {
      const result = dataOf<ChatBody>(
        await chat(customer, 'mark my notifications as read').expect(200),
      );
      const declined = dataOf<{ status: string }>(
        await api()
          .post(`/api/v1/assistant/actions/${result.proposals[0]!.id}/decline`)
          .set(...as(customer))
          .expect(200),
      );
      expect(declined.status).toBe('DECLINED');
      const count = dataOf<{ count: number }>(
        await api()
          .get('/api/v1/notifications/unread-count')
          .set(...as(customer))
          .expect(200),
      );
      expect(count.count).toBe(3);
    });

    it('confirming makes the change, once, and writes an audit entry', async () => {
      const result = dataOf<ChatBody>(
        await chat(customer, 'mark my notifications as read').expect(200),
      );
      const id = result.proposals[0]!.id;
      const done = dataOf<{ status: string; message: string }>(
        await api()
          .post(`/api/v1/assistant/actions/${id}/confirm`)
          .set(...as(customer))
          .expect(200),
      );
      expect(done.status).toBe('DONE');
      const count = dataOf<{ count: number }>(
        await api()
          .get('/api/v1/notifications/unread-count')
          .set(...as(customer))
          .expect(200),
      );
      expect(count.count).toBe(0);
      await api()
        .post(`/api/v1/assistant/actions/${id}/confirm`)
        .set(...as(customer))
        .expect(404);
      const audit = dataOf<Array<{ action: string; entityId: string }>>(
        await api()
          .get('/api/v1/audit-logs?pageSize=30')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(
        audit.some(
          (entry) => entry.action === 'assistant.action.confirmed' && entry.entityId === id,
        ),
      ).toBe(true);
    });

    it('stops offering the action when there is nothing to do', async () => {
      const result = dataOf<ChatBody>(
        await chat(customer, 'mark my notifications as read').expect(200),
      );
      expect(result.proposals).toEqual([]);
      expect(result.reply).toContain('no unread');
    });

    it('refuses to confirm a change once actions are switched off again', async () => {
      await context.connection.collection('notifications').insertOne({
        userId: new Types.ObjectId(customer.id),
        eventId: 'assistant-e2e-late',
        type: 'test',
        title: 'Late',
        body: 'b',
        data: {},
        readAt: null,
        deliveries: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      const result = dataOf<ChatBody>(
        await chat(customer, 'mark my notifications as read').expect(200),
      );
      await setting({ values: { allowActions: false }, reason: 'e2e off' }).expect(200);
      await api()
        .post(`/api/v1/assistant/actions/${result.proposals[0]!.id}/confirm`)
        .set(...as(customer))
        .expect(403);
    });
  });

  it('checks the request: empty, wrong last speaker, too long, unknown language', async () => {
    const post = (body: object) =>
      api()
        .post('/api/v1/assistant/chat')
        .set(...as(customer))
        .send(body);
    await post({ messages: [], language: 'en' }).expect(400);
    await post({ messages: [{ role: 'assistant', content: 'hello' }] }).expect(400);
    await post({ messages: [{ role: 'user', content: 'x'.repeat(2001) }] }).expect(400);
    await post({ messages: [{ role: 'user', content: 'hi' }], language: 'xx' }).expect(400);
    await post({ messages: [{ role: 'system', content: 'hi' }] }).expect(400);
  });

  it('takes thumbs up on my own answer only', async () => {
    const result = dataOf<ChatBody>(await chat(customer, 'who am i?').expect(200));
    await api()
      .post(`/api/v1/assistant/messages/${result.turnId}/feedback`)
      .set(...as(customer))
      .send({ value: 'UP' })
      .expect(200);
    await api()
      .post(`/api/v1/assistant/messages/${result.turnId}/feedback`)
      .set(...as(other))
      .send({ value: 'UP' })
      .expect(404);
    await api()
      .post(`/api/v1/assistant/messages/${result.turnId}/feedback`)
      .set(...as(customer))
      .send({ value: 'MAYBE' })
      .expect(400);
  });

  it('can be switched off, and answers 503 with a sentence while it is off', async () => {
    await setting({ enabled: false, reason: 'e2e off' }).expect(200);
    const status = dataOf<{ available: boolean }>(
      await api()
        .get('/api/v1/assistant/status')
        .set(...as(customer))
        .expect(200),
    );
    expect(status.available).toBe(false);
    const response = await chat(customer, 'hi').expect(503);
    expect(JSON.stringify(response.body)).toContain('switched off');
    await setting({ enabled: true, reason: 'e2e on' }).expect(200);
    await chat(customer, 'hi').expect(200);
  });

  it('limits a person to 20 questions a minute', async () => {
    const fresh = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
    for (let i = 0; i < 20; i += 1) await chat(fresh, 'hi').expect(200);
    const blocked = await chat(fresh, 'hi').expect(429);
    expect(JSON.stringify(blocked.body)).toContain('retryAfterSeconds');
  });
});
