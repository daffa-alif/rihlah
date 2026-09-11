import { Module } from '@nestjs/common';
import { PaymentModule } from '@rihlah/payment';
import { PaymentsController, PaymentsWebhookController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  imports: [PaymentModule],
  controllers: [PaymentsController, PaymentsWebhookController],
  providers: [PaymentsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
