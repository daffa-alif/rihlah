// lib/core/providers/saved_address_provider.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/saved_address.dart';
import '../services/firestore_service.dart';

const _hiveKey = 'saved_addresses';

final savedAddressProvider =
    StateNotifierProvider<SavedAddressNotifier, List<SavedAddress>>(
  (ref) => SavedAddressNotifier(),
);

/// Saved addresses are tied to the signed-in account, synced to Firestore
/// (`users/{uid}/addresses`) so they survive reinstall/new-device. Hive is
/// kept as an offline-first local cache: it renders instantly on load, then
/// gets overwritten by the first Firestore snapshot once that arrives.
class SavedAddressNotifier extends StateNotifier<List<SavedAddress>> {
  SavedAddressNotifier() : super([]) {
    _loadFromHiveCache();
    // This provider is a long-lived singleton, constructed once at app
    // startup — often before sign-in completes. Track auth state directly
    // rather than reading currentUser once, so the Firestore sync starts
    // (or restarts under a different uid) whenever who's signed in changes.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _addressesSub?.cancel();
      if (user == null) return;
      _subscribeToFirestore(user.uid);
    });
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<SavedAddress>>? _addressesSub;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _loadFromHiveCache() {
    final box = Hive.box('settings');
    final raw = (box.get(_hiveKey) as List?)?.cast<Map>() ?? [];
    state = raw.map(SavedAddress.fromMap).toList();
  }

  void _subscribeToFirestore(String uid) {
    _addressesSub =
        FirestoreService.instance.addressesStream(uid).listen((addresses) {
      state = addresses;
      _cacheToHive();
    });
  }

  Future<void> _cacheToHive() async {
    final box = Hive.box('settings');
    await box.put(_hiveKey, state.map((a) => a.toMap()).toList());
  }

  Future<void> add(SavedAddress address) async {
    state = [...state, address];
    await _cacheToHive();
    final uid = _uid;
    if (uid != null) await FirestoreService.instance.addAddress(uid, address);
  }

  Future<void> update(SavedAddress address) async {
    state = [
      for (final a in state)
        if (a.id == address.id) address else a,
    ];
    await _cacheToHive();
    final uid = _uid;
    if (uid != null) await FirestoreService.instance.updateAddress(uid, address);
  }

  Future<void> remove(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _cacheToHive();
    final uid = _uid;
    if (uid != null) await FirestoreService.instance.removeAddress(uid, id);
  }

  /// Buat ID unik untuk alamat baru.
  static String newId() => const Uuid().v4();

  @override
  void dispose() {
    _authSub?.cancel();
    _addressesSub?.cancel();
    super.dispose();
  }
}
