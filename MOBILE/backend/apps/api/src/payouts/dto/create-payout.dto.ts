import { IsString, IsNumber, IsOptional, Min } from 'class-validator';

export class CreatePayoutDto {
  @IsString()
  driverId: string;

  @IsNumber()
  @Min(20000) // Minimum withdrawal Rp 20.000
  amountIdr: number;

  @IsString()
  destination: string; // masked bank account or e-wallet identifier

  @IsString()
  @IsOptional()
  bankCode?: string; // bca, bni, mandiri, etc.

  @IsString()
  accountHolderName?: string;
}
