import { IsString, IsNumber, IsOptional, IsIn, Min } from 'class-validator';

export class CreatePaymentDto {
  @IsString()
  tripId: string;

  @IsString()
  @IsIn(['cash', 'qris', 'gopay', 'ovo', 'dana', 'shopeepay'])
  method: string;

  @IsNumber()
  @Min(0)
  amountIdr: number;

  @IsString()
  @IsOptional()
  customerName?: string;

  @IsString()
  @IsOptional()
  customerPhone?: string;
}
