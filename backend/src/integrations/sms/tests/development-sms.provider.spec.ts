import { Logger } from '@nestjs/common';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { DevelopmentSmsProvider } from '../development-sms.provider';
import { createSmsProvider } from '../sms.module';

describe('DevelopmentSmsProvider', () => {
  afterEach(() => jest.restoreAllMocks());

  it('keeps messages in memory for tests and sends nothing', async () => {
    const provider = new DevelopmentSmsProvider(false);
    await provider.send({ to: '+919876543210', purpose: 'OTP', body: 'first' });
    await provider.send({ to: '+919876543210', purpose: 'OTP', body: 'second' });
    await provider.send({ to: '+919000000001', purpose: 'OTP', body: 'other' });

    expect(provider.providerKey).toBe('development');
    expect(provider.lastMessageTo('+919876543210')?.body).toBe('second');
    expect(provider.messagesTo('+919876543210')).toHaveLength(2);
    expect(provider.lastMessageTo('+919999999999')).toBeUndefined();
  });

  it('writes the message to the log only when asked to (NODE_ENV=development)', async () => {
    const log = jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    await new DevelopmentSmsProvider(false).send({
      to: '+919876543210',
      purpose: 'OTP',
      body: 'x',
    });
    expect(log).not.toHaveBeenCalled();
    await new DevelopmentSmsProvider(true).send({ to: '+919876543210', purpose: 'OTP', body: 'x' });
    expect(log).toHaveBeenCalledTimes(1);
  });

  it('bounds the in-memory inbox', async () => {
    const provider = new DevelopmentSmsProvider(false);
    for (let index = 0; index < 60; index++) {
      await provider.send({ to: '+919876543210', purpose: 'OTP', body: `m${index}` });
    }
    expect(provider.messagesTo('+919876543210')).toHaveLength(50);
  });
});

describe('createSmsProvider', () => {
  it('selects the development adapter outside production, logging only in development', () => {
    const test = createSmsProvider(configOf({ SMS_PROVIDER: 'development', NODE_ENV: 'test' }));
    expect(test).toBeInstanceOf(DevelopmentSmsProvider);
  });

  it('refuses the development adapter in production', () => {
    expect(() =>
      createSmsProvider(configOf({ SMS_PROVIDER: 'development', NODE_ENV: 'production' })),
    ).toThrow('cannot be used in production');
  });

  it('refuses a provider that has no adapter', () => {
    expect(() =>
      createSmsProvider(configOf({ SMS_PROVIDER: 'not-implemented', NODE_ENV: 'staging' })),
    ).toThrow('No SMS provider is implemented');
  });
});
