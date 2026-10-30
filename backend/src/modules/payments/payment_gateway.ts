import { randomBytes } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { hmacSha256Hex, safeEqualHex } from '../../common/crypto/secure-hash';
import { ApiException } from '../../common/errors/api-exception';
import { AppConfigService } from '../../config/app-config.service';
import { IntegrationSettingsStore } from '../system-settings/integrations_admin_manage.service';

/*
 * The payment gateway behind one interface (documentation/payment-flow.md section 1). Razorpay is
 * the real one. The development gateway is a labelled test gateway for local work only: it makes
 * orders and signatures itself, so the same verification path runs with no outside call.
 */

export interface GatewayOrder {
  gatewayOrderId: string;
  /** What the app needs to open the checkout (Razorpay key id; "development" for the test gateway). */
  keyId: string;
}

/** A payment event from the gateway, in one shape for every gateway. */
export interface GatewayWebhookEvent {
  type: 'payment.captured' | 'payment.failed' | 'refund.processed' | 'other';
  gatewayOrderId?: string;
  gatewayPaymentId?: string;
  gatewayRefundId?: string;
  amountPaise?: number;
  currency?: string;
}

export interface GatewayRefund {
  gatewayRefundId: string;
  status: 'PENDING' | 'COMPLETED';
}

export interface PaymentGateway {
  readonly key: 'razorpay' | 'development';
  /** True when the signature proves these exact bytes came from the gateway. */
  verifyWebhookSignature(rawBody: Buffer, signature: string): boolean;
  parseWebhookEvent(rawBody: Buffer): GatewayWebhookEvent;
  /** Sends money back for a captured payment. */
  createRefund(input: { gatewayPaymentId: string; amountPaise: number; receipt: string }): Promise<GatewayRefund>;
  /** Development only: the webhook signature the gateway itself would give. */
  signWebhookForDevelopment?(rawBody: Buffer): string;
  createOrder(input: { amountPaise: number; currency: string; receipt: string }): Promise<GatewayOrder>;
  /** True when the signature proves this payment belongs to this order. */
  verifyPaymentSignature(gatewayOrderId: string, gatewayPaymentId: string, signature: string): boolean;
  /** Development only: the signature the gateway itself would give for a paid order. */
  signForDevelopment?(gatewayOrderId: string, gatewayPaymentId: string): string;
}


export class DevelopmentPaymentGateway implements PaymentGateway {
  readonly key = 'development' as const;

  constructor(private readonly secret: string) {}

  createOrder(): Promise<GatewayOrder> {
    return Promise.resolve({ gatewayOrderId: `dev_order_${randomBytes(9).toString('hex')}`, keyId: 'development' });
  }

  signWebhookForDevelopment(rawBody: Buffer): string {
    return hmacSha256Hex(`${this.secret}:dev-webhook`, rawBody.toString('utf8'));
  }

  verifyWebhookSignature(rawBody: Buffer, signature: string): boolean {
    return safeEqualHex(this.signWebhookForDevelopment(rawBody), signature);
  }

  parseWebhookEvent(rawBody: Buffer): GatewayWebhookEvent {
    return parseRazorpayShape(rawBody);
  }

  createRefund(input: { gatewayPaymentId: string; amountPaise: number; receipt: string }): Promise<GatewayRefund> {
    void input;
    return Promise.resolve({ gatewayRefundId: `dev_refund_${randomBytes(9).toString('hex')}`, status: 'COMPLETED' });
  }

  signForDevelopment(gatewayOrderId: string, gatewayPaymentId: string): string {
    return hmacSha256Hex(`${this.secret}:dev-payments`, `${gatewayOrderId}|${gatewayPaymentId}`);
  }

  verifyPaymentSignature(gatewayOrderId: string, gatewayPaymentId: string, signature: string): boolean {
    return safeEqualHex(this.signForDevelopment(gatewayOrderId, gatewayPaymentId), signature);
  }
}

export class RazorpayPaymentGateway implements PaymentGateway {
  readonly key = 'razorpay' as const;

  constructor(
    private readonly keyId: string,
    private readonly keySecret: string,
    private readonly webhookSecret: string = '',
  ) {}

  /** Razorpay: HMAC-SHA256 of the raw body with the webhook secret, in the X-Razorpay-Signature header. */
  verifyWebhookSignature(rawBody: Buffer, signature: string): boolean {
    if (this.webhookSecret === '') return false;
    return safeEqualHex(hmacSha256Hex(this.webhookSecret, rawBody.toString('utf8')), signature);
  }

  parseWebhookEvent(rawBody: Buffer): GatewayWebhookEvent {
    return parseRazorpayShape(rawBody);
  }

