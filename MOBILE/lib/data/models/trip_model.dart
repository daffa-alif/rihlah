import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus {
  searching,
  accepted,
  arriving,
  arrived,
  inTrip,
  completed,
  cancelled;

  static TripStatus fromString(String s) =>
      TripStatus.values.firstWhere((e) => e.name == s,
          orElse: () => TripStatus.searching);
}

class TripModel {
  const TripModel({
    required this.tripId,
    required this.passengerId,
    required this.serviceType,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.totalFare,
    required this.platformFee,
    required this.driverEarns,
    required this.paymentMethod,
    required this.status,
    this.driverId,
    this.passengerName,
    this.passengerPhone,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.cancellationFee,
    this.surgeMultiplier = 1.0,
    this.passengerRating,
    this.passengerTip,
    this.passengerReview,
    this.appliedDiscount,
    this.appliedVoucherCode,
    this.skippedBy = const [],
  });

  final String tripId;
  final String passengerId;
  final String? driverId;
  final String serviceType; // 'car' | 'bike' | 'send'
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupAddress;
  final String dropoffAddress;
  final double distanceKm;
  final int durationMin;
  final int totalFare;
  final int platformFee;
  final int driverEarns;
  final String paymentMethod;
  final TripStatus status;
  final String? passengerName;
  final String? passengerPhone;
  final Timestamp? createdAt;
  final Timestamp? acceptedAt;
  final Timestamp? completedAt;
  final Timestamp? cancelledAt;
  final String? cancelledBy; // 'passenger' | 'driver'
  final String? cancelReason; // free-text reason
  final int? cancellationFee; // in IDR, 0 = free
  final double surgeMultiplier; // 1.0 = no surge
  final int? passengerRating;
  final int? passengerTip;
  final String? passengerReview;
  final int? appliedDiscount;
  final String? appliedVoucherCode;
  final List<String> skippedBy;

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;
  static List<String> _strList(dynamic v) {
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TripModel(
      tripId: doc.id,
      passengerId: _str(d['passengerId']) ?? '',
      driverId: _str(d['driverId']),
      serviceType: _str(d['serviceType']) ?? 'car',
      pickupLat: _num(d['pickupLat'])?.toDouble() ?? 0,
      pickupLng: _num(d['pickupLng'])?.toDouble() ?? 0,
      dropoffLat: _num(d['dropoffLat'])?.toDouble() ?? 0,
      dropoffLng: _num(d['dropoffLng'])?.toDouble() ?? 0,
      pickupAddress: _str(d['pickupAddress']) ?? '',
      dropoffAddress: _str(d['dropoffAddress']) ?? '',
      distanceKm: _num(d['distanceKm'])?.toDouble() ?? 0,
      durationMin: _num(d['durationMin'])?.toInt() ?? 0,
      totalFare: _num(d['totalFare'])?.toInt() ?? 0,
      platformFee: _num(d['platformFee'])?.toInt() ?? 0,
      driverEarns: _num(d['driverEarns'])?.toInt() ?? 0,
      paymentMethod: _str(d['paymentMethod']) ?? 'cash',
      status: TripStatus.fromString(_str(d['status']) ?? 'searching'),
      passengerName: _str(d['passengerName']),
      passengerPhone: _str(d['passengerPhone']),
      createdAt: _ts(d['createdAt']),
      acceptedAt: _ts(d['acceptedAt']),
      completedAt: _ts(d['completedAt']),
      cancelledAt: _ts(d['cancelledAt']),
      cancelledBy: _str(d['cancelledBy']),
      cancelReason: _str(d['cancelReason']),
      cancellationFee: _num(d['cancellationFee'])?.toInt(),
      surgeMultiplier: _num(d['surgeMultiplier'])?.toDouble() ?? 1.0,
      passengerRating: _num(d['passengerRating'])?.toInt(),
      passengerTip: _num(d['passengerTip'])?.toInt(),
      passengerReview: _str(d['passengerReview']),
      appliedDiscount: _num(d['appliedDiscount'])?.toInt(),
      appliedVoucherCode: _str(d['appliedVoucherCode']),
      skippedBy: _strList(d['skippedBy']),
    );
  }

  Map<String, dynamic> toMap() => {
        'passengerId': passengerId,
        if (driverId != null) 'driverId': driverId,
        'serviceType': serviceType,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'distanceKm': distanceKm,
        'durationMin': durationMin,
        'totalFare': totalFare,
        'platformFee': platformFee,
        'driverEarns': driverEarns,
        'paymentMethod': paymentMethod,
        'status': status.name,
        if (passengerName != null) 'passengerName': passengerName,
        if (passengerPhone != null) 'passengerPhone': passengerPhone,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        if (acceptedAt != null) 'acceptedAt': acceptedAt,
        if (completedAt != null) 'completedAt': completedAt,
        if (cancelledAt != null) 'cancelledAt': cancelledAt,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
        if (cancelReason != null) 'cancelReason': cancelReason,
        if (cancellationFee != null) 'cancellationFee': cancellationFee,
        if (surgeMultiplier != 1.0) 'surgeMultiplier': surgeMultiplier,
        if (passengerRating != null) 'passengerRating': passengerRating,
        if (passengerTip != null) 'passengerTip': passengerTip,
        if (passengerReview != null) 'passengerReview': passengerReview,
        if (appliedDiscount != null) 'appliedDiscount': appliedDiscount,
        if (appliedVoucherCode != null) 'appliedVoucherCode': appliedVoucherCode,
        if (skippedBy.isNotEmpty) 'skippedBy': skippedBy,
      };

  TripModel copyWith({
    String? driverId,
    TripStatus? status,
    Timestamp? acceptedAt,
    Timestamp? completedAt,
    Timestamp? cancelledAt,
    String? cancelledBy,
    String? cancelReason,
    int? cancellationFee,
    double? surgeMultiplier,
    int? passengerRating,
    int? passengerTip,
    String? passengerReview,
  }) =>
      TripModel(
        tripId: tripId,
        passengerId: passengerId,
        driverId: driverId ?? this.driverId,
        serviceType: serviceType,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        distanceKm: distanceKm,
        durationMin: durationMin,
        totalFare: totalFare,
        platformFee: platformFee,
        driverEarns: driverEarns,
        paymentMethod: paymentMethod,
        status: status ?? this.status,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        createdAt: createdAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        completedAt: completedAt ?? this.completedAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        cancelReason: cancelReason ?? this.cancelReason,
        cancellationFee: cancellationFee ?? this.cancellationFee,
        surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
        passengerRating: passengerRating ?? this.passengerRating,
        passengerTip: passengerTip ?? this.passengerTip,
        passengerReview: passengerReview ?? this.passengerReview,
        appliedDiscount: appliedDiscount,
        appliedVoucherCode: appliedVoucherCode,
        skippedBy: skippedBy,
      );
}
