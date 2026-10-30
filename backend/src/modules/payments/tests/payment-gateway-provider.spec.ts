import { type AppConfigService } from '../../../config/app-config.service';
import { type IntegrationSettingsStore } from '../../system-settings/integrations_admin_manage.service';
import { DevelopmentPaymentGateway, PaymentGatewayProvider, RazorpayPaymentGateway } from '../payment_gateway';

function provider(
  kind: 'razorpay' | 'development',
  settings: { enabled: boolean; values: Record<string, string | undefined> },
) {
  const config = {
    get: (key: string) => (key === 'PAYMENT_GATEWAY' ? kind : 'a-development-secret-of-some-length'),
  } as unknown as AppConfigService;
  const state = { ...settings };
  const store = {
    effective: () => Promise.resolve({ enabled: state.enabled, values: state.values, sources: {} }),
  } as unknown as IntegrationSettingsStore;
  return { gateways: new PaymentGatewayProvider(config, store), state };
}

describe('PaymentGatewayProvider', () => {
  it('uses the labelled development gateway when PAYMENT_GATEWAY says so, whatever is saved', async () => {
    const { gateways } = provider('development', { enabled: true, values: { keyId: 'rzp_test_abcdef12', keySecret: 'x'.repeat(20) } });
    expect(await gateways.current()).toBeInstanceOf(DevelopmentPaymentGateway);
  });

  it('uses Razorpay with the keys saved in the admin settings', async () => {
    const { gateways } = provider('razorpay', {
      enabled: true,
      values: { keyId: 'rzp_test_abcdef12', keySecret: 'secret-secret-1', webhookSecret: 'hook-secret-1' },
    });
    const gateway = await gateways.current();
    expect(gateway).toBeInstanceOf(RazorpayPaymentGateway);
    // The webhook secret from the settings is the one that proves a webhook
    const body = Buffer.from('{"event":"payment.captured"}');
    const good = (await import('node:crypto')).createHmac('sha256', 'hook-secret-1').update(body).digest('hex');
    expect(gateway.verifyWebhookSignature(body, good)).toBe(true);
    expect(gateway.verifyWebhookSignature(body, 'a'.repeat(64))).toBe(false);
  });

  it('follows a key changed in the admin app, and keeps the same gateway while nothing changes', async () => {
    const { gateways, state } = provider('razorpay', {
      enabled: true,
      values: { keyId: 'rzp_test_abcdef12', keySecret: 'secret-secret-1', webhookSecret: 'hook-secret-1' },
    });
    const first = await gateways.current();
    expect(await gateways.current()).toBe(first);
    state.values = { ...state.values, keySecret: 'secret-secret-2' };
    expect(await gateways.current()).not.toBe(first);
  });

  it('says payments are not set up when the keys are missing or the card is switched off', async () => {
    const missing = provider('razorpay', { enabled: true, values: { keyId: 'rzp_test_abcdef12' } });
    await expect(missing.gateways.current()).rejects.toMatchObject({ code: 'PAYMENT_PROVIDER_UNAVAILABLE' });
    const off = provider('razorpay', { enabled: false, values: { keyId: 'rzp_test_abcdef12', keySecret: 'secret-secret-1' } });
    await expect(off.gateways.current()).rejects.toMatchObject({ code: 'PAYMENT_PROVIDER_UNAVAILABLE' });
  });

  it('refuses every webhook when no webhook secret is saved', async () => {
    const { gateways } = provider('razorpay', { enabled: true, values: { keyId: 'rzp_test_abcdef12', keySecret: 'secret-secret-1' } });
    const gateway = await gateways.current();
    expect(gateway.verifyWebhookSignature(Buffer.from('{}'), 'a'.repeat(64))).toBe(false);
  });
});
