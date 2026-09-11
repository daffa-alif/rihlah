import { IsString, IsOptional, IsIn, IsPhoneNumber } from 'class-validator';

export class CreateUserDto {
  @IsString()
  firebaseUid: string;

  @IsString()
  @IsPhoneNumber('ID')
  phone: string;

  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsIn(['passenger', 'driver', 'admin'])
  @IsOptional()
  role?: string;
}
