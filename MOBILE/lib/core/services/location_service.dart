import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  // Titik cadangan diubah ke area Ciomas (bukan lagi Bandung)
  static const _defaultFallback = LatLng(-6.6023, 106.7628);

  /// Minta izin dan ambil posisi saat ini.
  /// Mengembalikan fallback jika gagal.
  Future<LatLng> getCurrentPosition() async {
    try {
      final permission = await _ensurePermission();
      if (!permission) return _defaultFallback;

      final pos = await Geolocator.getCurrentPosition(
        // Batas waktu (timeLimit) DIHAPUS agar GPS memiliki
        // waktu yang cukup untuk mengunci posisi akuratmu di luar kota.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Jika error, coba ambil lokasi terakhir yang terekam di HP
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LatLng(last.latitude, last.longitude);
      } catch (_) {}
      return _defaultFallback;
    }
  }

  /// Stream posisi untuk tracking realtime.
  Stream<LatLng> positionStream() =>
      rawPositionStream().map((p) => LatLng(p.latitude, p.longitude));

  /// Stream posisi mentah dengan accuracy/heading/speed — untuk konsumen
  /// yang perlu memfilter fix buruk (lihat GpsFixFilter).
  Stream<Position> rawPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // meter
      ),
    );
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Hitung jarak lurus antara dua titik (km).
  static double straightDistance(LatLng a, LatLng b) {
    const dist = Distance();
    return dist.as(LengthUnit.Kilometer, a, b);
  }
}