import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteStep {
  const RouteStep({
    required this.distance,
    required this.instruction,
  });
  final String distance;    // e.g. "200 m" or "1.2 km"
  final String instruction; // e.g. "Belok kanan ke Jl. Juanda"
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    this.steps = const [],
  });
  final List<LatLng>   points;
  final double         distanceKm;
  final int            durationMin;
  final List<RouteStep> steps;

  static const empty = RouteResult(
    points      : [],
    distanceKm  : 0,
    durationMin : 0,
    steps       : [],
  );
}

class RoutingService {
  RoutingService._();
  static final instance = RoutingService._();

  static const _baseUrl = 'https://router.project-osrm.org/route/v1';

  /// Map Rihlah service type to OSRM profile.
  static String _osrmProfile(String? serviceType) => switch (serviceType?.toLowerCase()) {
    'bike' => 'cycling',
    _      => 'driving',  // car, send, default
  };

  /// Map Rihlah service type to Google Maps travel mode.
  static String _mapsMode(String? serviceType) => switch (serviceType?.toLowerCase()) {
    'bike' => 'bicycling',
    _      => 'driving',
  };

  Future<RouteResult> getRoute(LatLng from, LatLng to, {String? serviceType}) async {
    final profile = _osrmProfile(serviceType);
    final base = '$_baseUrl/$profile';
    try {
      // Hapus language=id — bukan parameter valid OSRM
      final url = '$base/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=polyline6&steps=true'
          '&annotations=false';

      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'rihlah-app/2.0'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('=== OSRM error: ${res.statusCode} ${res.body}');
        return RouteResult.empty;
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        debugPrint('=== OSRM code: ${data['code']} ${data['message']}');
        return RouteResult.empty;
      }

      final route    = (data['routes'] as List).first as Map<String, dynamic>;
      final distance = (route['distance'] as num).toDouble() / 1000;
      final duration = ((route['duration'] as num).toDouble() / 60).ceil();
      final geometry = route['geometry'] as String;
      final points   = _decodePoly6(geometry);

      debugPrint('=== OSRM OK: ${points.length} pts, '
          '${distance.toStringAsFixed(1)} km, $duration min');

      // Parse steps
      final steps = <RouteStep>[];
      final legs  = route['legs'] as List? ?? [];
      for (final leg in legs) {
        final legSteps = (leg as Map)['steps'] as List? ?? [];
        for (final step in legSteps) {
          final s        = step as Map<String, dynamic>;
          final dist     = (s['distance'] as num).toDouble();
          final maneuver = s['maneuver'] as Map<String, dynamic>?;
          final name     = s['name'] as String? ?? '';
          final type     = maneuver?['type']     as String? ?? '';
          final modifier = maneuver?['modifier'] as String? ?? '';

          if (dist < 10) continue;

          final distStr = dist >= 1000
              ? '${(dist / 1000).toStringAsFixed(1)} km'
              : '${dist.round()} m';

          steps.add(RouteStep(
            distance   : distStr,
            instruction: _buildInstruction(type, modifier, name),
          ));
        }
      }

      return RouteResult(
        points     : points,
        distanceKm : double.parse(distance.toStringAsFixed(1)),
        durationMin: duration,
        steps      : steps,
      );
    } catch (e) {
      debugPrint('=== OSRM exception: $e');
      return RouteResult.empty;
    }
  }

  /// Build human-readable instruction in Indonesian.
  String _buildInstruction(String type, String modifier, String name) {
    final street = name.isNotEmpty ? ' ke $name' : '';
    return switch (type) {
      'turn' => switch (modifier) {
        'left'        => 'Belok kiri$street',
        'right'       => 'Belok kanan$street',
        'slight left' => 'Sedikit belok kiri$street',
        'slight right'=> 'Sedikit belok kanan$street',
        'sharp left'  => 'Belok tajam kiri$street',
        'sharp right' => 'Belok tajam kanan$street',
        'uturn'       => 'Putar balik$street',
        _             => 'Lurus$street',
      },
      'depart'       => 'Mulai perjalanan$street',
      'arrive'       => 'Sudah sampai di tujuan',
      'merge'        => 'Gabung$street',
      'ramp'         => 'Ambil jalur$street',
      'fork'         => switch (modifier) {
        'left'  => 'Ambil percabangan kiri$street',
        'right' => 'Ambil percabangan kanan$street',
        _       => 'Lurus di percabangan$street',
      },
      'end of road'  => switch (modifier) {
        'left'  => 'Di ujung jalan, belok kiri$street',
        'right' => 'Di ujung jalan, belok kanan$street',
        _       => 'Di ujung jalan$street',
      },
      'continue'     => 'Lanjut lurus$street',
      'roundabout'   => 'Masuk bundaran$street',
      _              => name.isNotEmpty ? 'Lanjut ke $name' : 'Lanjut',
    };
  }

  List<LatLng> _decodePoly6(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1);
      lat += dlat;

      shift = 0; result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1);
      lng += dlng;

      result.add(LatLng(lat / 1e6, lng / 1e6));
    }
    return result;
  }

  // ── Google Maps fallback ──────────────────────────────────────────────────

  /// Buka Google Maps dengan navigasi dari [from] ke [to].
  /// Dipanggil saat OSRM gagal atau hasil rute tidak valid.
  Future<bool> openGoogleMapsNavigation(LatLng from, LatLng to, {String? serviceType}) async {
    final mode = _mapsMode(serviceType);
    final nativeMode = mode == 'bicycling' ? 'b' : 'd';
    // Format: navigasi dari koordinat ke koordinat
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${from.latitude},${from.longitude}'
      '&destination=${to.latitude},${to.longitude}'
      '&travelmode=$mode',
    );

    try {
      // Coba buka Google Maps native app dulu
      final nativeUri = Uri.parse(
        'google.navigation:q=${to.latitude},${to.longitude}'
        '&mode=$nativeMode',
      );

      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
        debugPrint('=== Opened Google Maps native app');
        return true;
      }

      // Fallback ke browser jika app tidak tersedia
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('=== Opened Google Maps in browser');
        return true;
      }

      debugPrint('=== Cannot launch Google Maps');
      return false;
    } catch (e) {
      debugPrint('=== Google Maps launch error: $e');
      return false;
    }
  }

  /// Coba getRoute, jika gagal/kosong kembalikan empty dan log event.
  /// Caller bisa cek `result == RouteResult.empty` lalu panggil
  /// [openGoogleMapsNavigation] sebagai fallback.
  Future<RouteResult> getRouteWithFallback(
    LatLng from,
    LatLng to, {
    String? serviceType,
    VoidCallback? onFallback,
  }) async {
    final result = await getRoute(from, to, serviceType: serviceType);

    if (result.points.length < 2) {
      debugPrint('=== OSRM failed — caller should open Google Maps');
      onFallback?.call();
    }

    return result;
  }
}