  async createRefund(input: { gatewayPaymentId: string; amountPaise: number; receipt: string }): Promise<GatewayRefund> {
    let response: Response;
    try {
      response = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(input.gatewayPaymentId)}/refund`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
        },
        body: JSON.stringify({ amount: input.amountPaise, receipt: input.receipt }),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service could not be reached. Please try again.');
    }
    if (!response.ok) {
      throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service refused the refund. Please try again.');
    }
    const body = (await response.json()) as { id?: string; status?: string };
    if (!body.id) throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service gave no refund.');
    return { gatewayRefundId: body.id, status: body.status === 'processed' ? 'COMPLETED' : 'PENDING' };
  }

  async createOrder(input: { amountPaise: number; currency: string; receipt: string }): Promise<GatewayOrder> {
    let response: Response;
    try {
      response = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
        },
        body: JSON.stringify({ amount: input.amountPaise, currency: input.currency, receipt: input.receipt }),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service could not be reached. Please try again.');
    }
    if (!response.ok) {
      throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service refused the order. Please try again.');
    }
    const body = (await response.json()) as { id?: string };
    if (!body.id) throw new ApiException('PAYMENT_PROVIDER_UNAVAILABLE', 'The payment service gave no order.');
    return { gatewayOrderId: body.id, keyId: this.keyId };
  }

  /** Razorpay: HMAC-SHA256 of "order_id|payment_id" with the key secret. */
  verifyPaymentSignature(gatewayOrderId: string, gatewayPaymentId: string, signature: string): boolean {
    return safeEqualHex(hmacSha256Hex(this.keySecret, `${gatewayOrderId}|${gatewayPaymentId}`), signature);
  }
}

/** The shape both Razorpay and the development gateway send. Anything unreadable is "other". */
function parseRazorpayShape(rawBody: Buffer): GatewayWebhookEvent {
  try {
    const body = JSON.parse(rawBody.toString('utf8')) as {
      event?: string;
      payload?: {
        payment?: { entity?: { id?: string; order_id?: string; amount?: number; currency?: string } };
        refund?: { entity?: { id?: string; payment_id?: string; amount?: number } };
      };
    };
    const payment = body.payload?.payment?.entity;
    const refund = body.payload?.refund?.entity;
    if (body.event === 'payment.captured' || body.event === 'payment.failed') {
      return {
        type: body.event,
        ...(payment?.order_id ? { gatewayOrderId: payment.order_id } : {}),
        ...(payment?.id ? { gatewayPaymentId: payment.id } : {}),
        ...(typeof payment?.amount === 'number' ? { amountPaise: payment.amount } : {}),
        ...(payment?.currency ? { currency: payment.currency } : {}),
      };
    }
    if (body.event === 'refund.processed') {
      return {
        type: 'refund.processed',
        ...(refund?.id ? { gatewayRefundId: refund.id } : {}),
        ...(refund?.payment_id ? { gatewayPaymentId: refund.payment_id } : {}),
        ...(typeof refund?.amount === 'number' ? { amountPaise: refund.amount } : {}),
      };
    }
  } catch {
    // not JSON: handled as "other"
  }
  return { type: 'other' };
}

/**
 * The gateway to use right now. PAYMENT_GATEWAY says which kind (razorpay, or the labelled
 * development gateway). For Razorpay the keys are the ones saved in Settings, Integrations in the
 * admin app, and only when none is saved there the ones in the environment. So changing a key in
 * the admin app takes effect within seconds, with no restart.
 */
@Injectable()
export class PaymentGatewayProvider {
  private razorpay: { fingerprint: string; gateway: RazorpayPaymentGateway } | undefined;
  private readonly development: DevelopmentPaymentGateway;

  constructor(
    private readonly config: AppConfigService,
    private readonly settings: IntegrationSettingsStore,
  ) {
    this.development = new DevelopmentPaymentGateway(this.config.get('OTP_HASH_SECRET'));
  }

  async current(): Promise<PaymentGateway> {
    if (this.config.get('PAYMENT_GATEWAY') !== 'razorpay') return this.development;
    const { enabled, values } = await this.settings.effective('razorpay');
    const keyId = values.keyId ?? '';
    const keySecret = values.keySecret ?? '';
    if (!enabled || keyId === '' || keySecret === '') {
      throw new ApiException(
        'PAYMENT_PROVIDER_UNAVAILABLE',
        'Online payments are not set up yet. Please try again later.',
      );
    }
    const webhookSecret = values.webhookSecret ?? '';
    const fingerprint = `${keyId}|${keySecret}|${webhookSecret}`;
    if (this.razorpay?.fingerprint !== fingerprint) {
      this.razorpay = { fingerprint, gateway: new RazorpayPaymentGateway(keyId, keySecret, webhookSecret) };
    }
    return this.razorpay.gateway;
  }
}
