import { Module } from '@nestjs/common';
import { SosController } from './sos.controller';
import { SosService } from './sos.service';
import { TwilioService } from '@rihlah/common/notifications/twilio.service';

@Module({
  controllers: [SosController],
  providers: [SosService, TwilioService],
  exports: [SosService],
})
export class SosModule {}
