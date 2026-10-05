import { Logger } from '@nestjs/common';
import { type Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  configOf,
  InMemoryRateLimiter,
} from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { OtpDeliveryService } from '../../../integrations/otp-delivery/otp-delivery.service';
import { SmsOtpDeliveryProvider } from '../../../integrations/otp-delivery/sms-otp-delivery.provider';
import { WhatsAppOtpDeliveryProvider } from '../../../integrations/otp-delivery/whatsapp-otp-delivery.provider';
import { DevelopmentSmsProvider } from '../../../integrations/sms/development-sms.provider';
import { type SmsProvider } from '../../../integrations/sms/sms-provider.interface';
import { DevelopmentWhatsAppProvider } from '../../../integrations/whatsapp/development-whatsapp.provider';
import { type WhatsAppProvider } from '../../../integrations/whatsapp/whatsapp-provider.interface';
import {
  type OtpChallengeRepository,
  type StoredOtpChallenge,
} from '../repositories/otp-challenge.repository';
import { type OtpPurpose } from '../schemas/otp-challenge.schema';
import { generateOtpCode, OtpService } from '../services/otp.service';

const PHONE = '+919876543210';
const CLIENT = { ip: '203.0.113.7' };

/** Same conditional semantics as the MongoDB repository (covered for real by the e2e suite). */
class InMemoryOtpChallenges {
  readonly challenges: StoredOtpChallenge[] = [];

  insert(challenge: StoredOtpChallenge): Promise<void> {
    this.challenges.push({ ...challenge, createdAt: new Date() });
    return Promise.resolve();
  }

  supersedeActive(target: string, purpose: OtpPurpose, now: Date): Promise<void> {
    for (const challenge of this.challenges) {
      if (challenge.target === target && challenge.purpose === purpose && !challenge.consumedAt) {
        challenge.consumedAt = now;
      }
    }
    return Promise.resolve();
  }

  registerAttempt(target: string, purpose: OtpPurpose, maxAttempts: number, now: Date) {
    const usable = this.challenges
      .filter(
        (challenge) =>
          challenge.target === target &&
          challenge.purpose === purpose &&
          !challenge.consumedAt &&
          challenge.expiresAt > now &&
          challenge.attempts < maxAttempts,
      )
      .at(-1);
    if (usable) usable.attempts += 1;
    return Promise.resolve(usable ?? null);
  }

  consume(id: Types.ObjectId, now: Date): Promise<boolean> {
    const challenge = this.challenges.find((candidate) => candidate._id.equals(id));
    if (!challenge || challenge.consumedAt) return Promise.resolve(false);
    challenge.consumedAt = now;
    return Promise.resolve(true);
  }
}

function setup(
  options: { whatsApp?: WhatsAppProvider; sms?: SmsProvider; channels?: string[] } = {},
) {
  const whatsApp = options.whatsApp ?? new DevelopmentWhatsAppProvider(false);
  const sms = options.sms ?? new DevelopmentSmsProvider(false);
  const challenges = new InMemoryOtpChallenges();
  const limiter = new InMemoryRateLimiter();
  const config = configOf({
    OTP_LENGTH: 6,
    OTP_TTL_SECONDS: 300,
    OTP_MAX_VERIFY_ATTEMPTS: 5,
    OTP_MAX_SENDS_PER_WINDOW: 3,
    OTP_SEND_WINDOW_SECONDS: 900,
    OTP_RESEND_COOLDOWN_SECONDS: 30,
    OTP_MAX_SENDS_PER_IP_PER_WINDOW: 20,
    OTP_HASH_SECRET: 'unit-test-otp-hash-secret-0123456789abcdef',
    OTP_DELIVERY_CHANNELS: options.channels ?? ['whatsapp', 'sms'],
  });
  const delivery = new OtpDeliveryService(
    config,
    new WhatsAppOtpDeliveryProvider(whatsApp, config),
    new SmsOtpDeliveryProvider(sms),
  );
  const service = new OtpService(
    challenges as unknown as OtpChallengeRepository,
    limiter.asService(),
    config,
    delivery,
  );
  /** The code from the newest message to [phone] on either channel. */
  const codeSentTo = (phone: string): string => {
    if (whatsApp instanceof DevelopmentWhatsAppProvider) {
      const viaWhatsApp = whatsApp.lastMessageTo(phone)?.bodyParameters[0];
      if (viaWhatsApp) return viaWhatsApp;
    }
    const body =
      sms instanceof DevelopmentSmsProvider ? (sms.lastMessageTo(phone)?.body ?? '') : '';
    return /^(\d{6}) /.exec(body)?.[1] ?? '';
  };
  const messagesTo = (phone: string): number =>
    (whatsApp instanceof DevelopmentWhatsAppProvider ? whatsApp.messagesTo(phone).length : 0) +
    (sms instanceof DevelopmentSmsProvider ? sms.messagesTo(phone).length : 0);
  return { challenges, limiter, service, whatsApp, sms, codeSentTo, messagesTo };
}

