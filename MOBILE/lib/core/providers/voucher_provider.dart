// lib/core/providers/voucher_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../di/repository_providers.dart';
import '../../data/models/promo_model.dart';

/// Live promo catalog — Firestore-backed in P2, API-backed in MVP.
/// Admins manage this collection from the admin console.
final promosProvider = StreamProvider<List<PromoModel>>(
  (ref) => ref.watch(promoRepositoryProvider).getPromosStream(),
);

const _hiveKey = 'saved_vouchers';

final voucherProvider =
    StateNotifierProvider<VoucherNotifier, Set<String>>(
  (ref) => VoucherNotifier(),
);

/// Tracks which promo codes *this device's* user has saved/used. The promo
/// catalog itself lives in Firestore ([promosProvider]) — this notifier only
/// holds local per-user save/use state, persisted to Hive.
class VoucherNotifier extends StateNotifier<Set<String>> {
  VoucherNotifier() : super(const {}) {
    _load();
  }

  Set<String> _usedCodes = {};

  void _load() {
    final box = Hive.box('settings');
    final raw = box.get(_hiveKey) as List?;
    if (raw != null) {
      state = raw.cast<String>().toSet();
    }
    final used = (box.get('used_vouchers') as List?)
        ?.cast<String>() ?? [];
    _usedCodes = used.toSet();
  }

  Future<void> _persist() async {
    await Hive.box('settings').put(_hiveKey, state.toList());
  }

  bool isSaved(String code) => state.contains(code);
  bool isUsed(String code) => _usedCodes.contains(code);

  /// Given the live promo catalog, which ones aren't saved yet → home banner.
  List<PromoModel> unsavedOf(List<PromoModel> promos) => promos
      .where((p) =>
          p.isActive && !state.contains(p.code) && !_usedCodes.contains(p.code))
      .toList();

  /// Given the live promo catalog, which ones are saved → promos screen.
  List<PromoModel> savedOf(List<PromoModel> promos) => promos
      .where((p) =>
          p.isActive && state.contains(p.code) && !_usedCodes.contains(p.code))
      .toList();

  bool hasUnsavedOf(List<PromoModel> promos) => unsavedOf(promos).isNotEmpty;

  Future<void> saveVoucher(String code) async {
    state = {...state, code};
    await _persist();
  }

  Future<void> removeVoucher(String code) async {
    state = state.where((c) => c != code).toSet();
    await _persist();
  }

  Future<void> markAsUsed(String code) async {
    _usedCodes = {..._usedCodes, code};
    await Hive.box('settings')
        .put('used_vouchers', _usedCodes.toList());
    // Hapus dari saved juga
    await removeVoucher(code);
  }
}
