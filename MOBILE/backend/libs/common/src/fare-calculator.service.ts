import { Injectable } from '@nestjs/common';
import { PrismaService } from '@rihlah/database';

export interface FareResult {
  baseFareIdr: number;
  surgeMultiplier: number;
  totalFareIdr: number;
  platformFeeIdr: number;
  driverEarnsIdr: number;
  gojekEstimateIdr: number;
  indriveEstimateIdr: number;
  durationMin: number;
}

export type RihlahService = 'car' | 'bike' | 'send';

/**
 * Server-side fare calculator — must produce IDENTICAL results to the Flutter
 * FareCalculator in lib/core/utils/fare_calculator.dart.
 *
 * The active formula is loaded from the `fare_formulas` DB table, falling back
 * to hardcoded defaults if no formula exists yet.
 */
@Injectable()
export class FareCalculatorService {
  // Hardcoded defaults match the Flutter FareCalculator constants exactly.
  private static readonly DEFAULTS = {
    car: { base: 5000, perKm: 3000, perMin: 300, maxKm: 50 },
    bike: { base: 3000, perKm: 2000, perMin: 200, maxKm: 25 },
    send: { base: 4000, perKm: 2500, perMin: 250, maxKm: 30 },
  };

  // Competitor estimates (Gojek public Bandung rates)
  private static readonly GOJEK_CAR = { base: 9000, perKm: 4000, perMin: 450 };
  private static readonly GOJEK_BIKE = { base: 6000, perKm: 2500, perMin: 300 };
  private static readonly INDRIVE_DISCOUNT = 0.1; // 10% cheaper than Gojek

  private static readonly PLATFORM_FEE_RATE = 0.05;

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Calculate fare with the active formula from the database.
   * Falls back to hardcoded defaults if no formula has been seeded.
   */
  async calculate(params: {
    distanceKm: number;
    durationMin?: number;
    service: RihlahService;
    surge?: number;
  }): Promise<FareResult> {
    const { distanceKm, service, surge = 1.0 } = params;
    const durationMin =
      params.durationMin ?? this.estimateDuration(distanceKm);

    // Try to load active formula from DB
    let formula = await this.prisma.fareFormula.findFirst({
      where: { validTo: null },
      orderBy: { version: 'desc' },
    });

    const svc = FareCalculatorService.DEFAULTS[service];

    const base = formula ? this.formulaBase(formula, service) : svc.base;
    const perKm = formula ? this.formulaPerKm(formula, service) : svc.perKm;
    const perMin = formula ? this.formulaPerMin(formula, service) : svc.perMin;

    const baseFareIdr = Math.round(
      base + distanceKm * perKm + durationMin * perMin,
    );

    const totalFareIdr = this.roundTo100(
      Math.round(baseFareIdr * surge),
    );
    const platformFeeIdr = Math.round(totalFareIdr * FareCalculatorService.PLATFORM_FEE_RATE);
    const driverEarnsIdr = totalFareIdr - platformFeeIdr;

    // Competitor estimates
    const gojekEstimateIdr = this.calculateGojek(service, distanceKm, durationMin);
    const indriveEstimateIdr = this.roundTo100(
      Math.round(gojekEstimateIdr * (1 - FareCalculatorService.INDRIVE_DISCOUNT)),
    );

    return {
      baseFareIdr,
      surgeMultiplier: surge,
      totalFareIdr,
      platformFeeIdr,
      driverEarnsIdr,
      gojekEstimateIdr,
      indriveEstimateIdr,
      durationMin,
    };
  }

  /** Compute fare synchronously with hardcoded defaults (for seeding / offline). */
  static calculateSync(params: {
    distanceKm: number;
    durationMin?: number;
    service: RihlahService;
    surge?: number;
  }): FareResult {
    const { distanceKm, service, surge = 1.0 } = params;
    const durationMin =
      params.durationMin ?? this.estimateDurationStatic(distanceKm);
    const svc = FareCalculatorService.DEFAULTS[service];

    const baseFareIdr = Math.round(
      svc.base + distanceKm * svc.perKm + durationMin * svc.perMin,
    );
    const totalFareIdr = FareCalculatorService.roundTo100Static(
      Math.round(baseFareIdr * surge),
    );
    const platformFeeIdr = Math.round(
      totalFareIdr * FareCalculatorService.PLATFORM_FEE_RATE,
    );
    const driverEarnsIdr = totalFareIdr - platformFeeIdr;

    const gojekEstimateIdr =
      service === 'bike'
        ? Math.round(
            FareCalculatorService.GOJEK_BIKE.base +
              distanceKm * FareCalculatorService.GOJEK_BIKE.perKm +
              durationMin * FareCalculatorService.GOJEK_BIKE.perMin,
          )
        : Math.round(
            FareCalculatorService.GOJEK_CAR.base +
              distanceKm * FareCalculatorService.GOJEK_CAR.perKm +
              durationMin * FareCalculatorService.GOJEK_CAR.perMin,
          );
    const indriveEstimateIdr = FareCalculatorService.roundTo100Static(
      Math.round(gojekEstimateIdr * (1 - FareCalculatorService.INDRIVE_DISCOUNT)),
    );

    return {
      baseFareIdr,
      surgeMultiplier: surge,
      totalFareIdr,
      platformFeeIdr,
      driverEarnsIdr,
      gojekEstimateIdr,
      indriveEstimateIdr,
      durationMin,
    };
  }

  maxKmForService(service: RihlahService): number {
    return FareCalculatorService.DEFAULTS[service].maxKm;
  }

  isWithinLimit(service: RihlahService, km: number): boolean {
    return km <= this.maxKmForService(service);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  private estimateDuration(distanceKm: number): number {
    return Math.max(1, Math.ceil((distanceKm / 25) * 60));
  }

  private static estimateDurationStatic(distanceKm: number): number {
    return Math.max(1, Math.ceil((distanceKm / 25) * 60));
  }

  private roundTo100(v: number): number {
    return Math.round(v / 100) * 100;
  }

  private static roundTo100Static(v: number): number {
    return Math.round(v / 100) * 100;
  }

  private formulaBase(f: any, service: RihlahService): number {
    return service === 'car' ? f.baseCar : service === 'bike' ? f.baseBike : f.baseSend;
  }

  private formulaPerKm(f: any, service: RihlahService): number {
    return service === 'car' ? f.perKmCar : service === 'bike' ? f.perKmBike : f.perKmSend;
  }

  private formulaPerMin(f: any, service: RihlahService): number {
    return service === 'car' ? f.perMinCar : service === 'bike' ? f.perMinBike : f.perMinSend;
  }

  private calculateGojek(
    service: RihlahService,
    km: number,
    mins: number,
  ): number {
    const g =
      service === 'bike'
        ? FareCalculatorService.GOJEK_BIKE
        : FareCalculatorService.GOJEK_CAR;
    return this.roundTo100(Math.round(g.base + km * g.perKm + mins * g.perMin));
  }
}
