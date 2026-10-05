import { MetaCloudWhatsAppProvider } from '../meta-cloud-whatsapp.provider';
import {
  type WhatsAppTemplateMessage,
  WhatsAppDeliveryError,
} from '../whatsapp-provider.interface';

const SETTINGS = {
  accessToken: 'test-access-token',
  phoneNumberId: '1234567890',
  apiVersion: 'v23.0',
};

const OTP_MESSAGE: WhatsAppTemplateMessage = {
  to: '+919876543210',
  templateName: 'abra_login_code',
  languageCode: 'en',
  bodyParameters: ['482913'],
  urlButtonParameter: '482913',
  purpose: 'OTP',
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function providerWith(fetchImpl: jest.Mock) {
  return new MetaCloudWhatsAppProvider(SETTINGS, fetchImpl);
}

async function rejection(work: Promise<unknown>): Promise<Error> {
  const error: unknown = await work.then(
    () => undefined,
    (caught: unknown) => caught,
  );
  expect(error).toBeInstanceOf(WhatsAppDeliveryError);
  return error as Error;
}

describe('MetaCloudWhatsAppProvider', () => {
  it('sends an authentication template to the Cloud API with the code in body and copy button', async () => {
    const fetchImpl = jest.fn(() =>
      Promise.resolve(jsonResponse(200, { messages: [{ id: 'wamid.ABC' }] })),
    );
    await providerWith(fetchImpl).sendTemplate(OTP_MESSAGE);

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://graph.facebook.com/v23.0/1234567890/messages');
    expect(init.method).toBe('POST');
    expect(init.headers).toMatchObject({
      Authorization: 'Bearer test-access-token',
      'Content-Type': 'application/json',
    });
    expect(init.signal).toBeInstanceOf(AbortSignal);
    expect(JSON.parse(init.body as string)).toEqual({
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: '919876543210',
      type: 'template',
      template: {
        name: 'abra_login_code',
        language: { code: 'en' },
        components: [
          { type: 'body', parameters: [{ type: 'text', text: '482913' }] },
          {
            type: 'button',
            sub_type: 'url',
            index: '0',
            parameters: [{ type: 'text', text: '482913' }],
          },
        ],
      },
    });
  });

  it('omits the button component when no button parameter is given', async () => {
    const fetchImpl = jest.fn(() =>
      Promise.resolve(jsonResponse(200, { messages: [{ id: 'wamid.ABC' }] })),
    );
    await providerWith(fetchImpl).sendTemplate({ ...OTP_MESSAGE, urlButtonParameter: undefined });
    const [, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    const body = JSON.parse(init.body as string) as { template: { components: unknown[] } };
    expect(body.template.components).toHaveLength(1);
  });

  it('rejects an error answer with only status and Meta error code (no code, number or text)', async () => {
    const fetchImpl = jest.fn(() =>
      Promise.resolve(
        jsonResponse(400, {
          error: {
            code: 131026,
            message: 'Message undeliverable to 919876543210 with 482913',
            type: 'OAuthException',
          },
        }),
      ),
    );
    const error = await rejection(providerWith(fetchImpl).sendTemplate(OTP_MESSAGE));
    expect(error.message).toBe('WhatsApp rejected the message (HTTP 400, error 131026)');
    expect(error.message).not.toMatch(/482913|9876543210|undeliverable/);
  });

  it('rejects a success status without a message id', async () => {
    const fetchImpl = jest.fn(() => Promise.resolve(jsonResponse(200, { messages: [] })));
    const error = await rejection(providerWith(fetchImpl).sendTemplate(OTP_MESSAGE));
    expect(error.message).toBe('WhatsApp did not confirm the message');
  });

  it('rejects a non-JSON error page', async () => {
    const fetchImpl = jest.fn(() =>
      Promise.resolve(new Response('<html>bad gateway</html>', { status: 502 })),
    );
    const error = await rejection(providerWith(fetchImpl).sendTemplate(OTP_MESSAGE));
    expect(error.message).toBe('WhatsApp rejected the message (HTTP 502, error unknown)');
  });

  it('rejects network failures and timeouts without leaking details', async () => {
    const network = jest.fn(() =>
      Promise.reject(new TypeError('fetch failed: getaddrinfo token=x')),
    );
    expect((await rejection(providerWith(network).sendTemplate(OTP_MESSAGE))).message).toBe(
      'WhatsApp request failed',
    );

    const timeout = jest.fn(() =>
      Promise.reject(Object.assign(new Error('The operation timed out'), { name: 'TimeoutError' })),
    );
    expect((await rejection(providerWith(timeout).sendTemplate(OTP_MESSAGE))).message).toBe(
      'WhatsApp request timed out',
    );
  });
});
