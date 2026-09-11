import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';

class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.address,
    required this.latLng,
  });
  final String  name;
  final String  address;
  final LatLng  latLng;

  @override
  String toString() => name;
}

class GeocodingService {
  GeocodingService._();
  static final instance = GeocodingService._();

  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'RihlahApp/1.0 (contact@rihlah.id)',
    'Accept': 'application/json',
    'Accept-Language': 'id,en',
    'Referer': 'https://rihlah.id',
  };

  /// Cari tempat berdasarkan teks query.
  /// Dibatasi di area Indonesia (countrycodes=id).
  Future<List<PlaceResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'q' : query,
          // Parameter 'viewbox' dan 'bounded' telah DIHAPUS
          // agar area pencarian tidak lagi dikurung di Bandung.
          'countrycodes' : 'id', // Tetap dibatasi untuk negara Indonesia
          'format'       : 'json',
          'limit'        : '10',
          'addressdetails': '1',
        },
      );
      debugPrint('=== Nominatim URL: $uri');
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      debugPrint('=== Status: ${res.statusCode}');
      debugPrint('=== Body: ${res.body.substring(0, min(200, res.body.length))}');
      if (res.statusCode != 200) return [];

      final List data = json.decode(res.body) as List;
      return data.map((item) {
        final addr  = item['address'] as Map<String, dynamic>? ?? {};
        final name  = _extractName(item, addr);
        final detail = _extractDetail(addr);
        return PlaceResult(
          name   : name,
          address: detail,
          latLng : LatLng(
            double.parse(item['lat'].toString()),
            double.parse(item['lon'].toString()),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocode: koordinat → nama alamat.
  Future<String> reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse('$_baseUrl/reverse').replace(
        queryParameters: {
          'lat'    : pos.latitude.toString(),
          'lon'    : pos.longitude.toString(),
          'format' : 'json',
          'zoom'   : '16',
        },
      );
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return 'Lokasi saat ini';

      final data = json.decode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      return _extractName(data, addr);
    } catch (_) {
      return 'Lokasi saat ini';
    }
  }

  String _extractName(Map<String, dynamic> item,
      Map<String, dynamic> addr) {
    return addr['amenity']       ??
        addr['building']      ??
        addr['road']          ??
        addr['neighbourhood'] ??
        addr['suburb']        ??
        addr['city_district'] ??
        item['display_name']?.toString().split(',').first ??
        'Lokasi';
  }

  String _extractDetail(Map<String, dynamic> addr) {
    final parts = <String>[];
    if (addr['road']          != null) parts.add(addr['road']);
    if (addr['suburb']        != null) parts.add(addr['suburb']);
    if (addr['city_district'] != null) parts.add(addr['city_district']);
    return parts.take(2).join(', ');
  }
}