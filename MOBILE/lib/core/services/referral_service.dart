// lib/core/services/referral_service.dart
//
// Business rules:
// - Setiap driver punya satu kode unik
// - Kode bisa dipakai driver manapun kecuali pemilik kode
// - Driver yang sudah pakai satu kode tidak bisa pakai kode lain
// - Saat invitee selesai 20 trip: referrer DAN invitee sama-sama dapat bonus
// - First claim wins: satu driver hanya bisa punya satu referrer

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ── Bonus config ──────────────────────────────────────────────────────────────

const kReferrerBonus  = 25000; // Rp 25.000 untuk penyebar kode
const kInviteeBonus   = 15000; // Rp 15.000 untuk pengguna kode
const kMilestoneTrips = 20;    // Jumlah trip untuk unlock bonus

// ── Models ────────────────────────────────────────────────────────────────────

enum ReferralStatus { registered, inProgress, completed, paid }

class ReferralInvitee {
  const ReferralInvitee({
    required this.driverId,
    required this.name,
    required this.joinDate,
    required this.tripsCompleted,
    required this.status,
    required this.bonusPaid,
  });
  final String         driverId;
  final String         name;
  final DateTime       joinDate;
  final int            tripsCompleted;
  final ReferralStatus status;
  final bool           bonusPaid; // apakah referrer sudah menerima bonus

  double get progressPct =>
      (tripsCompleted / kMilestoneTrips).clamp(0.0, 1.0);

  bool get isComplete =>
      status == ReferralStatus.completed ||
      status == ReferralStatus.paid;

  Map<String, dynamic> toMap() => {
    'driverId'   : driverId,
    'name'       : name,
    'joinDate'   : joinDate.toIso8601String(),
    'trips'      : tripsCompleted,
    'status'     : status.name,
    'bonusPaid'  : bonusPaid,
  };

  static ReferralInvitee fromMap(Map m) => ReferralInvitee(
    driverId      : m['driverId']?.toString() ?? '',
    name          : m['name']?.toString()     ?? 'Driver Baru',
    joinDate      : DateTime.tryParse(
        m['joinDate']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    tripsCompleted: (m['trips']    as num?)?.toInt() ?? 0,
    status        : ReferralStatus.values.firstWhere(
      (s) => s.name == (m['status']?.toString() ?? 'registered'),
      orElse: () => ReferralStatus.registered,
    ),
    bonusPaid     : m['bonusPaid'] as bool? ?? false,
  );
}

/// Info kode yang dipakai oleh driver ini saat signup
class UsedReferralInfo {
  const UsedReferralInfo({
    required this.referrerName,
    required this.code,
    required this.usedDate,
    required this.bonusReceived, // bonus invitee sudah diterima?
  });
  final String   referrerName;
  final String   code;
  final DateTime usedDate;
  final bool     bonusReceived;

