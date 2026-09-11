import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutStatus {
  processing,
  success,
  failed;

  static PayoutStatus fromString(String s) => PayoutStatus.values
      .firstWhere((e) => e.name == s, orElse: () => PayoutStatus.processing);
}

/// A single driver withdrawal (D-S6 Daily Withdrawal) — mirrors the SRS
/// `payouts` entity so the admin console has a real transaction ledger.
class PayoutModel {
  const PayoutModel({
    required this.payoutId,
    required this.driverId,
    required this.amountIdr,
    required this.destination,
    required this.status,
    this.driverName,
    this.feeIdr = 0,
    this.requestedAt,
    this.paidAt,
  });

  final String payoutId;
  final String driverId;
  final String? driverName;
  final int amountIdr;
  final int feeIdr;
  final String destination;
  final PayoutStatus status;
  final Timestamp? requestedAt;
  final Timestamp? paidAt;

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;

  factory PayoutModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PayoutModel(
      payoutId: doc.id,
      driverId: _str(d['driverId']) ?? '',
      driverName: _str(d['driverName']),
      amountIdr: _num(d['amountIdr'])?.toInt() ?? 0,
      feeIdr: _num(d['feeIdr'])?.toInt() ?? 0,
      destination: _str(d['destination']) ?? '',
      status: PayoutStatus.fromString(_str(d['status']) ?? 'processing'),
      requestedAt: _ts(d['requestedAt']),
      paidAt: _ts(d['paidAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        if (driverName != null) 'driverName': driverName,
        'amountIdr': amountIdr,
        'feeIdr': feeIdr,
        'destination': destination,
        'status': status.name,
        'requestedAt': requestedAt ?? FieldValue.serverTimestamp(),
        if (paidAt != null) 'paidAt': paidAt,
      };
}
