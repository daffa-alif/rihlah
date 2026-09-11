/**
 * Unified payment gateway interface.
 * Both Midtrans and Xendit implement this so the Payments module can use either
 * (or both, with one as primary and the other as fallback).
 */
export interface PaymentRequest {
  /** Unique order/trip ID. */
  orderId: string;
  /** Amount in IDR (integer). */
  amount: number;
  /** Payment method: qris | gopay | ovo | dana | shopeepay. */
  method: string;
  /** Customer phone for e-wallet deeplink notifications. */
  customerPhone?: string;
  /** Customer name. */
  customerName?: string;
  /** Trip description shown on checkout page. */
  description?: string;
}

export interface PaymentResponse {
  /** Gateway-generated transaction ID. */
  transactionId: string;
  /** For QRIS: QR code payload string. For e-wallet: deeplink URL. */
  paymentCode: string;
  /** For QRIS: rendered QR image URL from gateway. */
  qrImageUrl?: string;
  /** Redirect URL for web-based checkout. */
  redirectUrl?: string;
  /** Payment method used. */
  method: string;
  /** Current status from gateway. */
  status: 'pending' | 'settlement' | 'success' | 'failure' | 'expire';
  /** Raw gateway response for audit. */
  rawResponse: any;
}

export interface WebhookPayload {
  /** Gateway name: midtrans | xendit. */
  gateway: string;
  /** Raw payload from webhook HTTP body. */
  raw: any;
  /** HTTP headers from the webhook request. */
  headers: Record<string, string>;
}

export interface WebhookResult {
  /** Whether the signature/verification passed. */
  verified: boolean;
  /** The order/trip ID extracted from the webhook. */
  orderId: string;
  /** Gateway transaction ID. */
  transactionId: string;
  /** Payment status from gateway. */
  status: 'settlement' | 'success' | 'pending' | 'failure' | 'expire' | 'deny' | 'cancel';
  /** Amount paid in IDR. */
  amount: number;
  /** Payment method. */
  method: string;
  /** Raw webhook data for audit. */
  raw: any;
}

export interface PayoutRequest {
  /** Unique payout ID for idempotency. */
  externalId: string;
  /** Amount in IDR. */
  amount: number;
  /** Destination: bank account number or e-wallet ID. */
  accountNumber: string;
  /** Bank code (e.g. 'bca', 'bni', 'mandiri') or e-wallet provider. */
  bankCode: string;
  /** Account holder name. */
  accountHolderName: string;
  /** Description for the transfer. */
  description?: string;
}

export interface PayoutResponse {
  /** Gateway payout ID. */
  payoutId: string;
  /** Status from gateway. */
  status: 'success' | 'pending' | 'failed';
  /** Estimated time to complete. */
  estimatedAt?: Date;
  /** Failure reason if applicable. */
  failureReason?: string;
}

export interface IPaymentGateway {
  readonly name: string;

  /** Create a payment transaction (QRIS code, e-wallet redirect, etc). */
  createPayment(request: PaymentRequest): Promise<PaymentResponse>;

  /** Verify and parse a webhook callback. */
  verifyWebhook(payload: WebhookPayload): Promise<WebhookResult>;

  /** Disburse money to a driver's bank account or e-wallet. */
  createDisbursement(request: PayoutRequest): Promise<PayoutResponse>;
}
