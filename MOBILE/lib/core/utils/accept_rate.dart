// lib/core/utils/accept_rate.dart
//
// Utilitas untuk membaca dan menghitung accept rate driver.

import 'package:hive_flutter/hive_flutter.dart';

class AcceptRateStats {
  const AcceptRateStats({
    required this.totalOrders,
    required this.accepted,
    required this.declined,
    required this.autoDeclined,
    required this.acceptRate,
    required this.isLow,
  });

  final int    totalOrders;  // hanya accept + manual decline (bukan auto)
  final int    accepted;
  final int    declined;
  final int    autoDeclined;
  final double acceptRate;   // 0.0–1.0
  final bool   isLow;        // true jika < 50% dan >= 50 order

  static const _lowThreshold    = 0.50;
  static const _minOrdersForLow = 50;

  static AcceptRateStats load(String driverId) {
    final box = Hive.box('settings');
    final key = 'accept_rate_$driverId';
    final raw = (box.get(key) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    int accepted    = 0;
    int declined    = 0;
    int autoDeclined = 0;

    for (final r in raw) {
      switch (r['result'] as String? ?? '') {
        case 'accept'  : accepted++;     break;
        case 'decline' : declined++;     break;
        case 'auto'    : autoDeclined++; break;
      }
    }

    // Accept rate hanya dari keputusan manual
    final manual     = accepted + declined;
    final rate       = manual > 0 ? accepted / manual : 1.0;
    final isLow      = manual >= _minOrdersForLow &&
        rate < _lowThreshold;

    return AcceptRateStats(
      totalOrders : manual,
      accepted    : accepted,
      declined    : declined,
      autoDeclined: autoDeclined,
      acceptRate  : rate,
      isLow       : isLow,
    );
  }

  String get rateLabel =>
      '${(acceptRate * 100).toStringAsFixed(0)}%';
}