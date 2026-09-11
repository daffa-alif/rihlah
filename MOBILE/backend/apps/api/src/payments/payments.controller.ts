import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  Headers,
  Req,
  UseGuards,
} from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('payments')
@UseGuards(FirebaseAuthGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  /** Create/initiate a payment for a trip. */
  @Post()
  async create(@Body() dto: CreatePaymentDto) {
    return this.paymentsService.create(dto);
  }

  /** Get payment by trip ID. */
  @Get('trip/:tripId')
  async getByTrip(@Param('tripId') tripId: string) {
    return this.paymentsService.findByTrip(tripId);
  }

  /** Driver confirms cash payment received. */
  @Patch('trip/:tripId/cash-confirm')
  async confirmCash(
    @Param('tripId') tripId: string,
    @Body('driverId') driverId: string,
  ) {
    return this.paymentsService.confirmCash(tripId, driverId);
  }

  /** Admin: list all payments. */
  @Get()
  @Roles('admin')
  @UseGuards(RolesGuard)
  async findAll(
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.paymentsService.findAll({ status, limit, offset });
  }
}

/**
 * Webhook endpoints — NO auth guard (external gateway callbacks).
 * Signature verification happens inside the service.
 */
@Controller('payments/webhook')
export class PaymentsWebhookController {
  constructor(private readonly paymentsService: PaymentsService) {}

  /** Midtrans webhook receiver. */
  @Post('midtrans')
  async midtrans(@Body() body: any, @Headers() headers: Record<string, string>) {
    return this.paymentsService.handleWebhook('midtrans', body, headers);
  }

  /** Xendit webhook receiver. */
  @Post('xendit')
  async xendit(@Body() body: any, @Headers() headers: Record<string, string>) {
    return this.paymentsService.handleWebhook('xendit', body, headers);
  }
}
