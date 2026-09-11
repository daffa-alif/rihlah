import 'package:cloud_firestore/cloud_firestore.dart';

/// Emergency SOS event (P-S7 / D-S8) — synced to Firestore so the admin
/// ops console has a real, live safety review queue. Audio capture itself
/// stays simulated (P1/P2 scope), so [audioUrl] is always null for now.
class SosEventModel {
  const SosEventModel({
    required this.eventId,
    required this.byUserId,
    required this.lat,
    required this.lng,
    this.tripId,
    this.byUserRole,
    this.byUserName,
    this.audioUrl,
    this.contactsNotified = const [],
    this.status = 'open',
    this.createdAt,
  });

  final String eventId;
  final String? tripId;
  final String byUserId;
  final String? byUserRole; // 'passenger' | 'driver'
  final String? byUserName;
  final double lat;
  final double lng;
  final String? audioUrl;
  final List<String> contactsNotified;
  final String status; // 'open' | 'acknowledged'
  final Timestamp? createdAt;

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;
  static List<String> _strList(dynamic v) {
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }

  factory SosEventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SosEventModel(
      eventId: doc.id,
      tripId: _str(d['tripId']),
      byUserId: _str(d['byUserId']) ?? '',
      byUserRole: _str(d['byUserRole']),
      byUserName: _str(d['byUserName']),
      lat: _num(d['lat'])?.toDouble() ?? 0,
      lng: _num(d['lng'])?.toDouble() ?? 0,
      audioUrl: _str(d['audioUrl']),
      contactsNotified: _strList(d['contactsNotified']),
      status: _str(d['status']) ?? 'open',
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        if (tripId != null) 'tripId': tripId,
        'byUserId': byUserId,
        if (byUserRole != null) 'byUserRole': byUserRole,
        if (byUserName != null) 'byUserName': byUserName,
        'lat': lat,
        'lng': lng,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'contactsNotified': contactsNotified,
        'status': status,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };
}
