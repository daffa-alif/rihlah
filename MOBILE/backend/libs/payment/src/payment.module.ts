import { Module } from '@nestjs/common';
import { MidtransService } from './midtrans.service';
import { XenditService } from './xendit.service';

@Module({
  providers: [MidtransService, XenditService],
  exports: [MidtransService, XenditService],
})
export class PaymentModule {}
