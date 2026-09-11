import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { PayoutsService } from './payouts.service';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('payouts')
@UseGuards(FirebaseAuthGuard)
export class PayoutsController {
  constructor(private readonly payoutsService: PayoutsService) {}

  /** Driver initiates a withdrawal. */
  @Post()
  async create(@Body() dto: CreatePayoutDto) {
    return this.payoutsService.create(dto);
  }

  /** Get a driver's payout history. */
  @Get('driver/:driverId')
  async findByDriver(@Param('driverId') driverId: string) {
    return this.payoutsService.findByDriver(driverId);
  }

  /** Admin: list all payouts. */
  @Get()
  @Roles('admin')
  @UseGuards(RolesGuard)
  async findAll(
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.payoutsService.findAll({ status, limit, offset });
  }

  /** Admin: manually settle a stuck payout. */
  @Patch(':id/settle')
  @Roles('admin')
  @UseGuards(RolesGuard)
  async settle(@Param('id') id: string) {
    return this.payoutsService.adminSettle(id);
  }

  /** Admin: manually fail/reject a payout. */
  @Patch(':id/fail')
  @Roles('admin')
  @UseGuards(RolesGuard)
  async fail(@Param('id') id: string, @Body('reason') reason?: string) {
    return this.payoutsService.adminFail(id, reason);
  }
}
