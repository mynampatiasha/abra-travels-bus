import { DevelopmentSmsProvider } from '../../../integrations/sms/development-sms.provider';
import { type SmsProvider } from '../../../integrations/sms/sms-provider.interface';
import { DevelopmentWhatsAppProvider } from '../../../integrations/whatsapp/development-whatsapp.provider';
import {
  WhatsAppDeliveryError,
  type WhatsAppProvider,
} from '../../../integrations/whatsapp/whatsapp-provider.interface';
import {
  type AuthTestContext,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  lastOtp,
  uniquePhone,
} from './auth-e2e.harness';

/** A WhatsApp provider that is down (Meta rejects every message). */
const unavailableWhatsApp: WhatsAppProvider = {
  providerKey: 'meta-cloud',
  sendTemplate: () =>
    Promise.reject(new WhatsAppDeliveryError('WhatsApp rejected the message (HTTP 503, error 2)')),
};

const unavailableSms: SmsProvider = {
  providerKey: 'sms-down',
  send: () => Promise.reject(new Error('sms provider down')),
};

interface OtpDispatchBody {
  expiresInSeconds: number;
  resendAfterSeconds: number;
  codeLength: number;
  channel: 'WHATSAPP' | 'SMS';
}

async function sendAndVerify(context: AuthTestContext, phone: string) {
  const caller = client(context);
  const sent = await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
  await caller
    .post('/api/v1/auth/otp/verify')
    .send({ phone, code: lastOtp(context, phone) })
    .expect(200);
  return dataOf<OtpDispatchBody>(sent);
}

/** OTP delivery channels (WhatsApp first, SMS fallback) — real MongoDB + Redis. */
describe('Authentication e2e: OTP delivery channels', () => {
  describe('default (WhatsApp, SMS as fallback)', () => {
    let context: AuthTestContext;
    beforeAll(async () => {
      context = await createAuthTestApp();
    }, 60_000);
    afterAll(async () => {
      await context?.close();
    }, 60_000);

    it('sends the code on WhatsApp only, and the code signs in', async () => {
      const phone = uniquePhone();
      expect(await sendAndVerify(context, phone)).toEqual({
        expiresInSeconds: 300,
        resendAfterSeconds: 30,
        codeLength: 6,
        channel: 'WHATSAPP',
      });
      const whatsApp = context.whatsApp as DevelopmentWhatsAppProvider;
      expect(whatsApp.messagesTo(phone)).toHaveLength(1);
      expect(whatsApp.lastMessageTo(phone)).toMatchObject({ purpose: 'OTP', languageCode: 'en' });
      expect((context.sms as DevelopmentSmsProvider).messagesTo(phone)).toHaveLength(0);
    });
  });

  describe('WhatsApp unavailable', () => {
    let context: AuthTestContext;
    beforeAll(async () => {
      context = await createAuthTestApp({}, { whatsApp: unavailableWhatsApp });
    }, 60_000);
    afterAll(async () => {
      await context?.close();
    }, 60_000);

    it('falls back to SMS, sends one message, and that code signs in', async () => {
      const phone = uniquePhone();
      const dispatch = await sendAndVerify(context, phone);
      expect(dispatch.channel).toBe('SMS');
      expect((context.sms as DevelopmentSmsProvider).messagesTo(phone)).toHaveLength(1);
    });
  });

  describe('every channel unavailable', () => {
    let context: AuthTestContext;
    beforeAll(async () => {
      context = await createAuthTestApp({}, { whatsApp: unavailableWhatsApp, sms: unavailableSms });
    }, 60_000);
    afterAll(async () => {
      await context?.close();
    }, 60_000);

    it('answers SERVICE_UNAVAILABLE without provider details and leaves no usable code', async () => {
      const phone = uniquePhone();
      const response = await client(context)
        .post('/api/v1/auth/otp/send')
        .send({ phone })
        .expect(503);
      expect(errorCodeOf(response)).toBe('SERVICE_UNAVAILABLE');
      expect(JSON.stringify(response.body)).not.toMatch(/HTTP 503|provider down|meta/i);

      const challenge = await context.connection
        .collection('otp_challenges')
        .findOne({ target: phone });
      expect(challenge?.consumedAt).toBeInstanceOf(Date);
    });
  });

  describe('SMS only (OTP_DELIVERY_CHANNELS=sms)', () => {
    let context: AuthTestContext;
    beforeAll(async () => {
      context = await createAuthTestApp({ OTP_DELIVERY_CHANNELS: 'sms' });
    }, 60_000);
    afterAll(async () => {
      await context?.close();
    }, 60_000);

    it('uses SMS and never WhatsApp', async () => {
      const phone = uniquePhone();
      expect((await sendAndVerify(context, phone)).channel).toBe('SMS');
      expect((context.whatsApp as DevelopmentWhatsAppProvider).messagesTo(phone)).toHaveLength(0);
    });
  });
});
