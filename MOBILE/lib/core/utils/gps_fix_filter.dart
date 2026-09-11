import 'package:latlong2/latlong.dart';

/// An accepted GPS fix plus the bearing travelled since the previous one.
class AcceptedFix {
  const AcceptedFix(this.pos, this.bearingDeg);

  final LatLng pos;

  /// Bearing of travel in degrees (0 = north, clockwise), or null until two
  /// distinct fixes have been accepted.
  final double? bearingDeg;
}

/// Filters a stream of raw GPS fixes so downstream consumers (RTDB writes,
/// map markers) never see jumps from noisy or implausible readings.
///
/// Rejection rules:
///  1. Accuracy gate — fixes with reported accuracy worse than
///     [maxAccuracyM] are dropped outright.
///  2. Speed gate — a fix implying travel faster than [maxSpeedMps] from the
///     last accepted fix is treated as an outlier and dropped.
///
/// A genuinely relocated device (GPS regained after a tunnel, app resumed
/// after backgrounding) would fail the speed gate forever, so after
/// [maxConsecutiveRejects] rejected fixes in a row the next fix is accepted
/// unconditionally and the filter re-anchors there.
class GpsFixFilter {
  GpsFixFilter({
    this.maxAccuracyM = 50,
    this.maxSpeedMps = 35, // ~126 km/h, generous for urban Bandung
    this.maxConsecutiveRejects = 3,
  });

  final double maxAccuracyM;
  final double maxSpeedMps;
  final int maxConsecutiveRejects;

  static const _distance = Distance();

  LatLng? _lastAccepted;
  DateTime? _lastAcceptedAt;
  double? _lastBearing;
  int _rejectStreak = 0;

  /// Returns the accepted fix (with travel bearing), or null to discard.
  AcceptedFix? filter(LatLng pos, {double? accuracyM, DateTime? at}) {
    final now = at ?? DateTime.now();

    if (accuracyM != null && accuracyM > maxAccuracyM) {
      // Poor-accuracy fixes don't count toward the reject streak — they are
      // known-bad rather than "surprisingly far", so they never force a
      // re-anchor onto a noisy position.
      return null;
    }

    final last = _lastAccepted;
    final lastAt = _lastAcceptedAt;
    if (last != null && lastAt != null) {
      final meters = _distance.as(LengthUnit.Meter, last, pos);
      final seconds =
          now.difference(lastAt).inMilliseconds.clamp(1, 1 << 31) / 1000.0;
      if (meters / seconds > maxSpeedMps) {
        _rejectStreak++;
        if (_rejectStreak <= maxConsecutiveRejects) return null;
        // Too many rejects in a row — trust the new position, re-anchor, and
        // drop the stale bearing since the old heading no longer applies.
        _lastBearing = null;
      } else if (meters >= 2) {
        // Only update bearing on meaningful movement; sub-2m jitter while
        // stationary would make the marker spin.
        final b = _distance.bearing(last, pos);
        _lastBearing = b < 0 ? b + 360 : b;
      }
    }

    _rejectStreak = 0;
    _lastAccepted = pos;
    _lastAcceptedAt = now;
    return AcceptedFix(pos, _lastBearing);
  }

  void reset() {
    _lastAccepted = null;
    _lastAcceptedAt = null;
    _lastBearing = null;
    _rejectStreak = 0;
  }
}
