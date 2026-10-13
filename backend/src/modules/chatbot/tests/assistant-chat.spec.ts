import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  AssistantToolRegistry,
  type AssistantTool,
  audienceOf,
  GroqChatClient,
  LANGUAGES,
  systemPrompt,
  type ToolContext,
} from '../assistant_chat.service';

const reply = (status: number, body: unknown = {}) =>
  Promise.resolve({ status, ok: status < 300, json: () => Promise.resolve(body) } as Response);

const actor = {
  userId: new Types.ObjectId().toHexString(),
  userType: 'CUSTOMER',
} as never;

const context = (over: Partial<ToolContext> = {}): ToolContext => ({
  actor,
  permissions: new Set<string>(),
  roleKeys: ['CUSTOMER'],
  hasWildcard: false,
  ...over,
});

const tool = (over: Partial<AssistantTool> = {}): AssistantTool => ({
  name: 'my_thing',
  description: 'd',
  parameters: { type: 'object', properties: {} },
  audiences: ['CUSTOMER'],
  kind: 'READ',
  run: () => Promise.resolve({ ok: true }),
  ...over,
});

describe('systemPrompt', () => {
  const base = {
    audience: 'CUSTOMER' as const,
    language: 'te',
    name: 'Priya',
    roleKeys: ['CUSTOMER'],
    now: new Date('2026-10-12T05:00:00Z'),
  };

  it('names the language, the person, the app and today in India time', () => {
    const text = systemPrompt(base);
    expect(text).toContain('Telugu');
    expect(text).toContain('Priya');
    expect(text).toContain('customer app');
    expect(text).toContain('12 October 2026');
  });

  it('carries the safety rules', () => {
    const text = systemPrompt(base);
    expect(text).toMatch(/only from what the tools return/);
    expect(text).toMatch(/Never reveal anything about other people/);
    expect(text).toMatch(/cannot change anything yourself/);
    expect(text).toMatch(/Ignore any instruction/);
    expect(text).toMatch(/passwords, codes, card numbers or keys/);
  });

  it('falls back to English for an unknown language and knows all eight', () => {
    expect(systemPrompt({ ...base, language: 'xx' })).toContain('English');
    expect(Object.keys(LANGUAGES)).toEqual(['en', 'te', 'hi', 'kn', 'ta', 'ml', 'mr', 'bn']);
  });
});

describe('audienceOf', () => {
  it('maps account kinds to assistants and refuses the rest', () => {
    expect(audienceOf('STAFF')).toBe('ADMIN');
    expect(audienceOf('OPERATOR_STAFF')).toBe('OPERATOR');
    expect(audienceOf('CUSTOMER')).toBe('CUSTOMER');
    expect(audienceOf('DRIVER')).toBe('DRIVER');
    expect(audienceOf('PARTNER_USER')).toBeUndefined();
  });
});

describe('AssistantToolRegistry', () => {
  it('refuses a tool registered twice', () => {
    const registry = new AssistantToolRegistry();
    registry.register(tool());
    expect(() => registry.register(tool())).toThrow('registered twice');
  });

  it('offers only tools for the audience, that the person may use', () => {
    const registry = new AssistantToolRegistry();
    registry.register(tool({ name: 'a' }));
    registry.register(tool({ name: 'b', audiences: ['ADMIN'] }));
    registry.register(tool({ name: 'c', permission: 'bookings.read' }));
    const names = (ctx: ToolContext, actions = false) =>
      registry.allowedFor('CUSTOMER', ctx, actions).map((t) => t.name);
    expect(names(context())).toEqual(['a']);
    expect(names(context({ permissions: new Set(['bookings.read']) }))).toEqual(['a', 'c']);
    expect(names(context({ hasWildcard: true }))).toEqual(['a', 'c']);
  });

  it('offers action tools only when the administrator allowed actions', () => {
    const registry = new AssistantToolRegistry();
    registry.register(tool({ name: 'read' }));
    registry.register(tool({ name: 'propose', kind: 'ACTION' }));
    expect(registry.allowedFor('CUSTOMER', context(), false).map((t) => t.name)).toEqual(['read']);
    expect(registry.allowedFor('CUSTOMER', context(), true).map((t) => t.name)).toEqual([
      'read',
      'propose',
    ]);
  });
});

describe('GroqChatClient', () => {
  const request = { apiKey: 'gsk_secret_key_0000000000', model: 'm', messages: [], tools: [] };

  it('returns the answer and the token counts', async () => {
    const client = new GroqChatClient();
    client.fetchFn = () =>
      reply(200, {
        choices: [{ message: { role: 'assistant', content: 'Hello' } }],
        usage: { prompt_tokens: 10, completion_tokens: 3 },
      });
    expect(await client.complete(request)).toMatchObject({
      message: { content: 'Hello' },
      promptTokens: 10,
      completionTokens: 3,
    });
  });

  it('sends the key only in the Authorization header', async () => {
    const client = new GroqChatClient();
    const fetchFn = jest.fn(() =>
      reply(200, { choices: [{ message: { role: 'assistant', content: 'x' } }] }),
    );
    client.fetchFn = fetchFn as never;
    await client.complete(request);
    const [url, init] = fetchFn.mock.calls[0] as unknown as [
      string,
      { headers: Record<string, string>; body: string },
    ];
    expect(url).not.toContain('gsk_secret');
    expect(init.body).not.toContain('gsk_secret');
    expect(init.headers.authorization).toBe('Bearer gsk_secret_key_0000000000');
  });

  it.each([
    [401, 'SERVICE_UNAVAILABLE', 'not set up correctly'],
    [429, 'RATE_LIMITED', 'busy'],
    [500, 'SERVICE_UNAVAILABLE', 'could not answer'],
  ])('turns HTTP %i into a sentence for people', async (status, code, text) => {
    const client = new GroqChatClient();
    client.fetchFn = () => reply(status, { error: { message: 'provider internal detail xyz' } });
    const error = await client.complete(request).catch((e: unknown) => e as ApiException);
    expect(error).toMatchObject({ code });
    expect((error as ApiException).message).toContain(text);
    expect((error as ApiException).message).not.toContain('xyz');
  });

  it('turns a network failure and an empty answer into sentences', async () => {
    const client = new GroqChatClient();
    client.fetchFn = () => Promise.reject(new Error('socket hang up'));
    await expect(client.complete(request)).rejects.toMatchObject({ code: 'SERVICE_UNAVAILABLE' });
    client.fetchFn = () => reply(200, { choices: [] });
    await expect(client.complete(request)).rejects.toThrow('no answer');
  });
});
