import { Module } from '@nestjs/common';
import { TripsController } from './trips.controller';
import { TripsService } from './trips.service';
import { FareCalculatorService } from '@rihlah/common';

@Module({
  controllers: [TripsController],
  providers: [TripsService, FareCalculatorService],
  exports: [TripsService],
})
export class TripsModule {}
