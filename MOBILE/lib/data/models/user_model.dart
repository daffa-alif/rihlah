import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.phone,
    required this.name,
    required this.role,
    this.photoUrl,
    this.createdAt,
    this.vehicleType,
    this.plate,
    this.ktpNumberMasked,
    this.bpjsKt = 'not_registered',
    this.bpjsKs = 'not_registered',
    this.bpjsInsurance = 'not_registered',
    this.ratingAvg,
    this.balanceIdr,
    this.totalTrips = 0,
    this.accountStatus = 'active',
  });

  final String uid;
  final String phone;
  final String name;
  final String role; // 'passenger' | 'driver' | 'admin' | ''
  final String? photoUrl;
  final Timestamp? createdAt;

  // ── Driver-only profile fields (admin console + driver docs screen) ──────
  final String? vehicleType; // 'car' | 'bike'
  final String? plate;
  final String? ktpNumberMasked;
  final String bpjsKt; // 'active' | 'expired' | 'not_registered'
  final String bpjsKs; // 'active' | 'expired' | 'not_registered'
  final String bpjsInsurance; // Perpres 27/2026 accident insurance
  final double? ratingAvg;
  final int? balanceIdr;
  final int totalTrips;
  final String accountStatus; // 'active' | 'suspended'

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phone: _str(d['phone']) ?? '',
      name: _str(d['name']) ?? 'Pengguna RIHLAH',
      role: _str(d['role']) ?? '',
      photoUrl: _str(d['photoUrl']),
      createdAt: _ts(d['createdAt']),
      vehicleType: _str(d['vehicleType']),
      plate: _str(d['plate']),
      ktpNumberMasked: _str(d['ktpNumberMasked']),
      bpjsKt: _str(d['bpjsKt']) ?? 'not_registered',
      bpjsKs: _str(d['bpjsKs']) ?? 'not_registered',
      bpjsInsurance: _str(d['bpjsInsurance']) ?? 'not_registered',
      ratingAvg: _num(d['ratingAvg'])?.toDouble(),
      balanceIdr: _num(d['balanceIdr'])?.toInt(),
      totalTrips: _num(d['totalTrips'])?.toInt() ?? 0,
      accountStatus: _str(d['accountStatus']) ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'phone': phone,
        'name': name,
        'role': role,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        if (vehicleType != null) 'vehicleType': vehicleType,
        if (plate != null) 'plate': plate,
        if (ktpNumberMasked != null) 'ktpNumberMasked': ktpNumberMasked,
        'bpjsKt': bpjsKt,
        'bpjsKs': bpjsKs,
        'bpjsInsurance': bpjsInsurance,
        if (ratingAvg != null) 'ratingAvg': ratingAvg,
        if (balanceIdr != null) 'balanceIdr': balanceIdr,
        if (totalTrips != 0) 'totalTrips': totalTrips,
        'accountStatus': accountStatus,
      };

  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';
  bool get isAdmin => role == 'admin';
  bool get hasRole => role.isNotEmpty;
  bool get isSuspended => accountStatus == 'suspended';
}
