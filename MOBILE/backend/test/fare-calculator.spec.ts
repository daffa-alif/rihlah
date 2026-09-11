import { FareCalculatorService } from '../libs/common/src/fare-calculator.service';

/**
 * Unit tests for the server-side FareCalculator.
 *
 * These MUST match the equivalent Flutter tests exactly — any discrepancy
 * means the passenger and driver see different fare numbers.
 */
describe('FareCalculatorService (static)', () => {
  // ── Car fares ────────────────────────────────────────────────────────────

  it('should calculate minimum car fare for a short trip', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 1.0,
      durationMin: 3,
      service: 'car',
    });

    // base=5000 + 1*3000 + 3*300 = 5000+3000+900 = 8900 → round to 8900
    expect(result.baseFareIdr).toBe(8900);
    // platform = 5% of 8900 = 445 → driver = 8900-445 = 8455
    expect(result.platformFeeIdr).toBe(445);
    expect(result.driverEarnsIdr).toBe(8455);
  });

  it('should calculate a medium car trip (5 km, 12 min)', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 5.0,
      durationMin: 12,
      service: 'car',
    });

    // base=5000 + 5*3000 + 12*300 = 5000+15000+3600 = 23600
    expect(result.baseFareIdr).toBe(23600);
    expect(result.totalFareIdr).toBe(23600);
    expect(result.platformFeeIdr).toBe(1180); // 5% of 23600
    expect(result.driverEarnsIdr).toBe(22420);
  });

  it('should calculate a long car trip (20 km, 48 min)', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 20.0,
      durationMin: 48,
      service: 'car',
    });

    // base=5000 + 20*3000 + 48*300 = 5000+60000+14400 = 79400
    expect(result.baseFareIdr).toBe(79400);
    expect(result.platformFeeIdr).toBe(3970);
    expect(result.driverEarnsIdr).toBe(75430);
  });

  // ── Bike fares ───────────────────────────────────────────────────────────

  it('should calculate a short bike trip (2 km, 5 min)', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 2.0,
      durationMin: 5,
      service: 'bike',
    });

    // base=3000 + 2*2000 + 5*200 = 3000+4000+1000 = 8000
    expect(result.baseFareIdr).toBe(8000);
    expect(result.platformFeeIdr).toBe(400);
    expect(result.driverEarnsIdr).toBe(7600);
  });

  // ── Send (courier) fares ─────────────────────────────────────────────────

  it('should calculate a send trip (3 km, 8 min)', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 3.0,
      durationMin: 8,
      service: 'send',
    });

    // base=4000 + 3*2500 + 8*250 = 4000+7500+2000 = 13500
    expect(result.baseFareIdr).toBe(13500);
    expect(result.totalFareIdr).toBe(13500);
    expect(result.platformFeeIdr).toBe(675);
    expect(result.driverEarnsIdr).toBe(12825);
  });

  // ── Rounding ─────────────────────────────────────────────────────────────

  it('should round fares to nearest 100', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 3.7,
      durationMin: 9,
      service: 'car',
    });

    // base=5000 + 3.7*3000 + 9*300 = 5000+11100+2700 = 18800
    // roundTo100(18800) = 18800
    expect(result.totalFareIdr % 100).toBe(0);
  });

  // ── Competitor estimates ─────────────────────────────────────────────────

  it('should calculate Gojek competitor estimate', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 5.0,
      durationMin: 12,
      service: 'car',
    });

    // Gojek car: 9000 + 5*4000 + 12*450 = 9000+20000+5400 = 34400
    // roundTo100(34400) = 34400
    expect(result.gojekEstimateIdr).toBe(34400);
    // InDrive: 34400 * 0.9 = 30960 → roundTo100 = 31000
    expect(result.indriveEstimateIdr).toBe(31000);
  });

  it('should calculate Gojek bike estimate', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 2.0,
      durationMin: 5,
      service: 'bike',
    });

    // Gojek bike: 6000 + 2*2500 + 5*300 = 6000+5000+1500 = 12500
    expect(result.gojekEstimateIdr).toBe(12500);
    // InDrive: 12500 * 0.9 = 11250 → roundTo100 = 11300
    expect(result.indriveEstimateIdr).toBe(11300);
  });

  // ── Service limits ───────────────────────────────────────────────────────

  it('should enforce car distance limit (50 km)', () => {
    const svc = new FareCalculatorService(null as any);
    expect(svc.isWithinLimit('car', 50)).toBe(true);
    expect(svc.isWithinLimit('car', 50.1)).toBe(false);
  });

  it('should enforce bike distance limit (25 km)', () => {
    const svc = new FareCalculatorService(null as any);
    expect(svc.isWithinLimit('bike', 25)).toBe(true);
    expect(svc.isWithinLimit('bike', 25.1)).toBe(false);
  });

  // ── Platform fee split (95/5) ────────────────────────────────────────────

  it('should split fare 95% driver / 5% platform', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 10.0,
      durationMin: 24,
      service: 'car',
    });

    expect(result.totalFareIdr).toBe(
      result.driverEarnsIdr + result.platformFeeIdr,
    );
    // 5% platform cut
    const expectedFee = Math.round(result.totalFareIdr * 0.05);
    expect(result.platformFeeIdr).toBe(expectedFee);
  });

  // ── Default duration estimation ──────────────────────────────────────────

  it('should estimate duration when not provided', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 10.0,
      // no durationMin → estimated as (10/25)*60 = 24 min
      service: 'car',
    });

    expect(result.durationMin).toBe(24);
  });

  // ── No surge in MVP ──────────────────────────────────────────────────────

  it('should have surge multiplier of 1.0 by default', () => {
    const result = FareCalculatorService.calculateSync({
      distanceKm: 5.0,
      service: 'car',
    });

    expect(result.surgeMultiplier).toBe(1.0);
    expect(result.totalFareIdr).toBe(result.baseFareIdr);
  });
});
