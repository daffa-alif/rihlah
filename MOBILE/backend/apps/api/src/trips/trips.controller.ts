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
import { TripsService } from './trips.service';
import {
  CreateTripDto,
  DriverActionDto,
  RateTripDto,
} from './dto/create-trip.dto';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('trips')
@UseGuards(FirebaseAuthGuard)
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  /** Passenger books a new trip. */
  @Post()
  async create(@Body() dto: CreateTripDto) {
    return this.tripsService.create(dto);
  }

  /** Get trip by ID. */
  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.tripsService.findById(id);
  }

  /** Driver accepts a trip. */
  @Patch(':id/accept')
  async accept(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.accept(id, dto.driverId);
  }

  /** Driver declines a trip. */
  @Patch(':id/decline')
  async decline(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.decline(id, dto.driverId);
  }

  /** Driver is on the way to pickup. */
  @Patch(':id/arriving')
  async arriving(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.setArriving(id, dto.driverId);
  }

  /** Driver has arrived at pickup. */
  @Patch(':id/arrive')
  async arrive(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.setArrived(id, dto.driverId);
  }

  /** Trip starts (passenger onboard). */
  @Patch(':id/start')
  async start(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.startTrip(id, dto.driverId);
  }

  /** Trip completed. */
  @Patch(':id/complete')
  async complete(@Param('id') id: string, @Body() dto: DriverActionDto) {
    return this.tripsService.complete(id, dto.driverId);
  }

  /** Cancel trip. */
  @Patch(':id/cancel')
  async cancel(
    @Param('id') id: string,
    @Body('cancelledBy') cancelledBy: string,
  ) {
    return this.tripsService.cancel(id, cancelledBy);
  }

  /** Passenger rates a completed trip. */
  @Patch(':id/rate')
  async rate(@Param('id') id: string, @Body() dto: RateTripDto) {
    return this.tripsService.rate(id, dto.passengerId || '', dto);
  }

  /** Driver: list pending trips I can accept. */
  @Get('driver/:driverId/pending')
  async findPending(
    @Param('driverId') driverId: string,
    @Query('serviceType') serviceType = 'car',
  ) {
    return this.tripsService.findPending(serviceType, driverId);
  }

  /** Passenger: my trip history. */
  @Get('passenger/:passengerId')
  async findByPassenger(@Param('passengerId') passengerId: string) {
    return this.tripsService.findByPassenger(passengerId);
  }

  /** Driver: my trip history. */
  @Get('driver/:driverId/history')
  async findByDriver(@Param('driverId') driverId: string) {
    return this.tripsService.findByDriver(driverId);
  }

  /** Admin: list all trips. */
  @Get()
  @Roles('admin')
  @UseGuards(RolesGuard)
  async findAll(
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.tripsService.findAll({ status, limit, offset });
  }
}
