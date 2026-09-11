import 'package:flutter_test/flutter_test.dart';
import 'package:rihlah/core/utils/fare_calculator.dart';
import 'package:rihlah/core/providers/trip_booking_provider.dart'; // for RihlahService

/// Flutter-side fare calculator tests.
///
/// THESE MUST MATCH the backend test suite in
/// backend/test/fare-calculator.spec.ts EXACTLY.
/// Any discrepancy means passenger/driver see different fares.
void main() {
  // ── Car fares ────────────────────────────────────────────────────────────

  test('should calculate minimum car fare for a short trip', () {
    final result = FareCalculator.calculate(
      distanceKm: 1.0,
      durationMin: 3,
      service: RihlahService.car,
    );

    expect(result.baseFare, 8900);
    expect(result.platformFee, 445);
    expect(result.driverEarns, 8455);
  });

  test('should calculate a medium car trip (5 km, 12 min)', () {
    final result = FareCalculator.calculate(
      distanceKm: 5.0,
      durationMin: 12,
      service: RihlahService.car,
    );

    expect(result.baseFare, 23600);
    expect(result.totalFare, 23600);
    expect(result.platformFee, 1180);
    expect(result.driverEarns, 22420);
  });

  test('should calculate a long car trip (20 km, 48 min)', () {
    final result = FareCalculator.calculate(
      distanceKm: 20.0,
      durationMin: 48,
      service: RihlahService.car,
    );

    expect(result.baseFare, 79400);
    expect(result.platformFee, 3970);
    expect(result.driverEarns, 75430);
  });

  // ── Bike fares ───────────────────────────────────────────────────────────

  test('should calculate a short bike trip (2 km, 5 min)', () {
    final result = FareCalculator.calculate(
      distanceKm: 2.0,
      durationMin: 5,
      service: RihlahService.bike,
    );

    expect(result.baseFare, 8000);
    expect(result.platformFee, 400);
    expect(result.driverEarns, 7600);
  });

  // ── Send (courier) fares ─────────────────────────────────────────────────

  test('should calculate a send trip (3 km, 8 min)', () {
    final result = FareCalculator.calculate(
      distanceKm: 3.0,
      durationMin: 8,
      service: RihlahService.send,
    );

    expect(result.baseFare, 13500);
    expect(result.totalFare, 13500);
    expect(result.platformFee, 675);
    expect(result.driverEarns, 12825);
  });

  // ── Rounding ─────────────────────────────────────────────────────────────

  test('should round fares to nearest 100', () {
    final result = FareCalculator.calculate(
      distanceKm: 3.7,
      durationMin: 9,
      service: RihlahService.car,
    );

    expect(result.totalFare % 100, 0);
  });

  // ── Competitor estimates ─────────────────────────────────────────────────

  test('should calculate Gojek competitor estimate for car', () {
    final result = FareCalculator.calculate(
      distanceKm: 5.0,
      durationMin: 12,
      service: RihlahService.car,
    );

    expect(result.gojekEstimate, 34400);
    expect(result.indriveEstimate, 31000);
  });

  test('should calculate Gojek competitor estimate for bike', () {
    final result = FareCalculator.calculate(
      distanceKm: 2.0,
      durationMin: 5,
      service: RihlahService.bike,
    );

    expect(result.gojekEstimate, 12500);
    expect(result.indriveEstimate, 11300);
  });

  // ── Service limits ───────────────────────────────────────────────────────

  test('should enforce car distance limit (50 km)', () {
    expect(FareCalculator.isWithinLimit(RihlahService.car, 50), true);
    expect(FareCalculator.isWithinLimit(RihlahService.car, 50.1), false);
  });

  test('should enforce bike distance limit (25 km)', () {
    expect(FareCalculator.isWithinLimit(RihlahService.bike, 25), true);
    expect(FareCalculator.isWithinLimit(RihlahService.bike, 25.1), false);
  });

  // ── Platform fee split (95/5) ────────────────────────────────────────────

  test('should split fare 95% driver / 5% platform', () {
    final result = FareCalculator.calculate(
      distanceKm: 10.0,
      durationMin: 24,
      service: RihlahService.car,
    );

    expect(result.totalFare, result.driverEarns + result.platformFee);
    final expectedFee = (result.totalFare * 0.05).round();
    expect(result.platformFee, expectedFee);
  });

  // ── Duration estimation ──────────────────────────────────────────────────

  test('should estimate duration when not provided', () {
    final result = FareCalculator.calculate(
      distanceKm: 10.0,
      service: RihlahService.car,
    );

    expect(result.durationMin, 24);
  });

  // ── No surge in MVP ──────────────────────────────────────────────────────

  test('should have surge multiplier of 1.0 by default', () {
    final result = FareCalculator.calculate(
      distanceKm: 5.0,
      service: RihlahService.car,
    );

    expect(result.surgeMultiplier, 1.0);
    expect(result.totalFare, result.baseFare);
  });
}
