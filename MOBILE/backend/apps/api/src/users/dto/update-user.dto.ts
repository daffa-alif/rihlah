import { IsString, IsOptional, IsIn } from 'class-validator';

export class UpdateUserDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsIn(['active', 'suspended'])
  @IsOptional()
  accountStatus?: string;

  // Driver KYC fields
  @IsString()
  @IsOptional()
  vehicleType?: string;

  @IsString()
  @IsOptional()
  plate?: string;

  @IsString()
  @IsOptional()
  ktpNumber?: string;

  @IsString()
  @IsIn(['active', 'expired', 'not_registered'])
  @IsOptional()
  bpjsKt?: string;

  @IsString()
  @IsIn(['active', 'expired', 'not_registered'])
  @IsOptional()
  bpjsKs?: string;

  @IsString()
  @IsIn(['active', 'expired', 'not_registered'])
  @IsOptional()
  bpjsInsurance?: string;
}