  static UsedReferralInfo? fromMap(Map? m) {
    if (m == null) return null;
    return UsedReferralInfo(
      referrerName : m['referrerName']?.toString() ?? '',
      code         : m['code']?.toString()         ?? '',
      usedDate     : DateTime.tryParse(
          m['usedDate']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      bonusReceived: m['bonusReceived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'referrerName': referrerName,
    'code'        : code,
    'usedDate'    : usedDate.toIso8601String(),
    'bonusReceived': bonusReceived,
  };
}

// ── Service ───────────────────────────────────────────────────────────────────

class ReferralService {
  ReferralService._();
  static final instance = ReferralService._();

  // ── Kode referral ─────────────────────────────────────────────────────────

  String getOrCreateCode(String driverId, String driverName) {
    final box  = Hive.box('settings');
    final key  = 'referral_code_$driverId';
    final code = box.get(key) as String?;

    // Selalu update nama driver agar _getDriverName akurat
    box.put('driver_display_name_$driverId', driverName);

    if (code != null) return code;

    final initials = driverName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(3)
        .map((w) => w[0].toUpperCase())
        .join();
    final digits = (1000 + Random().nextInt(8999)).toString();
    final newCode = '$initials$digits';
    box.put(key, newCode);
    return newCode;
  }

  // ── Gunakan kode ──────────────────────────────────────────────────────────

  /// Validasi dan daftarkan penggunaan kode referral.
  /// Returns: null = sukses, String = pesan error
  String? useCode({
    required String driverId,
    required String driverName,
    required String code,
    required String allDriversJson, // untuk lookup kode → pemilik
  }) {
    final box = Hive.box('settings');

    // Sudah pakai kode sebelumnya?
    if (box.containsKey('referral_used_$driverId')) {
      return 'Kamu sudah menggunakan kode referral sebelumnya.';
    }

    // Cari pemilik kode
    final referrerId = _findCodeOwner(code);
    if (referrerId == null) {
      return 'Kode referral tidak ditemukan.';
    }

    // Tidak bisa pakai kode sendiri
    if (referrerId == driverId) {
      return 'Kamu tidak bisa menggunakan kode referral sendiri.';
    }

    // Simpan: driver ini menggunakan kode dari referrerId
    box.put('referral_used_$driverId', {
      'referrerName': _getDriverName(referrerId),
      'code'        : code,
      'usedDate'    : DateTime.now().toIso8601String(),
      'bonusReceived': false,
    });

    // Daftarkan driver ini sebagai invitee referrerId
    _addInvitee(
      referrerId : referrerId,
      inviteeId  : driverId,
      inviteeName: driverName,
    );

    debugPrint('=== Referral: $driverName menggunakan kode $code '
        'dari driver $referrerId');
    return null; // sukses
  }

  void _addInvitee({
    required String referrerId,
    required String inviteeId,
    required String inviteeName,
  }) {
    final box  = Hive.box('settings');
    final key  = 'referral_invitees_$referrerId';
    final list = (box.get(key) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    list.add(ReferralInvitee(
      driverId      : inviteeId,
      name          : inviteeName,
      joinDate      : DateTime.now(),
      tripsCompleted: 0,
      status        : ReferralStatus.registered,
      bonusPaid     : false,
    ).toMap());

    box.put(key, list);
  }

  // ── Trip progress update ──────────────────────────────────────────────────

  /// Dipanggil setiap kali invitee selesai satu trip.
  /// Otomatis trigger bonus jika milestone tercapai.
  Future<void> onInviteeTripCompleted(String inviteeId) async {
    final box        = Hive.box('settings');
    final usedKey    = 'referral_used_$inviteeId';
    final usedRaw    = box.get(usedKey) as Map?;
    if (usedRaw == null) return; // driver ini tidak dari referral

    // Cari referrerId berdasarkan kode yang dipakai
    final code       = usedRaw['code']?.toString() ?? '';
    final referrerId = _findCodeOwner(code);
    if (referrerId == null) return;

    final inviteesKey = 'referral_invitees_$referrerId';
    final list = (box.get(inviteesKey) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final idx = list.indexWhere((m) => m['driverId'] == inviteeId);
    if (idx == -1) return;

    final current = (list[idx]['trips'] as num?)?.toInt() ?? 0;
    final updated = current + 1;
    list[idx]['trips'] = updated;

    if (updated >= kMilestoneTrips &&
        list[idx]['status'] != 'paid') {
      list[idx]['status'] = 'completed';

      // Bayar bonus ke referrer
      if (!(list[idx]['bonusPaid'] as bool? ?? false)) {
        _addBonus(referrerId, kReferrerBonus);
        list[idx]['bonusPaid'] = true;
        list[idx]['status']    = 'paid';
        debugPrint('=== Bonus Rp$kReferrerBonus → referrer $referrerId');
      }

      // Bayar bonus ke invitee (jika belum)
      final usedMap = Map<String, dynamic>.from(usedRaw);
      if (!(usedMap['bonusReceived'] as bool? ?? false)) {
        _addBonus(inviteeId, kInviteeBonus);
        usedMap['bonusReceived'] = true;
        box.put(usedKey, usedMap);
        debugPrint('=== Bonus Rp$kInviteeBonus → invitee $inviteeId');
      }
    } else if (updated < kMilestoneTrips) {
      list[idx]['status'] = 'inProgress';
    }

    await box.put(inviteesKey, list);
  }

  void _addBonus(String driverId, int amount) {
    final box     = Hive.box('settings');
    final walletKey = 'driver_wallet_$driverId';
    final prev    = (box.get(walletKey) as num?)?.toInt() ?? 0;
    box.put(walletKey, prev + amount);

    // Log bonus
    final logKey = 'referral_bonus_log_$driverId';
    final log    = (box.get(logKey) as List? ?? []).toList();
    log.insert(0, {
      'amount': amount,
      'date'  : DateTime.now().toIso8601String(),
    });
    box.put(logKey, log.take(50).toList());
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<ReferralInvitee> getInvitees(String driverId) {
    final box = Hive.box('settings');
    return (box.get('referral_invitees_$driverId') as List? ?? [])
        .map((e) => ReferralInvitee.fromMap(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  UsedReferralInfo? getUsedCode(String driverId) {
    final box = Hive.box('settings');
    final raw = box.get('referral_used_$driverId') as Map?;
    return UsedReferralInfo.fromMap(raw);
  }

  int totalBonusEarned(String driverId) {
    final box = Hive.box('settings');
    final log = (box.get('referral_bonus_log_$driverId') as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return log.fold(0, (s, m) => s + ((m['amount'] as num?)?.toInt() ?? 0));
  }

  int totalBonusPaid(String driverId) => getInvitees(driverId)
      .where((i) => i.bonusPaid)
      .length * kReferrerBonus;

  int totalBonusPending(String driverId) => getInvitees(driverId)
      .where((i) => i.status == ReferralStatus.completed && !i.bonusPaid)
      .length * kReferrerBonus;

  // ── Seed data ─────────────────────────────────────────────────────────────

  void seedReferralData(String driverId, String driverName) {
    final box = Hive.box('settings');

    // Pastikan kode dibuat
    getOrCreateCode(driverId, driverName);

    final inviteesKey = 'referral_invitees_$driverId';
    if (box.containsKey(inviteesKey)) return;

    final now = DateTime.now();
    final invitees = [
      ReferralInvitee(
        driverId      : 'seed-inv-001',
        name          : 'Budi Santoso',
        joinDate      : now.subtract(const Duration(days: 25)),
        tripsCompleted: 20,
        status        : ReferralStatus.paid,
        bonusPaid     : true,
      ),
      ReferralInvitee(
        driverId      : 'seed-inv-002',
        name          : 'Deni Kurniawan',
        joinDate      : now.subtract(const Duration(days: 14)),
        tripsCompleted: 16,
        status        : ReferralStatus.inProgress,
        bonusPaid     : false,
      ),
      ReferralInvitee(
        driverId      : 'seed-inv-003',
        name          : 'Farhan Maulana',
        joinDate      : now.subtract(const Duration(days: 7)),
        tripsCompleted: 7,
        status        : ReferralStatus.inProgress,
        bonusPaid     : false,
      ),
      ReferralInvitee(
        driverId      : 'seed-inv-004',
        name          : 'Gilang Pratama',
        joinDate      : now.subtract(const Duration(days: 2)),
        tripsCompleted: 0,
        status        : ReferralStatus.registered,
        bonusPaid     : false,
      ),
    ];

    box.put(inviteesKey, invitees.map((i) => i.toMap()).toList());

    // Seed log bonus (1 sudah terbayar)
    final logKey = 'referral_bonus_log_$driverId';
    if (!box.containsKey(logKey)) {
      box.put(logKey, [
        {
          'amount': kReferrerBonus,
          'date'  : now.subtract(const Duration(days: 5))
              .toIso8601String(),
        }
      ]);
    }

    debugPrint('=== Referral seed done for $driverId');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _findCodeOwner(String code) {
    final box = Hive.box('settings');
    // Scan semua kode yang tersimpan
    for (final key in box.keys) {
      if (key.toString().startsWith('referral_code_')) {
        if (box.get(key) == code) {
          return key.toString().replaceFirst('referral_code_', '');
        }
      }
    }
    return null;
  }

  String _getDriverName(String driverId) {
    final box  = Hive.box('settings');
    // Coba ambil nama dari active driver atau simpan saat kode dibuat
    final saved = box.get('driver_display_name_$driverId') as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    // Fallback: ambil dari active_driver_id jika cocok
    final activeId = box.get('active_driver_id') as String?;
    if (activeId == driverId) {
      return box.get('active_driver_name',
          defaultValue: 'Driver') as String;
    }
    return 'Driver';
  }
}