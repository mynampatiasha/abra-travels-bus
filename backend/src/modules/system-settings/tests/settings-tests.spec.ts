import { isHostAllowed, describeEmailFailure } from '../../../integrations/email/email.service';
import { checkWhatsAppConnection } from '../services/whatsapp-connection-check';

const READY = {
  accessToken: 'EAAtoken0000000000000000',
  phoneNumberId: '1234567890',
  apiVersion: 'v23.0',
};

function reply(status: number, body: unknown): typeof fetch {
  return () => Promise.resolve(new Response(JSON.stringify(body), { status }));
}

describe('checkWhatsAppConnection', () => {
  it('asks for what is missing before calling Meta', async () => {
    const never = (() => {
      throw new Error('must not call Meta');
    }) as unknown as typeof fetch;
    expect(
      (await checkWhatsAppConnection({ ...READY, accessToken: undefined }, never)).message,
    ).toMatch(/access token/);
    expect(
      (await checkWhatsAppConnection({ ...READY, phoneNumberId: undefined }, never)).message,
    ).toMatch(/phone number ID/);
    expect((await checkWhatsAppConnection({ ...READY, apiVersion: undefined }, never)).ok).toBe(
      false,
    );
  });

  it('reports the number, name and quality Meta returns', async () => {
    const result = await checkWhatsAppConnection(
      READY,
      reply(200, {
        display_phone_number: '+91 98765 43210',
        verified_name: 'Abra Travels',
        quality_rating: 'GREEN',
      }),
    );
    expect(result).toEqual({
      ok: true,
      message: 'Connected to WhatsApp: number +91 98765 43210, name "Abra Travels", quality green.',
    });
  });

  it('sends the token only as a header and asks for the saved phone number', async () => {
    let url = '';
    let init: RequestInit | undefined;
    const spy = ((input: string, options?: RequestInit) => {
      url = input;
      init = options;
      return Promise.resolve(new Response('{}', { status: 200 }));
    }) as unknown as typeof fetch;
    await checkWhatsAppConnection(READY, spy);
    expect(url).toContain('/v23.0/1234567890?fields=');
    expect(url).not.toContain(READY.accessToken);
    expect((init?.headers as Record<string, string>).Authorization).toBe(
      `Bearer ${READY.accessToken}`,
    );
  });

  it.each([
    [190, /access token/],
    [100, /phone number ID/],
    [200, /permission/],
    [80007, /limiting/],
  ])('explains Meta error %s in plain words', async (code, expected) => {
    const result = await checkWhatsAppConnection(
      READY,
      reply(400, { error: { code, message: 'secret detail' } }),
    );
    expect(result.ok).toBe(false);
    expect(result.message).toMatch(expected);
    expect(result.message).not.toContain('secret detail');
  });

  it('handles an unknown Meta error, a timeout and no network', async () => {
    expect((await checkWhatsAppConnection(READY, reply(500, {}))).message).toContain('HTTP 500');
    const timeout = (() =>
      Promise.reject(
        Object.assign(new Error('t'), { name: 'TimeoutError' }),
      )) as unknown as typeof fetch;
    expect((await checkWhatsAppConnection(READY, timeout)).message).toMatch(/in time/);
    const offline = (() => Promise.reject(new Error('offline'))) as unknown as typeof fetch;
    expect((await checkWhatsAppConnection(READY, offline)).message).toMatch(/Could not reach Meta/);
  });
});

describe('isHostAllowed', () => {
  it('allows any host outside production, so a local mail catcher can be used', () => {
    expect(isHostAllowed('localhost', false)).toBe(true);
    expect(isHostAllowed('127.0.0.1', false)).toBe(true);
  });

  it('in production refuses local and private addresses', () => {
    for (const host of [
      'localhost',
      '127.0.0.1',
      '10.0.0.5',
      '192.168.1.10',
      '172.16.0.1',
      '169.254.169.254',
      '::1',
      'mail.corp.internal',
      'printer.local',
    ]) {
      expect(isHostAllowed(host, true)).toBe(false);
    }
  });

  it('in production allows public hosts', () => {
    for (const host of ['smtp.gmail.com', 'smtp-relay.brevo.com', '8.8.8.8', '172.32.0.1']) {
      expect(isHostAllowed(host, true)).toBe(true);
    }
  });
});

describe('describeEmailFailure', () => {
  it('turns mail server errors into readable reasons without the password', () => {
    expect(describeEmailFailure({ code: 'EAUTH' }, 'smtp.x.com', 587).message).toMatch(
      /username or password/,
    );
    expect(describeEmailFailure({ code: 'ENOTFOUND' }, 'smtp.x.com', 587).message).toContain(
      'smtp.x.com',
    );
    expect(describeEmailFailure({ code: 'ECONNREFUSED' }, 'smtp.x.com', 587).message).toContain(
      'smtp.x.com:587',
    );
    expect(describeEmailFailure({ code: 'ETLS' }, 'h', 1).message).toMatch(/SSL or STARTTLS/);
    expect(describeEmailFailure(new Error('weird'), 'h', 1).message).toBe(
      'The email could not be sent.',
    );
  });
});
