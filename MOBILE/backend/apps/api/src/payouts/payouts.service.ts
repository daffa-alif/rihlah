import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@rihlah/database';
import { MidtransService } from '@rihlah/payment';
import { CreatePayoutDto } from './dto/create-payout.dto';
import * as crypto from 'crypto';

@Injectable()
export class PayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly midtrans: MidtransService,
  ) {}

  // ── Create Payout ────────────────────────────────────────────────────────────

  async create(dto: CreatePayoutDto) {
    // 1. Validate driver exists and has sufficient balance
    const driver = await this.prisma.driver.findUnique({
      where: { userId: dto.driverId },
    });
    if (!driver) throw new NotFoundException('Driver not found');

    if (driver.balanceIdr < dto.amountIdr) {
      throw new BadRequestException(
        `Insufficient balance. Available: Rp ${driver.balanceIdr.toLocaleString('id-ID')}, ` +
        `Requested: Rp ${dto.amountIdr.toLocaleString('id-ID')}`,
      );
    }

    // 2. Check if this is the first withdrawal today (free) or subsequent (fee)
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayWithdrawals = await this.prisma.payout.count({
      where: {
        driverId: dto.driverId,
        requestedAt: { gte: today },
        status: { not: 'FAILED' },
      },
    });

    const feeIdr = todayWithdrawals === 0 ? 0 : 1000; // Rp 1.000 for subsequent
    const netAmount = dto.amountIdr - feeIdr;

    if (netAmount < 20000) {
      throw new BadRequestException(
        `After fee (Rp ${feeIdr.toLocaleString('id-ID')}), ` +
        `net amount (Rp ${netAmount.toLocaleString('id-ID')}) is below minimum withdrawal (Rp 20.000)`,
      );
    }

    // 3. Generate idempotency key
    const idempotencyKey = this.generateIdempotencyKey(dto.driverId, dto.amountIdr);

    // 4. Atomically debit driver balance
    await this.prisma.driver.update({
      where: { userId: dto.driverId },
      data: { balanceIdr: { decrement: dto.amountIdr } },
    });

    // 5. Create payout record
    const payout = await this.prisma.payout.create({
      data: {
        driverId: dto.driverId,
        amountIdr: dto.amountIdr,
        feeIdr,
        destination: dto.destination,
        status: 'PROCESSING',
        idempotencyKey,
      },
    });

    // 6. Initiate disbursement via payment gateway (async — don't block response)
    this.processDisbursement(payout.id, dto).catch((err) => {
      console.error(`Disbursement failed for payout ${payout.id}:`, err);
    });

    return payout;
  }

  // ── Disbursement Processing ──────────────────────────────────────────────────

  private async processDisbursement(payoutId: string, dto: CreatePayoutDto) {
    try {
      const result = await this.midtrans.createDisbursement({
        externalId: payoutId,
        amount: dto.amountIdr - (dto.amountIdr > 20000 ? 1000 : 0), // net after fee
        accountNumber: dto.destination,
        bankCode: dto.bankCode || 'bca',
        accountHolderName: dto.accountHolderName || 'RIHLAH Driver',
        description: `RIHLAH driver payout #${payoutId.substring(0, 8)}`,
      });

      if (result.status === 'pending') {
        await this.prisma.payout.update({
          where: { id: payoutId },
          data: { gatewayRef: result.payoutId, status: 'PROCESSING' },
        });
      } else if (result.status === 'success') {
        await this.prisma.payout.update({
          where: { id: payoutId },
          data: { gatewayRef: result.payoutId, status: 'SUCCESS', paidAt: new Date() },
        });
      } else {
        // Failed — refund to driver balance
        await this.refundFailedPayout(payoutId, result.failureReason);
      }
    } catch (err: any) {
      // Refund on error
      await this.refundFailedPayout(payoutId, err.message || 'Disbursement API error');
    }
  }

  private async refundFailedPayout(payoutId: string, reason?: string) {
    const payout = await this.prisma.payout.findUnique({ where: { id: payoutId } });
    if (!payout || payout.status === 'FAILED') return; // already refunded

    // Refund to driver balance
    await this.prisma.driver.update({
      where: { userId: payout.driverId },
      data: { balanceIdr: { increment: payout.amountIdr } },
    });

    // Mark payout as failed
    await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: 'FAILED',
        failedAt: new Date(),
        failureReason: reason || 'Unknown error',
      },
    });
  }

  // ── Admin Manual Settlement ──────────────────────────────────────────────────

  async adminSettle(payoutId: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
    });
    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status !== 'PROCESSING') {
      throw new BadRequestException(`Cannot settle payout in status: ${payout.status}`);
    }

    return this.prisma.payout.update({
      where: { id: payoutId },
      data: { status: 'SUCCESS', paidAt: new Date() },
    });
  }

  async adminFail(payoutId: string, reason?: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
    });
    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status === 'SUCCESS' || payout.status === 'FAILED') {
      throw new BadRequestException('Payout is already final');
    }

    return this.refundFailedPayout(payoutId, reason || 'Admin rejection');
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  async findByDriver(driverId: string, limit = 50) {
    return this.prisma.payout.findMany({
      where: { driverId },
      orderBy: { requestedAt: 'desc' },
      take: limit,
    });
  }

  async findAll(params: { status?: string; limit?: number; offset?: number }) {
    const { status, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (status) where.status = status;

    const [payouts, total] = await Promise.all([
      this.prisma.payout.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { requestedAt: 'desc' },
      }),
      this.prisma.payout.count({ where }),
    ]);

    return { data: payouts, total, limit, offset };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  private generateIdempotencyKey(driverId: string, amount: number): string {
    const rand = crypto.randomBytes(8).toString('hex');
    return `payout_${driverId}_${amount}_${rand}`;
  }
}