async function failure(work: Promise<unknown>): Promise<ApiException> {
  const error: unknown = await work.then(
    () => undefined,
    (caught: unknown) => caught,
  );
  expect(error).toBeInstanceOf(ApiException);
  return error as ApiException;
}

describe('generateOtpCode', () => {
  it('returns numeric codes of the requested length, including leading zeros', () => {
    const codes = Array.from({ length: 2000 }, () => generateOtpCode(6));
    expect(codes.every((code) => /^\d{6}$/.test(code))).toBe(true);
    expect(codes.some((code) => code.startsWith('0'))).toBe(true);
    // Not a constant, not sequential: thousands of distinct values
    expect(new Set(codes).size).toBeGreaterThan(1900);
    expect(generateOtpCode(4)).toMatch(/^\d{4}$/);
  });
});

describe('OtpService', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('sends the code on WhatsApp, stores only a keyed hash, and never returns the code', async () => {
    const { service, challenges, codeSentTo, sms } = setup();
    const result = await service.request(PHONE, 'SIGN_IN', CLIENT);

    expect(result).toEqual({
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
      codeLength: 6,
      channel: 'WHATSAPP',
    });
    expect((sms as DevelopmentSmsProvider).messagesTo(PHONE)).toHaveLength(0);
    const code = codeSentTo(PHONE);
    expect(code).toMatch(/^\d{6}$/);
    expect(JSON.stringify(result)).not.toContain(code);
    expect(challenges.challenges).toHaveLength(1);
    expect(challenges.challenges[0]?.codeHash).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(challenges.challenges)).not.toContain(code);
  });

  it('accepts the right code exactly once', async () => {
    const { service, codeSentTo } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const code = codeSentTo(PHONE);
    await expect(service.verify(PHONE, 'SIGN_IN', code)).resolves.toBeUndefined();
    expect((await failure(service.verify(PHONE, 'SIGN_IN', code))).code).toBe('OTP_INVALID');
  });

  it('rejects a wrong code, a code for another number and a code for another purpose', async () => {
    const { service, codeSentTo } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const code = codeSentTo(PHONE);
    const wrong = code === '000000' ? '000001' : '000000';

    expect((await failure(service.verify(PHONE, 'SIGN_IN', wrong))).code).toBe('OTP_INVALID');
    expect((await failure(service.verify('+919000000001', 'SIGN_IN', code))).code).toBe(
      'OTP_INVALID',
    );
    expect((await failure(service.verify(PHONE, 'PASSWORD_RESET', code))).code).toBe('OTP_INVALID');
    // The genuine code still works after those failures
    await expect(service.verify(PHONE, 'SIGN_IN', code)).resolves.toBeUndefined();
  });

  it('rejects an expired code', async () => {
    const { service, challenges, codeSentTo } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const challenge = challenges.challenges[0];
    if (challenge) challenge.expiresAt = new Date(Date.now() - 1);
    expect((await failure(service.verify(PHONE, 'SIGN_IN', codeSentTo(PHONE)))).code).toBe(
      'OTP_INVALID',
    );
  });

  it('stops accepting guesses after 5 attempts, even the correct code', async () => {
    const { service, codeSentTo } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const code = codeSentTo(PHONE);
    const wrong = code === '111111' ? '222222' : '111111';
    for (let attempt = 1; attempt <= 5; attempt++) {
      await failure(service.verify(PHONE, 'SIGN_IN', wrong));
    }
    expect((await failure(service.verify(PHONE, 'SIGN_IN', code))).code).toBe('OTP_INVALID');
  });

  it('a new code replaces the previous one', async () => {
    const { service, limiter, codeSentTo } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const first = codeSentTo(PHONE);
    limiter.advanceSeconds(31);
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const second = codeSentTo(PHONE);

    if (first !== second) await failure(service.verify(PHONE, 'SIGN_IN', first));
    await expect(service.verify(PHONE, 'SIGN_IN', second)).resolves.toBeUndefined();
  });

  it('enforces the resend cooldown', async () => {
    const { service, limiter } = setup();
    await service.request(PHONE, 'SIGN_IN', CLIENT);
    const error = await failure(service.request(PHONE, 'SIGN_IN', CLIENT));
    expect(error.code).toBe('RATE_LIMITED');
    expect(error.details).toEqual({ retryAfterSeconds: 30 });
    limiter.advanceSeconds(31);
    await expect(service.request(PHONE, 'SIGN_IN', CLIENT)).resolves.toBeDefined();
  });

  it('allows 3 sends per number per window, then blocks until the window ends', async () => {
    const { service, limiter, messagesTo } = setup();
    for (let send = 1; send <= 3; send++) {
      await service.request(PHONE, 'SIGN_IN', CLIENT);
      limiter.advanceSeconds(31);
    }
    const error = await failure(service.request(PHONE, 'SIGN_IN', CLIENT));
    expect(error.code).toBe('RATE_LIMITED');
    expect(messagesTo(PHONE)).toBe(3);

    // Another number is unaffected; the blocked number works again after the window
    await expect(service.request('+919000000002', 'SIGN_IN', CLIENT)).resolves.toBeDefined();
    limiter.advanceSeconds(900);
    await expect(service.request(PHONE, 'SIGN_IN', CLIENT)).resolves.toBeDefined();
  });

  it('limits sends per IP across numbers', async () => {
    const { service } = setup();
    for (let index = 0; index < 20; index++) {
      await service.request(`+9190000001${String(index).padStart(2, '0')}`, 'SIGN_IN', CLIENT);
    }
    const error = await failure(service.request('+919000000199', 'SIGN_IN', CLIENT));
    expect(error.code).toBe('RATE_LIMITED');
    await expect(
      service.request('+919000000199', 'SIGN_IN', { ip: '198.51.100.20' }),
    ).resolves.toBeDefined();
  });

  it('deliver:false answers like a real send but creates and sends nothing', async () => {
    const { service, challenges, messagesTo } = setup();
    const result = await service.request(PHONE, 'PASSWORD_RESET', CLIENT, { deliver: false });
    expect(result).toEqual({
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
      codeLength: 6,
      channel: 'WHATSAPP',
    });
    expect(challenges.challenges).toHaveLength(0);
    expect(messagesTo(PHONE)).toBe(0);
    // The limits still apply, so the answer cannot be used as an oracle either
    expect(
      (await failure(service.request(PHONE, 'PASSWORD_RESET', CLIENT, { deliver: false }))).code,
    ).toBe('RATE_LIMITED');
  });

  it('falls back to SMS when WhatsApp fails, sending exactly one usable code', async () => {
    const failingWhatsApp: WhatsAppProvider = {
      providerKey: 'failing',
      sendTemplate: () => Promise.reject(new Error('meta down')),
    };
    const { service, codeSentTo, sms } = setup({ whatsApp: failingWhatsApp });
    const result = await service.request(PHONE, 'SIGN_IN', CLIENT);
    expect(result.channel).toBe('SMS');
    expect((sms as DevelopmentSmsProvider).messagesTo(PHONE)).toHaveLength(1);
    await expect(service.verify(PHONE, 'SIGN_IN', codeSentTo(PHONE))).resolves.toBeUndefined();
  });

  it('uses only the configured channels (SMS only)', async () => {
    const { service, whatsApp, sms } = setup({ channels: ['sms'] });
    expect((await service.request(PHONE, 'SIGN_IN', CLIENT)).channel).toBe('SMS');
    expect((whatsApp as DevelopmentWhatsAppProvider).messagesTo(PHONE)).toHaveLength(0);
    expect((sms as DevelopmentSmsProvider).messagesTo(PHONE)).toHaveLength(1);
  });

  it('when no channel can send: SERVICE_UNAVAILABLE and the code is unusable', async () => {
    const failingSms: SmsProvider = {
      providerKey: 'failing',
      send: () => Promise.reject(new Error('provider timeout token=abc')),
    };
    const failingWhatsApp: WhatsAppProvider = {
      providerKey: 'failing',
      sendTemplate: () => Promise.reject(new Error('meta down token=xyz')),
    };
    const { service, challenges } = setup({ whatsApp: failingWhatsApp, sms: failingSms });
    const error = await failure(service.request(PHONE, 'SIGN_IN', CLIENT));
    expect(error.code).toBe('SERVICE_UNAVAILABLE');
    expect(error.message).not.toMatch(/token=|meta down/);
    expect(challenges.challenges[0]?.consumedAt).toBeInstanceOf(Date);
  });
});
