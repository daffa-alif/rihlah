import {
  IsString,
  IsNumber,
  IsOptional,
  IsIn,
  Min,
  Max,
} from 'class-validator';

export class CreateTripDto {
  @IsString()
  passengerId: string;

  @IsString()
  @IsIn(['car', 'bike', 'send'])
  serviceType: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  pickupLat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  pickupLng: number;

  @IsString()
  pickupAddress: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  dropoffLat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  dropoffLng: number;

  @IsString()
  dropoffAddress: string;

  @IsNumber()
  @Min(0)
  distanceM: number;

  @IsNumber()
  @Min(0)
  durationS: number;

  @IsString()
  @IsIn(['cash', 'qris', 'gopay', 'ovo', 'dana', 'shopeepay'])
  @IsOptional()
  paymentMethod?: string;

  @IsString()
  @IsOptional()
  appliedVoucherCode?: string;

  @IsNumber()
  @IsOptional()
  appliedDiscountIdr?: number;
}

export class UpdateTripStatusDto {
  @IsString()
  @IsIn([
    'accepted',
    'arriving',
    'arrived',
    'inTrip',
    'completed',
    'cancelled',
  ])
  status: string;
}

export class RateTripDto {
  @IsNumber()
  @Min(1)
  @Max(5)
  stars: number;

  @IsString({ each: true })
  @IsOptional()
  tags?: string[];

  @IsString()
  @IsOptional()
  comment?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  tip?: number;
}

export class DriverActionDto {
  @IsString()
  driverId: string;
}
