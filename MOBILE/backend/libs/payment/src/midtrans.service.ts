import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';
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
 * Midtrans payment gateway integration (https://midtrans.com).
 *
 * Midtrans is the primary Indonesian payment aggregator — supports QRIS,
 * GoPay, OVO, DANA, ShopeePay, bank transfer, and convenience store.
 *
 * Uses Midtrans Snap API (simplest integration for MVP).
 * Production base URL: https://app.midtrans.com/snap/v1
 * Sandbox base URL:    https://app.sandbox.midtrans.com/snap/v1
 */
@Injectable()
export class MidtransService implements IPaymentGateway {
  readonly name = 'midtrans';

  private readonly serverKey: string;
  private readonly clientKey: string;
  private readonly merchantId: string;
  private readonly baseUrl: string;

  constructor() {
    this.serverKey = process.env.MIDTRANS_SERVER_KEY || '';
    this.clientKey = process.env.MIDTRANS_CLIENT_KEY || '';
    this.merchantId = process.env.MIDTRANS_MERCHANT_ID || '';
    // Detect sandbox vs production from the server key prefix
    this.baseUrl = this.serverKey.startsWith('SB-Mid-server-')
      ? 'https://app.sandbox.midtrans.com'
      : 'https://app.midtrans.com';
  }

  // ── Create Payment ───────────────────────────────────────────────────────────

  async createPayment(request: PaymentRequest): Promise<PaymentResponse> {
    const orderId = request.orderId;
    const amount = request.amount;

    const payload: any = {
      transaction_details: {
        order_id: orderId,
        gross_amount: amount,
      },
      customer_details: {
        first_name: request.customerName || 'RIHLAH Passenger',
        phone: request.customerPhone || '',
      },
      item_details: [
        {
          id: orderId,
          price: amount,
          quantity: 1,
          name: request.description || 'RIHLAH Ride',
        },
      ],
      callbacks: {
        finish: `rihlah://payment/success?order_id=${orderId}`,
        error: `rihlah://payment/error?order_id=${orderId}`,
        pending: `rihlah://payment/pending?order_id=${orderId}`,
      },
    };

    // Enable specific payment methods based on request
    if (request.method === 'qris') {
      payload.enabled_payments = ['qris'];
    } else if (['gopay', 'ovo', 'dana', 'shopeepay'].includes(request.method)) {
      // Map RIHLAH method names to Midtrans channel names
      payload.enabled_payments = [this.mapToMidtransChannel(request.method)];
    }

    const response = await this.apiCall('POST', '/snap/v1/transactions', payload);

    // For QRIS, extract the QR string from the response
    let paymentCode = '';
    let qrImageUrl: string | undefined;

    if (request.method === 'qris' && response.actions) {
      const qrisAction = response.actions.find(
        (a: any) => a.name === 'generate-qr-code',
      );
      if (qrisAction) {
        paymentCode = qrisAction.url; // Midtrans deeplink for QR
      }
    }

    return {
      transactionId: response.token || response.transaction_id || orderId,
      paymentCode: paymentCode || response.redirect_url || '',
      qrImageUrl,
      redirectUrl: response.redirect_url,
      method: request.method,
      status: this.mapStatus(response.transaction_status || 'pending'),
      rawResponse: response,
    };
  }

  // ── Webhook Verification ─────────────────────────────────────────────────────

  async verifyWebhook(payload: WebhookPayload): Promise<WebhookResult> {
    const notification = payload.raw;

    // Midtrans sends notification as JSON body
    const orderId = notification.order_id;
    const statusCode = notification.status_code;
    const grossAmount = String(notification.gross_amount);
    const transactionStatus = notification.transaction_status;
    const fraudStatus = notification.fraud_status;

    // Verify signature: SHA512(order_id + status_code + gross_amount + server_key)
    const signatureKey = crypto
      .createHash('sha512')
      .update(`${orderId}${statusCode}${grossAmount}${this.serverKey}`)
      .digest('hex');

    const verified = signatureKey === notification.signature_key;

    // Determine final status
    let status: WebhookResult['status'] = 'pending';
    if (transactionStatus === 'capture' || transactionStatus === 'settlement') {
      if (fraudStatus === 'accept') {
        status = 'settlement';
      }
    } else if (transactionStatus === 'success') {
      status = 'success';
    } else if (
      transactionStatus === 'cancel' ||
      transactionStatus === 'deny' ||
      transactionStatus === 'expire'
    ) {
      status = transactionStatus;
    } else if (transactionStatus === 'failure') {
      status = 'failure';
    }

    return {
      verified,
      orderId,
      transactionId: notification.transaction_id || orderId,
      status,
      amount: parseInt(grossAmount, 10) || 0,
      method: this.extractMethod(notification),
      raw: notification,
    };
  }

  // ── Disbursement (Payout) ────────────────────────────────────────────────────

  async createDisbursement(request: PayoutRequest): Promise<PayoutResponse> {
    // Midtrans Iris for disbursements (separate API)
    const payload = {
      beneficiary: {
        name: request.accountHolderName,
        account: request.accountNumber,
        bank: request.bankCode.toUpperCase(),
      },
      amount: request.amount,
      notes: request.description || 'RIHLAH driver payout',
      external_id: request.externalId,
    };

    try {
      const response = await this.apiCall('POST', '/iris/api/v1/payouts', payload);

      return {
        payoutId: response.payout_id || request.externalId,
        status: response.status === 'accepted' ? 'pending' : 'failed',
        failureReason: response.rejection_reason,
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
    const auth = Buffer.from(`${this.serverKey}:`).toString('base64');
    const url = `${this.baseUrl}${path}`;

    const response = await fetch(url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`,
        'Accept': 'application/json',
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Midtrans API error (${response.status}): ${error}`);
    }

    return response.json();
  }

  private mapToMidtransChannel(method: string): string {
    const map: Record<string, string> = {
      gopay: 'gopay',
      ovo: 'ovo',
      dana: 'dana',
      shopeepay: 'shopeepay',
      qris: 'qris',
    };
    return map[method] || method;
  }

  private mapStatus(status: string): PaymentResponse['status'] {
    if (status === 'capture' || status === 'settlement' || status === 'success') {
      return 'success';
    }
    if (status === 'pending') return 'pending';
    if (status === 'expire') return 'expire';
    return 'failure';
  }

  private extractMethod(notification: any): string {
    // Try to determine payment method from notification
    if (notification.payment_type) return notification.payment_type;
    if (notification.va_numbers?.length > 0) return 'bank_transfer';
    return 'unknown';
  }
}
