import { Logger } from '@nestjs/common';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { DevelopmentSmsProvider } from '../../sms/development-sms.provider';
import { type SmsProvider } from '../../sms/sms-provider.interface';
import { DevelopmentWhatsAppProvider } from '../../whatsapp/development-whatsapp.provider';
import { whatsAppSettingsOf } from '../../whatsapp/tests/whatsapp-settings.fixture';
import { type WhatsAppProvider } from '../../whatsapp/whatsapp-provider.interface';
import { type WhatsAppSettings } from '../../whatsapp/whatsapp-settings.schema';
import { OtpDeliveryFailedError, OtpDeliveryService } from '../otp-delivery.service';
import { SmsOtpDeliveryProvider } from '../sms-otp-delivery.provider';
import { WhatsAppOtpDeliveryProvider } from '../whatsapp-otp-delivery.provider';

const REQUEST = { to: '+919876543210', code: '482913', expiresInSeconds: 300 };

const failingWhatsApp: WhatsAppProvider = {
  providerKey: 'meta-cloud',
  sendTemplate: () =>
    Promise.reject(new Error('WhatsApp rejected the message (HTTP 400, error 131026)')),
};
const failingSms: SmsProvider = {
  providerKey: 'failing-sms',
  send: () => Promise.reject(new Error('provider down')),
};

function setup(
  options: {
    channels?: string[];
    whatsApp?: WhatsAppProvider;
    sms?: SmsProvider;
    templateName?: string;
    templateLanguage?: string;
    /** Settings stored by an administrator, laid over the environment. */
    admin?: Partial<WhatsAppSettings>;
  } = {},
) {
  const whatsApp = options.whatsApp ?? new DevelopmentWhatsAppProvider(false);
  const sms = options.sms ?? new DevelopmentSmsProvider(false);
  const config = configOf({
    OTP_DELIVERY_CHANNELS: options.channels ?? ['whatsapp', 'sms'],
    WHATSAPP_OTP_TEMPLATE_NAME: options.templateName,
    WHATSAPP_OTP_TEMPLATE_LANGUAGE: options.templateLanguage,
  });
  const settings = whatsAppSettingsOf(config, options.admin);
  const service = new OtpDeliveryService(
    config,
    settings,
    new WhatsAppOtpDeliveryProvider(whatsApp, settings),
    new SmsOtpDeliveryProvider(sms),
  );
  return { service, whatsApp, sms };
}

const whatsAppCount = (provider: WhatsAppProvider) =>
  (provider as DevelopmentWhatsAppProvider).messagesTo(REQUEST.to).length;
const smsCount = (provider: SmsProvider) =>
  (provider as DevelopmentSmsProvider).messagesTo(REQUEST.to).length;

describe('OtpDeliveryService', () => {
  afterEach(() => jest.restoreAllMocks());

  it('delivers on WhatsApp first and does not also send an SMS', async () => {
    const { service, whatsApp, sms } = setup({
      templateName: 'abra_login_code',
      templateLanguage: 'en_US',
    });
    await expect(service.deliver(REQUEST)).resolves.toBe('WHATSAPP');
    expect(whatsAppCount(whatsApp)).toBe(1);
    expect(smsCount(sms)).toBe(0);
    expect((whatsApp as DevelopmentWhatsAppProvider).lastMessageTo(REQUEST.to)).toEqual({
      to: REQUEST.to,
      templateName: 'abra_login_code',
      languageCode: 'en_US',
      bodyParameters: ['482913'],
      urlButtonParameter: '482913',
      purpose: 'OTP',
    });
  });

  it('falls back to SMS only when WhatsApp fails, sending one message in total', async () => {
    const { service, sms } = setup({ whatsApp: failingWhatsApp });
    await expect(service.deliver(REQUEST)).resolves.toBe('SMS');
    expect(smsCount(sms)).toBe(1);
    expect((sms as DevelopmentSmsProvider).lastMessageTo(REQUEST.to)?.body).toBe(
      '482913 is your Abra Travels verification code. It expires in 5 minutes. Do not share it with anyone.',
    );
  });

  it('follows the configured order and channels', async () => {
    const smsFirst = setup({ channels: ['sms', 'whatsapp'] });
    await expect(smsFirst.service.deliver(REQUEST)).resolves.toBe('SMS');
    expect(whatsAppCount(smsFirst.whatsApp)).toBe(0);

    const whatsAppOnly = setup({ channels: ['whatsapp'], whatsApp: failingWhatsApp });
    await expect(whatsAppOnly.service.deliver(REQUEST)).rejects.toEqual(
      new OtpDeliveryFailedError(['WHATSAPP']),
    );
    expect(smsCount(whatsAppOnly.sms)).toBe(0);
    expect(whatsAppOnly.service.primaryChannel).toBe('WHATSAPP');
  });

  describe('administrator settings', () => {
    it('WhatsApp turned off: the code goes by SMS and WhatsApp is not contacted', async () => {
      const { service, whatsApp, sms } = setup({ admin: { enabled: false } });
      await expect(service.activeChannels()).resolves.toEqual(['SMS']);
      await expect(service.deliver(REQUEST)).resolves.toBe('SMS');
      expect(whatsAppCount(whatsApp)).toBe(0);
      expect(smsCount(sms)).toBe(1);
    });

    it('SMS fallback turned off: a WhatsApp failure is not followed by an SMS', async () => {
      const { service, sms } = setup({
        whatsApp: failingWhatsApp,
        admin: { otpFallbackToSms: false },
      });
      await expect(service.deliver(REQUEST)).rejects.toEqual(
        new OtpDeliveryFailedError(['WHATSAPP']),
      );
      expect(smsCount(sms)).toBe(0);
    });

    it('WhatsApp turned off while it is the only channel: it stays in use', async () => {
      const { service } = setup({ channels: ['whatsapp'], admin: { enabled: false } });
      await expect(service.deliver(REQUEST)).resolves.toBe('WHATSAPP');
    });

    it('the template chosen by an administrator replaces the configured one', async () => {
      const { service, whatsApp } = setup({
        templateName: 'from_environment',
        templateLanguage: 'en',
        admin: { otpTemplateName: 'abra_otp_v2', otpTemplateLanguage: 'en_US' },
      });
      await service.deliver(REQUEST);
      expect((whatsApp as DevelopmentWhatsAppProvider).lastMessageTo(REQUEST.to)).toMatchObject({
        templateName: 'abra_otp_v2',
        languageCode: 'en_US',
      });
    });
  });

  it('fails with the attempted channels when every channel fails', async () => {
    const { service } = setup({ whatsApp: failingWhatsApp, sms: failingSms });
    const error = await service.deliver(REQUEST).catch((caught: unknown) => caught);
    expect(error).toBeInstanceOf(OtpDeliveryFailedError);
    expect((error as OtpDeliveryFailedError).attemptedChannels).toEqual(['WHATSAPP', 'SMS']);
    expect((error as Error).message).not.toContain(REQUEST.code);
  });

  it('never logs the code or the full phone number', async () => {
    const lines: string[] = [];
    jest.spyOn(Logger.prototype, 'warn').mockImplementation((...args: unknown[]) => {
      lines.push(JSON.stringify(args));
    });
    const { service } = setup({ whatsApp: failingWhatsApp });
    await service.deliver(REQUEST);
    expect(lines.length).toBeGreaterThan(0);
    for (const line of lines) {
      expect(line).not.toContain(REQUEST.code);
      expect(line).not.toContain('9876543210');
    }
  });
});
