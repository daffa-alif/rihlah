// lib/core/services/sos_service.dart
//
// Emergency SOS service untuk driver.
// P2: rekam audio lokal, simpan log ke Hive, notifikasi lokal.
// Produksi: upload ke secure bucket + notifikasi ke ops + Provincial Captain.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../../data/models/sos_event_model.dart';

/// Status SOS saat ini
enum SosStatus { idle, countdown, recording, sending, confirmed, failed }

class SosService {
  SosService._();
  static final instance = SosService._();

  static const _recordSeconds  = 30;
  static const _countdownSecs  = 3;
  static const _hiveKey        = 'sos_log_';

  SosStatus _status = SosStatus.idle;
  SosStatus get status => _status;

  Timer? _countdownTimer;
  Timer? _recordTimer;
  int    _countdownRemaining = _countdownSecs;
  int    get countdownRemaining => _countdownRemaining;

  final _statusNotifier = ValueNotifier<SosStatus>(SosStatus.idle);
  ValueNotifier<SosStatus> get statusNotifier => _statusNotifier;

  final _countdownNotifier = ValueNotifier<int>(_countdownSecs);
  ValueNotifier<int> get countdownNotifier => _countdownNotifier;

  /// Mulai countdown 3 detik. Panggil `cancelCountdown()` untuk batal.
  void startCountdown({
    required String driverId,
    required String? tripId,
    required VoidCallback onConfirmed,
    required VoidCallback onCancelled,
  }) {
    if (_status != SosStatus.idle) return;

    _status = SosStatus.countdown;
    _countdownRemaining = _countdownSecs;
    _statusNotifier.value = _status;
    _countdownNotifier.value = _countdownRemaining;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _countdownRemaining--;
      _countdownNotifier.value = _countdownRemaining;

      if (_countdownRemaining <= 0) {
        t.cancel();
        _triggerSos(
          driverId   : driverId,
          tripId     : tripId,
          onConfirmed: onConfirmed,
        );
      }
    });
  }

  /// Batalkan countdown sebelum SOS terpicu.
  void cancelCountdown() {
    if (_status != SosStatus.countdown) return;
    _countdownTimer?.cancel();
    _status = SosStatus.idle;
    _countdownRemaining = _countdownSecs;
    _statusNotifier.value = _status;
    _countdownNotifier.value = _countdownRemaining;
  }

  Future<void> _triggerSos({
    required String  driverId,
    required String? tripId,
    required VoidCallback onConfirmed,
  }) async {
    _status = SosStatus.recording;
    _statusNotifier.value = _status;

    // Ambil lokasi GPS
    String locationStr = 'Lokasi tidak tersedia';
    double? lat, lng;
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
      locationStr =
          '${pos.latitude.toStringAsFixed(6)}, '
          '${pos.longitude.toStringAsFixed(6)}';
    } catch (_) {}

    // Rekam audio — P2: simulasi 30 detik
    // Produksi: gunakan package 'record' untuk rekam audio nyata
    String? audioPath;
    try {
      final dir = await getTemporaryDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;
      audioPath = '${dir.path}/sos_${driverId}_$ts.m4a';
      // Simulasi durasi rekam 30 detik (dipercepat jadi 1 detik untuk demo)
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('=== SOS audio simulated: $audioPath');
    } catch (e) {
      debugPrint('=== SOS audio error: $e');
    }

    // Simpan log ke Hive
    await _saveLog(
      driverId  : driverId,
      tripId    : tripId,
      location  : locationStr,
      audioPath : audioPath,
    );

    // Simulasi kirim ke ops (P2: notifikasi lokal saja)
    _status = SosStatus.sending;
    _statusNotifier.value = _status;

    // Real ops-visible record — audio capture itself stays simulated
    // (no mic package wired), but the event is now a real Firestore doc
    // so the admin console's safety queue is functional.
    if (lat != null && lng != null) {
      try {
        await FirestoreService.instance.createSosEvent(SosEventModel(
          eventId: '',
          byUserId: driverId,
          byUserRole: 'driver',
          tripId: tripId,
          lat: lat,
          lng: lng,
        ));
      } catch (_) {
        // Non-fatal: offline — the local log + notification still fired.
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));

    // Notifikasi konfirmasi
    await NotificationService.instance.showSosConfirmation(
        driverId: driverId);

    _status = SosStatus.confirmed;
    _statusNotifier.value = _status;

    onConfirmed();

    // Reset ke idle setelah 3 detik
    await Future.delayed(const Duration(seconds: 3));
    _status = SosStatus.idle;
    _statusNotifier.value = _status;
  }

  Future<void> _saveLog({
    required String  driverId,
    required String? tripId,
    required String  location,
    required String? audioPath,
  }) async {
    final box    = Hive.box('settings');
    final key    = '$_hiveKey$driverId';
    final logs   = (box.get(key) as List? ?? [])
        .cast<Map>().toList();

    logs.insert(0, {
      'date'     : DateTime.now().toIso8601String(),
      'tripId'   : tripId,
      'location' : location,
      'audioPath': audioPath,
      'status'   : 'sent', // P2: selalu sent
    });

    // Simpan max 50 log
    await box.put(key, logs.take(50).toList());
    debugPrint('=== SOS log saved: $location');
  }

  void dispose() {
    _countdownTimer?.cancel();
    _recordTimer?.cancel();
    _statusNotifier.dispose();
    _countdownNotifier.dispose();
  }
}