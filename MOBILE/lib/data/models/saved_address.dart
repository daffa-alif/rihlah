// lib/data/models/saved_address.dart

import 'package:latlong2/latlong.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String label;    // 'Rumah', 'Kantor', atau custom
  final String name;     // nama tempat
  final String address;  // detail alamat
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  // ── Serialization ─────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id'       : id,
    'label'    : label,
    'name'     : name,
    'address'  : address,
    'latitude' : latitude,
    'longitude': longitude,
  };

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;

  factory SavedAddress.fromMap(Map map) => SavedAddress(
    id        : _str(map['id']) ?? '',
    label     : _str(map['label']) ?? '',
    name      : _str(map['name']) ?? '',
    address   : _str(map['address']) ?? '',
    latitude  : _num(map['latitude'])?.toDouble() ?? 0,
    longitude : _num(map['longitude'])?.toDouble() ?? 0,
  );
}