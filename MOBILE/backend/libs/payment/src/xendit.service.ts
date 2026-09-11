import { Injectable } from '@nestjs/common';
import {
  IPaymentGateway,
  PaymentRequest,
  PaymentResponse,
  WebhookPayload,
  WebhookResult,
  PayoutRequest,
  PayoutResponse,
} from './payment-gateway.interface';

/**
 * Xendit payment gateway integration (https://xendit.co).
 *
 * Backup/alternative gateway. Uses Xendit Invoice API for payments
 * and Xendit Disbursement API for driver payouts.
 */
@Injectable()
export class XenditService implements IPaymentGateway {
  readonly name = 'xendit';

  private readonly apiKey: string;
  private readonly callbackToken: string;
  private readonly baseUrl: string;

  constructor() {
    this.apiKey = process.env.XENDIT_API_KEY || '';
    // Callback token for webhook verification (set in Xendit dashboard)
    this.callbackToken = process.env.XENDIT_CALLBACK_TOKEN || '';
    this.baseUrl = 'https://api.xendit.co';
  }

  // ── Create Payment ───────────────────────────────────────────────────────────

  async createPayment(request: PaymentRequest): Promise<PaymentResponse> {
    const payload: any = {
      external_id: request.orderId,
      amount: request.amount,
      payer_email: `${request.orderId}@rihlah.id`,
      description: request.description || 'RIHLAH Ride',
      should_send_email: false,
      success_redirect_url: `rihlah://payment/success?order_id=${request.orderId}`,
      failure_redirect_url: `rihlah://payment/error?order_id=${request.orderId}`,
      payment_methods: [this.mapToXenditMethod(request.method)],
      currency: 'IDR',
      customer: {
        given_names: request.customerName || 'RIHLAH Passenger',
        mobile_number: request.customerPhone || '',
      },
    };

    const response = await this.apiCall('POST', '/v2/invoices', payload);

    return {
      transactionId: response.id,
      paymentCode: response.invoice_url,
      redirectUrl: response.invoice_url,
      method: request.method,
      status: this.mapStatus(response.status),
      rawResponse: response,
    };
  }

  // ── Webhook Verification ─────────────────────────────────────────────────────

  async verifyWebhook(payload: WebhookPayload): Promise<WebhookResult> {
    const body = payload.raw;
    const headers = payload.headers;

    // Xendit callback verification token
    const receivedToken = headers['x-callback-token'] || '';
    const verified = receivedToken === this.callbackToken && this.callbackToken !== '';

    const orderId = body.external_id || body.id;
    const status = body.status as string;
    const amount = body.amount || body.paid_amount || 0;

    let mappedStatus: WebhookResult['status'] = 'pending';
    if (status === 'PAID' || status === 'SETTLED') {
      mappedStatus = 'success';
    } else if (status === 'EXPIRED') {
      mappedStatus = 'expire';
    } else if (status === 'FAILED') {
      mappedStatus = 'failure';
    }

    return {
      verified,
      orderId,
      transactionId: body.id || orderId,
      status: mappedStatus,
      amount: parseInt(String(amount), 10) || 0,
      method: body.payment_method || body.payment_channel || 'unknown',
      raw: body,
    };
  }

  // ── Disbursement (Payout) ────────────────────────────────────────────────────

  async createDisbursement(request: PayoutRequest): Promise<PayoutResponse> {
    const payload = {
      external_id: request.externalId,
      amount: request.amount,
      bank_code: request.bankCode.toUpperCase(),
      account_holder_name: request.accountHolderName,
      account_number: request.accountNumber,
      description: request.description || 'RIHLAH driver payout',
    };

    try {
      const response = await this.apiCall('POST', '/disbursements', payload);

      return {
        payoutId: response.id,
        status: response.status === 'COMPLETED' ? 'success' : 'pending',
        estimatedAt: response.expected_amount
          ? new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h estimate
          : undefined,
      };
    } catch (err: any) {
      return {
        payoutId: request.externalId,
        status: 'failed',
        failureReason: err.message || 'Disbursement API call failed',
      };
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  private async apiCall(
    method: string,
    path: string,
    body?: any,
  ): Promise<any> {
    const url = `${this.baseUrl}${path}`;

    const response = await fetch(url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${Buffer.from(this.apiKey + ':').toString('base64')}`,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Xendit API error (${response.status}): ${error}`);
    }

    return response.json();
  }

  private mapToXenditMethod(method: string): string {
    const map: Record<string, string> = {
      qris: 'QRIS',
      gopay: 'GOPAY',
      ovo: 'OVO',
      dana: 'DANA',
      shopeepay: 'SHOPEEPAY',
    };
    return map[method] || method;
  }

  private mapStatus(status: string): PaymentResponse['status'] {
    if (status === 'PAID' || status === 'SETTLED') return 'success';
    if (status === 'PENDING') return 'pending';
    if (status === 'EXPIRED') return 'expire';
    return 'failure';
  }
}
