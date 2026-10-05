import { Logger } from '@nestjs/common';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { DevelopmentWhatsAppProvider } from '../development-whatsapp.provider';
import { MetaCloudWhatsAppProvider } from '../meta-cloud-whatsapp.provider';
import { createWhatsAppProvider } from '../whatsapp.module';
import { type WhatsAppTemplateMessage } from '../whatsapp-provider.interface';

const MESSAGE: WhatsAppTemplateMessage = {
  to: '+919876543210',
  templateName: 'development_otp',
  languageCode: 'en',
  bodyParameters: ['123456'],
  urlButtonParameter: '123456',
  purpose: 'OTP',
};

describe('DevelopmentWhatsAppProvider', () => {
  afterEach(() => jest.restoreAllMocks());

  it('keeps messages in its inbox and sends nothing', async () => {
    const provider = new DevelopmentWhatsAppProvider(false);
    await provider.sendTemplate(MESSAGE);
    expect(provider.lastMessageTo('+919876543210')).toEqual(MESSAGE);
    expect(provider.messagesTo('+910000000000')).toEqual([]);
  });

  it('logs the code only when told to (NODE_ENV=development)', async () => {
    const log = jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    await new DevelopmentWhatsAppProvider(false).sendTemplate(MESSAGE);
    expect(log).not.toHaveBeenCalled();
    await new DevelopmentWhatsAppProvider(true).sendTemplate(MESSAGE);
    expect(log).toHaveBeenCalledWith(expect.stringContaining('DEVELOPMENT WHATSAPP (not sent)'));
  });
});

describe('createWhatsAppProvider', () => {
  const meta = {
    WHATSAPP_PROVIDER: 'meta',
    WHATSAPP_ACCESS_TOKEN: 'token',
    WHATSAPP_PHONE_NUMBER_ID: '1234567890',
    WHATSAPP_GRAPH_API_VERSION: 'v23.0',
  };

  it('builds the Meta Cloud provider from configuration', () => {
    expect(createWhatsAppProvider(configOf(meta))).toBeInstanceOf(MetaCloudWhatsAppProvider);
  });

  it('builds the development provider outside production and refuses it in production', () => {
    expect(
      createWhatsAppProvider(configOf({ WHATSAPP_PROVIDER: 'development', NODE_ENV: 'test' })),
    ).toBeInstanceOf(DevelopmentWhatsAppProvider);
    expect(() =>
      createWhatsAppProvider(
        configOf({ WHATSAPP_PROVIDER: 'development', NODE_ENV: 'production' }),
      ),
    ).toThrow('cannot be used in production');
  });

  it('refuses a Meta provider whose settings are missing', () => {
    expect(() =>
      createWhatsAppProvider(configOf({ ...meta, WHATSAPP_GRAPH_API_VERSION: undefined })),
    ).toThrow('WHATSAPP_GRAPH_API_VERSION is not configured');
  });
});
