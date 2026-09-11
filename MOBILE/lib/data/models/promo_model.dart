import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoDiscountType {
  percent,
  flat;

  static PromoDiscountType fromString(String s) => PromoDiscountType.values
      .firstWhere((e) => e.name == s, orElse: () => PromoDiscountType.flat);
}

/// Admin-managed promo code (Firestore `promos` collection). Replaces the
/// old hardcoded `mockVouchers` list — the passenger app reads this
/// collection directly, and ops can add/edit/remove codes without a build.
class PromoModel {
  const PromoModel({
    required this.promoId,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrder,
    required this.expiryLabel,
    this.isActive = true,
    this.createdAt,
  });

  final String promoId;
  final String code;
  final String title;
  final String description;
  final PromoDiscountType discountType;
  final int discountValue;
  final int minOrder;
  final String expiryLabel;
  final bool isActive;
  final Timestamp? createdAt;

  // Flat IDR discount applied to a given fare — percent codes are treated
  // as a percentage of the fare (capped at the fare itself); flat codes are
  // a fixed IDR amount.
  int discountFor(int fare) => discountType == PromoDiscountType.percent
      ? ((fare * discountValue) / 100).round().clamp(0, fare)
      : discountValue.clamp(0, fare);

  static String? _str(dynamic v) => v is String ? v : null;
  static num? _num(dynamic v) => v is num ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;

  factory PromoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PromoModel(
      promoId: doc.id,
      code: _str(d['code']) ?? '',
      title: _str(d['title']) ?? '',
      description: _str(d['description']) ?? '',
      discountType:
          PromoDiscountType.fromString(_str(d['discountType']) ?? 'flat'),
      discountValue: _num(d['discountValue'])?.toInt() ?? 0,
      minOrder: _num(d['minOrder'])?.toInt() ?? 0,
      expiryLabel: _str(d['expiryLabel']) ?? '',
      isActive: d['isActive'] is bool ? d['isActive'] as bool : true,
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'title': title,
        'description': description,
        'discountType': discountType.name,
        'discountValue': discountValue,
        'minOrder': minOrder,
        'expiryLabel': expiryLabel,
        'isActive': isActive,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };
}
