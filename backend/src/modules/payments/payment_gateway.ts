import { randomBytes } from 'node:crypto';
import { hmacSha256Hex, safeEqualHex } from '../../common/crypto/secure-hash';
import { ApiException } from '../../common/errors/api-exception';

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

export interface PaymentGateway {
  readonly key: 'razorpay' | 'development';
  createOrder(input: { amountPaise: number; currency: string; receipt: string }): Promise<GatewayOrder>;
  /** True when the signature proves this payment belongs to this order. */
  verifyPaymentSignature(gatewayOrderId: string, gatewayPaymentId: string, signature: string): boolean;
  /** Development only: the signature the gateway itself would give for a paid order. */
  signForDevelopment?(gatewayOrderId: string, gatewayPaymentId: string): string;
}

export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');

export class DevelopmentPaymentGateway implements PaymentGateway {
  readonly key = 'development' as const;

  constructor(private readonly secret: string) {}

  createOrder(): Promise<GatewayOrder> {
    return Promise.resolve({ gatewayOrderId: `dev_order_${randomBytes(9).toString('hex')}`, keyId: 'development' });
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
  ) {}

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
