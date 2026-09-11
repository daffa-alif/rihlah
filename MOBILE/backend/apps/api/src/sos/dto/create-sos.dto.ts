import { IsString, IsNumber, IsOptional, IsIn, Min, Max } from 'class-validator';

export class CreateSosDto {
  @IsString()
  @IsOptional()
  tripId?: string;

  @IsString()
  byUserId: string;

  @IsString()
  @IsIn(['passenger', 'driver'])
  byUserRole: string;

  @IsString()
  @IsOptional()
  byUserName?: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng: number;

  // Emergency contacts to notify
  @IsString({ each: true })
  @IsOptional()
  contacts?: string[];
}
