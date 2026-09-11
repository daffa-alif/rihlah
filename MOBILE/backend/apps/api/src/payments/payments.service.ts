import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '@rihlah/database';
import { MidtransService, XenditService } from '@rihlah/payment';
import { CreatePaymentDto } from './dto/create-payment.dto';
import * as crypto from 'crypto';

type PaymentStatus = 'PENDING' | 'AUTHENTICATING' | 'SETTLED' | 'COMPLETED' | 'FAILED' | 'EXPIRED' | 'CASH_CONFIRMED';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly midtrans: MidtransService,
    private readonly xendit: XenditService,
  ) {}

  // ── Create Payment ───────────────────────────────────────────────────────────

  async create(dto: CreatePaymentDto) {
    // 1. Validate trip exists and status is appropriate
    const trip = await this.prisma.trip.findUnique({
      where: { id: dto.tripId },
    });
    if (!trip) throw new NotFoundException('Trip not found');

    // 2. Generate idempotency key
    const idempotencyKey = this.generateIdempotencyKey(dto.tripId, dto.method);

    // 3. Check for existing payment (idempotency)
    const existing = await this.prisma.payment.findUnique({
      where: { tripId: dto.tripId },
    });
    if (existing) {
      if (existing.status === 'SETTLED' || existing.status === 'COMPLETED') {
        throw new ConflictException('Payment already completed for this trip');
      }
      // Return existing pending payment
      return existing;
    }

    // 4. Cash payment — no gateway call needed
    if (dto.method === 'cash') {
      return this.prisma.payment.create({
        data: {
          tripId: dto.tripId,
          method: 'cash',
          amountIdr: dto.amountIdr,
          status: 'PENDING', // becomes CASH_CONFIRMED when driver confirms
          idempotencyKey,
        },
      });
    }

    // 5. Online payment — call payment gateway
    const gateway = this.selectGateway(dto.method);

    const gatewayResponse = await gateway.createPayment({
      orderId: dto.tripId,
      amount: dto.amountIdr,
      method: dto.method,
      customerName: dto.customerName,
      customerPhone: dto.customerPhone,
      description: `RIHLAH Trip ${dto.tripId.substring(0, 8)}`,
    });

    // 6. Persist payment record
    return this.prisma.payment.create({
      data: {
        tripId: dto.tripId,
        method: dto.method,
        amountIdr: dto.amountIdr,
        status: 'AUTHENTICATING',
        gatewayRef: gatewayResponse.transactionId,
        idempotencyKey,
      },
    });
  }

  // ── Webhook Handler ──────────────────────────────────────────────────────────

  /**
   * Process incoming webhook from Midtrans or Xendit.
   * This is the single entry point for payment status updates.
   */
  async handleWebhook(gateway: 'midtrans' | 'xendit', raw: any, headers: Record<string, string>) {
    const service = gateway === 'midtrans' ? this.midtrans : this.xendit;

    const result = await service.verifyWebhook({
      gateway,
      raw,
      headers,
    });

    if (!result.verified) {
      console.warn(`Webhook verification failed for ${gateway}`, result.orderId);
      // Still log it — don't throw, Midtrans sometimes sends test notifications
    }

    // Find the payment by trip ID (order ID)
    const tripId = result.orderId;
    const payment = await this.prisma.payment.findUnique({
      where: { tripId },
    });

    if (!payment) {
      console.warn(`No payment found for trip ${tripId}`);
      return { received: true, action: 'ignored', reason: 'no payment record' };
    }

    // Map gateway status to internal status
    const internalStatus = this.mapGatewayStatus(result.status);

    // Update payment
    const updated = await this.prisma.payment.update({
      where: { tripId },
      data: {
        status: internalStatus,
        gatewayRef: result.transactionId || payment.gatewayRef,
        webhookRaw: result.raw,
        ...(internalStatus === 'SETTLED' || internalStatus === 'COMPLETED'
          ? { settledAt: new Date() }
          : {}),
      },
    });

    // If payment settled, update trip payment status
    if (internalStatus === 'SETTLED' || internalStatus === 'COMPLETED') {
      await this.prisma.trip.update({
        where: { id: tripId },
        data: { paymentMethod: payment.method },
      });
    }

    return { received: true, action: 'updated', status: internalStatus };
  }

  // ── Cash Confirmation ────────────────────────────────────────────────────────

  /**
   * Driver confirms cash payment received at trip end.
   * This transitions the payment from PENDING to CASH_CONFIRMED.
   */
  async confirmCash(tripId: string, driverId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { tripId },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    if (payment.method !== 'cash') {
      throw new BadRequestException('Only cash payments can be confirmed this way');
    }

    return this.prisma.payment.update({
      where: { tripId },
      data: { status: 'CASH_CONFIRMED' },
    });
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  async findByTrip(tripId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { tripId },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    return payment;
  }

  async findAll(params: { status?: string; limit?: number; offset?: number }) {
    const { status, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (status) where.status = status;

    const [payments, total] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return { data: payments, total, limit, offset };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  private generateIdempotencyKey(tripId: string, method: string): string {
    // tripId + method + random to ensure uniqueness while allowing retries
    const rand = crypto.randomBytes(8).toString('hex');
    return `pay_${tripId}_${method}_${rand}`;
  }

  /** Choose the primary gateway. Midtrans for QRIS + e-wallets. */
  private selectGateway(method: string) {
    // Both gateways support all methods; prefer Midtrans as primary
    return this.midtrans;
  }

  private mapGatewayStatus(gatewayStatus: string): PaymentStatus {
    switch (gatewayStatus) {
      case 'settlement':
      case 'success':
        return 'SETTLED';
      case 'pending':
        return 'PENDING';
      case 'expire':
        return 'EXPIRED';
      case 'failure':
      case 'deny':
      case 'cancel':
        return 'FAILED';
      default:
        return 'PENDING';
    }
  }
}
