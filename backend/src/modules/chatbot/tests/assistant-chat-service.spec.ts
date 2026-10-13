import { Types } from 'mongoose';
import {
  AssistantChatService,
  AssistantToolRegistry,
  type AssistantTool,
  GroqChatClient,
} from '../assistant_chat.service';

const reply = (status: number, body: unknown = {}) =>
  Promise.resolve({ status, ok: status < 300, json: () => Promise.resolve(body) } as Response);

const actor = { userId: new Types.ObjectId().toHexString(), userType: 'CUSTOMER' } as never;

const tool = (over: Partial<AssistantTool> = {}): AssistantTool => ({
  name: 'my_thing',
  description: 'd',
  parameters: { type: 'object', properties: {} },
  audiences: ['CUSTOMER'],
  kind: 'READ',
  run: () => Promise.resolve({ ok: true }),
  ...over,
});

describe('AssistantChatService with Groq', () => {
  function build(
    options: {
      settings?: Record<string, unknown>;
      groq?: GroqChatClient;
      tools?: AssistantTool[];
      allowed?: boolean;
      disabled?: boolean;
    } = {},
  ) {
    const created: Array<Record<string, unknown>> = [];
    const turns = {
      create: jest.fn((doc: Record<string, unknown>) => {
        created.push(doc);
        return Promise.resolve({ _id: new Types.ObjectId() });
      }),
    };
    const actions = {
      create: jest.fn((doc: Record<string, unknown>) =>
        Promise.resolve({ _id: new Types.ObjectId(), ...doc }),
      ),
    };
    const settings = {
      effective: () =>
        Promise.resolve({
          enabled: !options.disabled,
          values: {
            provider: 'groq',
            apiKey: 'gsk_key_0000000000000000',
            model: 'llama',
            allowActions: options.allowed ? 'true' : undefined,
            ...options.settings,
          },
          sources: {},
        }),
    };
    const permissions = {
      forActor: () =>
        Promise.resolve({
          permissions: new Set<string>(),
          roleKeys: ['CUSTOMER'],
          hasWildcard: false,
        }),
    };
    let hits = 0;
    const rateLimiter = {
      key: (...parts: string[]) => parts.join(':'),
      hit: () => Promise.resolve({ allowed: ++hits <= 20, count: hits, retryAfterSeconds: 30 }),
    };
    const registry = new AssistantToolRegistry();
    for (const t of options.tools ?? [tool({ name: 'my_profile' })]) registry.register(t);
    const groq = options.groq ?? new GroqChatClient();
    const users = { findById: () => Promise.resolve({ name: 'Priya' }) };
    const service = new AssistantChatService(
      turns as never,
      actions as never,
      settings as never,
      permissions as never,
      rateLimiter as never,
      registry,
      groq,
      users as never,
      {} as never,
    );
    return { service, created, turns, actions };
  }

  const ask = (text = 'who am i?') => ({
    messages: [{ role: 'user' as const, content: text }],
    language: 'en',
  });

  it('answers in words when the model needs no tool, and records the turn without its text', async () => {
    const groq = new GroqChatClient();
    groq.fetchFn = () =>
      reply(200, {
        choices: [{ message: { role: 'assistant', content: 'Hello Priya' } }],
        usage: { prompt_tokens: 20, completion_tokens: 4 },
      });
    const { service, created } = build({ groq });
    const result = await service.chat(actor, ask('hi'));
    expect(result).toMatchObject({ reply: 'Hello Priya', toolsUsed: [], proposals: [] });
    expect(created[0]).toMatchObject({
      status: 'OK',
      provider: 'groq',
      promptTokens: 20,
      completionTokens: 4,
    });
    expect(JSON.stringify(created[0])).not.toContain('hi');
  });

  it('runs the tool the model asks for, gives it the result, then returns the final answer', async () => {
    const bodies: Array<{
      messages: Array<{ role: string; content: string | null }>;
      tools?: unknown[];
    }> = [];
    let round = 0;
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      bodies.push(JSON.parse(init.body) as never);
      round += 1;
      return round === 1
        ? reply(200, {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: 'c1',
                      type: 'function',
                      function: { name: 'my_profile', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          })
        : reply(200, { choices: [{ message: { role: 'assistant', content: 'You are Priya.' } }] });
    }) as never;
    const { service } = build({
      groq,
      tools: [tool({ name: 'my_profile', run: () => Promise.resolve({ name: 'Priya Nair' }) })],
    });
    const result = await service.chat(actor, ask());
    expect(result.reply).toBe('You are Priya.');
    expect(result.toolsUsed).toEqual(['my_profile']);
    const second = bodies[1]!.messages;
    expect(second.at(-1)).toMatchObject({ role: 'tool', content: '{"name":"Priya Nair"}' });
    expect(second[0]!.role).toBe('system');
  });

  it('never runs a tool that is not allowed for this person', async () => {
    const run = jest.fn(() => Promise.resolve({ secret: 'admin data' }));
    let round = 0;
    const bodies: string[] = [];
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      bodies.push(init.body);
      round += 1;
      return round === 1
        ? reply(200, {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: 'c1',
                      type: 'function',
                      function: { name: 'admin_only', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          })
        : reply(200, {
            choices: [{ message: { role: 'assistant', content: 'I cannot do that.' } }],
          });
    }) as never;
    const { service } = build({
      groq,
      tools: [tool({ name: 'admin_only', audiences: ['ADMIN'], run })],
    });
    await service.chat(actor, ask('show admin data'));
    expect(run).not.toHaveBeenCalled();
    expect(bodies[1]).toContain('not available to this person');
    expect(bodies[0]).not.toContain('admin_only'); // not even offered to the model
  });

  it('turns a tool that throws, and bad arguments, into text the model can read', async () => {
    let round = 0;
    const seen: string[] = [];
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      seen.push(init.body);
      round += 1;
      return round === 1
        ? reply(200, {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: 'c1',
                      type: 'function',
                      function: { name: 'my_profile', arguments: '{bad json' },
                    },
                    {
                      id: 'c2',
                      type: 'function',
                      function: { name: 'my_profile', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          })
        : reply(200, { choices: [{ message: { role: 'assistant', content: 'Sorry.' } }] });
    }) as never;
    const { service } = build({
      groq,
      tools: [
        tool({
          name: 'my_profile',
          run: () => Promise.reject(new Error('mongo exploded at host db-1')),
        }),
      ],
    });
    const result = await service.chat(actor, ask());
    expect(result.reply).toBe('Sorry.');
    expect(seen[1]).toContain('arguments were not valid');
    expect(seen[1]).toContain('could not be read right now');
    expect(seen[1]).not.toContain('db-1');
  });

  it('stops after four tool rounds and forces a written answer', async () => {
    let calls = 0;
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      calls += 1;
      const body = JSON.parse(init.body) as { tools?: unknown[] };
      return body.tools
        ? reply(200, {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: `c${calls}`,
                      type: 'function',
                      function: { name: 'my_profile', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          })
        : reply(200, { choices: [{ message: { role: 'assistant', content: 'Final words.' } }] });
    }) as never;
    const { service } = build({ groq });
    const result = await service.chat(actor, ask());
    expect(result.reply).toBe('Final words.');
    expect(calls).toBe(5);
  });

  it('keeps an action the assistant proposes waiting, and says it is not done', async () => {
    let round = 0;
    const seen: string[] = [];
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      seen.push(init.body);
      round += 1;
      return round === 1
        ? reply(200, {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: 'c1',
                      type: 'function',
                      function: { name: 'propose_x', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          })
        : reply(200, { choices: [{ message: { role: 'assistant', content: 'Please confirm.' } }] });
    }) as never;
    const { service, actions } = build({
      groq,
      allowed: true,
      tools: [
        tool({
          name: 'propose_x',
          kind: 'ACTION',
          run: () =>
            Promise.resolve({ description: 'Mark 3 notifications as read', params: { n: 3 } }),
        }),
      ],
    });
    const result = await service.chat(actor, ask('mark them read'));
    expect(result.proposals).toHaveLength(1);
    expect(result.proposals[0]!.description).toBe('Mark 3 notifications as read');
    expect(actions.create).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'WAITING', tool: 'propose_x' }),
    );
    expect(seen[1]).toContain('Waiting for the person to confirm');
  });

  it('does not even offer action tools until the administrator allows actions', async () => {
    const bodies: string[] = [];
    const groq = new GroqChatClient();
    groq.fetchFn = ((_url: string, init: { body: string }) => {
      bodies.push(init.body);
      return reply(200, { choices: [{ message: { role: 'assistant', content: 'ok' } }] });
    }) as never;
    const { service } = build({ groq, tools: [tool({ name: 'propose_x', kind: 'ACTION' })] });
    await service.chat(actor, ask());
    expect(bodies[0]).not.toContain('propose_x');
  });

  it('refuses when switched off, not set up, or for an account kind without an assistant', async () => {
    const off = build({ disabled: true });
    await expect(off.service.chat(actor, ask())).rejects.toThrow('switched off');
    const unset = build({ settings: { apiKey: undefined } });
    await expect(unset.service.chat(actor, ask())).rejects.toThrow('not set up');
    const partner = build();
    await expect(
      partner.service.chat({ ...(actor as object), userType: 'PARTNER_USER' } as never, ask()),
    ).rejects.toMatchObject({ code: 'PERMISSION_DENIED' });
  });

  it('limits a person to 20 questions a minute', async () => {
    const groq = new GroqChatClient();
    groq.fetchFn = () =>
      reply(200, { choices: [{ message: { role: 'assistant', content: 'ok' } }] });
    const { service } = build({ groq });
    for (let i = 0; i < 20; i += 1) await service.chat(actor, ask());
    await expect(service.chat(actor, ask())).rejects.toMatchObject({
      code: 'RATE_LIMITED',
      details: { retryAfterSeconds: 30 },
    });
  });

  it('records a failed turn with a sentence, and raises the same sentence', async () => {
    const groq = new GroqChatClient();
    groq.fetchFn = () => reply(500);
    const { service, created } = build({ groq });
    await expect(service.chat(actor, ask())).rejects.toMatchObject({ code: 'SERVICE_UNAVAILABLE' });
    expect(created[0]).toMatchObject({ status: 'ERROR' });
    expect(String(created[0]?.error)).toContain('could not answer');
  });
});
