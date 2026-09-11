// lib/core/utils/fare_calculator.dart
//
// Formula tarif terpusat — dipakai oleh:
//   - Passenger: confirm_screen (tampil sebelum booking)
//   - Driver: trip_complete_screen (breakdown setelah trip)
//   - Keduanya untuk perbandingan kompetitor
//
// Versi formula harus selalu sinkron antara passenger dan driver.

import '../providers/trip_booking_provider.dart';

/// Hasil kalkulasi tarif lengkap
class FareResult {
  const FareResult({
    required this.baseFare,
    required this.surgeMultiplier,
    required this.totalFare,
    required this.platformFee,
    required this.driverEarns,
    required this.gojekEstimate,
    required this.indriveEstimate,
    required this.durationMin,
  });

  final int    baseFare;
  final double surgeMultiplier;
  final int    totalFare;
  final int    platformFee;
  final int    driverEarns;
  final int    gojekEstimate;
  final int    indriveEstimate;
  final int    durationMin;

  bool get hasSurge => surgeMultiplier > 1.0;
}

class FareCalculator {
  FareCalculator._();

  // ── RIHLAH tarif ──────────────────────────────────────────────────────────

  /// Tarif dasar per km (Rp)
  static const _rihlahCarPerKm   = 3000;
  static const _rihlahBikePerKm  = 2000;
  static const _rihlahSendPerKm  = 2500;

  /// Tarif dasar per menit (Rp)
  static const _rihlahCarPerMin  = 300;
  static const _rihlahBikePerMin = 200;
  static const _rihlahSendPerMin = 250;

  /// Biaya dasar minimum (Rp)
  static const _rihlahCarBase    = 5000;
  static const _rihlahBikeBase   = 3000;
  static const _rihlahSendBase   = 4000;

  /// Platform fee
  static const _platformFeeRate  = 0.05; // 5% — driver earns 95%

  // ── Kompetitor estimasi ───────────────────────────────────────────────────

  // Gojek GoCar/GoRide (estimasi berdasarkan tarif publik Bandung)
  static const _gojekCarPerKm    = 4000;
  static const _gojekCarPerMin   = 450;
  static const _gojekCarBase     = 9000;
  static const _gojekBikePerKm   = 2500;
  static const _gojekBikePerMin  = 300;
  static const _gojekBikeBase    = 6000;

  // InDrive (negosiasi — estimasi awal ~10% lebih murah dari Gojek)
  static const _indriveDiscount  = 0.10;

  // ── Service limits ────────────────────────────────────────────────────────

  static const _maxKmCar  = 50.0;
  static const _maxKmBike = 25.0;
  static const _maxKmSend = 30.0;

  static double maxKmForService(RihlahService service) => switch (service) {
    RihlahService.car  => _maxKmCar,
    RihlahService.bike => _maxKmBike,
    RihlahService.send => _maxKmSend,
  };

  static bool isWithinLimit(RihlahService service, double km) =>
      km <= maxKmForService(service);

  /// Estimasi durasi (menit) dari jarak — dipakai sebelum trip dimulai.
  /// Asumsi kecepatan rata-rata kota Bandung ~25 km/h.
  static int estimateDuration(double distanceKm) =>
      (distanceKm / 25 * 60).ceil().clamp(1, 999);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Hitung tarif lengkap berdasarkan jarak, durasi, dan jenis layanan.
  ///
  /// [distanceKm]   — jarak rute dalam kilometer
  /// [durationMin]  — estimasi durasi dalam menit
  /// [service]      — jenis layanan (car/bike/send)
  /// [surge]        — surge multiplier (default 1.0 = normal)
  static FareResult calculate({
    required double        distanceKm,
    int?                   durationMin, // null → estimasi otomatis dari jarak
    required RihlahService service,
    double                 surge = 1.0,
  }) {
    final mins = durationMin ?? estimateDuration(distanceKm);
    final (perKm, perMin, base) = switch (service) {
      RihlahService.car  => (_rihlahCarPerKm,  _rihlahCarPerMin,  _rihlahCarBase),
      RihlahService.bike => (_rihlahBikePerKm, _rihlahBikePerMin, _rihlahBikeBase),
      RihlahService.send => (_rihlahSendPerKm, _rihlahSendPerMin, _rihlahSendBase),
    };

    final baseFare = (base +
        (distanceKm * perKm).round() +
        (mins * perMin)).round();

    final total   = _roundTo100((baseFare * surge).round());
    final fee     = (total * _platformFeeRate).round();
    final driver  = total - fee;

    final gojekBase = service == RihlahService.bike
        ? _gojekBikeBase : _gojekCarBase;
    final gojekKm   = service == RihlahService.bike
        ? _gojekBikePerKm : _gojekCarPerKm;
    final gojekMin  = service == RihlahService.bike
        ? _gojekBikePerMin : _gojekCarPerMin;
    final gojek     = _roundTo100(
        gojekBase +
        (distanceKm * gojekKm).round() +
        (mins * gojekMin));

    final indrive = _roundTo100(
        (gojek * (1 - _indriveDiscount)).round());

    return FareResult(
      baseFare        : baseFare,
      surgeMultiplier : surge,
      totalFare       : total,
      platformFee     : fee,
      driverEarns     : driver,
      gojekEstimate   : gojek,
      indriveEstimate : indrive,
      durationMin     : mins,
    );
  }

  /// Parse service string dari Hive/MockOrder ke enum.
  static RihlahService parseService(String s) => switch (s.toLowerCase()) {
    'bike' => RihlahService.bike,
    'send' => RihlahService.send,
    _      => RihlahService.car,
  };

  /// Cancellation fee in IDR.
  /// Free if cancelled within 2 minutes of booking.
  /// Rp 5,000 for bike, Rp 10,000 for car/send otherwise.
  static int cancellationFee({
    required DateTime bookedAt,
    required DateTime cancelledAt,
    required String serviceType,
  }) {
    final diffMinutes = cancelledAt.difference(bookedAt).inMinutes;
    if (diffMinutes <= 2) return 0;
    return serviceType == 'bike' ? 5000 : 10000;
  }

  /// Default surge multiplier when DevMenu surge is enabled.
  static const double defaultSurgeMultiplier = 1.4;

  /// Determine surge multiplier from DevMenu toggle and Remote Config gate.
  /// Returns 1.0 (no surge) if either gate disables it.
  static double surgeMultiplier({
    required bool devSurgeEnabled,
    required bool remoteConfigEnabled,
  }) {
    if (!remoteConfigEnabled || !devSurgeEnabled) return 1.0;
    return defaultSurgeMultiplier;
  }

  /// Format Rp dengan titik ribuan.
  static String fmtIdr(int v) {
    if (v == 0) return 'Rp 0';
    final s      = v.toString();
    final buf    = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static int _roundTo100(int v) => ((v / 100).round() * 100);
}