// lib/core/services/notification_service.dart
//
// Local push notifications untuk order masuk.
// Menggunakan flutter_local_notifications — tidak butuh Firebase.

import 'dart:typed_data' show Int64List;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission : true,
      requestBadgePermission : true,
      requestSoundPermission : true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onTap,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Minta izin di Android 13+
    await androidPlugin?.requestNotificationsPermission();

    // Pre-register channels at startup instead of lazily on first .show() —
    // a channel has to exist before Android will surface a notification
    // through it, which matters most while the app is backgrounded (the
    // trigger is a live Firestore/RTDB listener, not a system push, so
    // there's no guarantee the "first" notification for a channel happens
    // while the app is in the foreground).
    for (final channel in _allChannels) {
      await androidPlugin?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  static const _allChannels = [
    AndroidNotificationChannel(
      _orderChannelId,
      _orderChannelName,
      description: 'Notifikasi order masuk dari penumpang',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      _sendChannelId,
      _sendChannelName,
      description: 'Notifikasi order kirim barang (RIHLAH Send)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      _chatChannelId,
      _chatChannelName,
      description: 'Notifikasi pesan chat selama perjalanan',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: 'Notifikasi panggilan masuk dalam aplikasi',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
  ];

  void _onTap(NotificationResponse response) {
    // Sudah di foreground — tidak perlu navigate, overlay sudah muncul
  }

  // ── Channels ──────────────────────────────────────────────────────────────

  static const _orderChannelId   = 'rihlah_order';
  static const _orderChannelName = 'Pesanan Masuk';

  static const AndroidNotificationDetails _orderAndroid =
      AndroidNotificationDetails(
    _orderChannelId,
    _orderChannelName,
    channelDescription: 'Notifikasi order masuk dari penumpang',
    importance        : Importance.max,
    priority          : Priority.high,
    playSound         : true,
    enableVibration   : true,
    fullScreenIntent  : true, // overlay saat layar mati
    ticker            : 'Pesanan masuk!',
    icon              : '@mipmap/ic_launcher',
  );

  static const NotificationDetails _orderDetails = NotificationDetails(
    android: _orderAndroid,
    iOS    : DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // Separate channel for RIHLAH Send (package delivery) orders — same
  // urgency, but visually distinct (accent color, different vibration
  // pattern) so a driver glancing at the notification can immediately tell
  // it's a delivery, not a passenger pickup.
  static const _sendChannelId   = 'rihlah_order_send';
  static const _sendChannelName = 'Pesanan Kirim Barang';

  // Not const: vibrationPattern needs Int64List.fromList(), which isn't a
  // const constructor.
  static final AndroidNotificationDetails _sendOrderAndroid =
      AndroidNotificationDetails(
    _sendChannelId,
    _sendChannelName,
    channelDescription: 'Notifikasi order kirim barang (RIHLAH Send)',
    importance        : Importance.max,
    priority          : Priority.high,
    playSound         : true,
    enableVibration   : true,
    vibrationPattern  : Int64List.fromList(
        [0, 400, 200, 400, 200, 400]), // distinct triple-buzz pattern
    fullScreenIntent  : true,
    ticker            : 'Pesanan kirim barang masuk!',
    icon              : '@mipmap/ic_launcher',
    color             : const Color(0xFFF4A11C), // accent500 — matches in-app badge
    colorized         : true,
  );

  static final NotificationDetails _sendOrderDetails = NotificationDetails(
    android: _sendOrderAndroid,
    iOS    : const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // Chat — one channel shared by both passenger and driver apps.
  static const _chatChannelId   = 'rihlah_chat';
  static const _chatChannelName = 'Pesan Masuk';

  static const AndroidNotificationDetails _chatAndroid =
      AndroidNotificationDetails(
    _chatChannelId,
    _chatChannelName,
    channelDescription: 'Notifikasi pesan chat selama perjalanan',
    importance        : Importance.high,
    priority          : Priority.high,
    playSound         : true,
    enableVibration   : true,
    icon              : '@mipmap/ic_launcher',
  );

  static const NotificationDetails _chatDetails = NotificationDetails(
    android: _chatAndroid,
    iOS    : DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // In-app voice call — full-screen intent so it's as noticeable as an
  // incoming order, since a missed call is time-sensitive.
  static const _callChannelId   = 'rihlah_call';
  static const _callChannelName = 'Panggilan Masuk';

  static const AndroidNotificationDetails _callAndroid =
      AndroidNotificationDetails(
    _callChannelId,
    _callChannelName,
    channelDescription: 'Notifikasi panggilan masuk dalam aplikasi',
    importance        : Importance.max,
    priority          : Priority.high,
    playSound         : true,
    enableVibration   : true,
    fullScreenIntent  : true,
    ticker            : 'Panggilan masuk!',
    icon              : '@mipmap/ic_launcher',
  );

  static const NotificationDetails _callDetails = NotificationDetails(
    android: _callAndroid,
    iOS    : DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Notifikasi pesan chat baru dari lawan bicara (penumpang atau driver).
  /// Satu notifikasi per trip — pesan baru menggantikan yang lama, bukan
  /// menumpuk, agar tidak membanjiri notification tray selama percakapan.
  Future<void> showNewMessage({
    required String tripId,
    required String senderName,
    required String text,
  }) async {
    await init();
    await _plugin.show(
      _chatIdHash(tripId),
      senderName,
      text,
      _chatDetails,
      payload: tripId,
    );
  }

  /// Notifikasi panggilan masuk dari lawan bicara. Otomatis dibatalkan
  /// lewat [cancelIncomingCall] setelah call screen terbuka atau berakhir.
  Future<void> showIncomingCall({
    required String tripId,
    required String callerName,
  }) async {
    await init();
    await _plugin.show(
      _callIdHash(tripId),
      '📞 Panggilan dari $callerName',
      'Ketuk untuk mengangkat',
      _callDetails,
      payload: tripId,
    );
  }

  Future<void> cancelIncomingCall(String tripId) async {
    await _plugin.cancel(_callIdHash(tripId));
  }

  /// Tampilkan notifikasi order masuk.
  Future<void> showIncomingOrder({
    required String orderId,
    required String passenger,
    required String pickup,
    required String dropoff,
    required double distanceToPickupKm,
    required double tripDistanceKm,
    required int    driverEarnsRp,
    String serviceType = 'car',
  }) async {
    await init();

    final distStr = distanceToPickupKm.toStringAsFixed(1);
    final earnStr = _fmtIdr(driverEarnsRp);
    final isSend  = serviceType == 'send';

    final title = isSend
        ? '📦 Kirim Barang Masuk — $earnStr'
        : '🚗 Pesanan Masuk — $earnStr';
    final body = isSend
        ? '$passenger · Ambil $distStr km · $pickup → $dropoff'
        : '$passenger · Jemput $distStr km · $pickup → $dropoff';

    await _plugin.show(
      _orderIdHash(orderId),
      title,
      body,
      isSend ? _sendOrderDetails : _orderDetails,
      payload: orderId,
    );
  }

  /// Batalkan notifikasi order (setelah accept/decline/timeout).
  Future<void> cancelOrder(String orderId) async {
    await _plugin.cancel(_orderIdHash(orderId));
  }

  /// Batalkan semua notifikasi.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Notifikasi konfirmasi SOS terkirim.
  Future<void> showSosConfirmation({required String driverId}) async {
    await init();
    const android = AndroidNotificationDetails(
      'rihlah_sos',
      'SOS Darurat',
      channelDescription: 'Notifikasi konfirmasi SOS driver',
      importance: Importance.max,
      priority  : Priority.max,
      playSound : true,
      color     : Color(0xFFEF4444),
    );
    await _plugin.show(
      driverId.hashCode.abs() % 99998,
      '🆘 SOS Terkirim',
      'Tim RIHLAH sudah diberitahu. Bantuan sedang dalam perjalanan.',
      const NotificationDetails(
        android: android,
        iOS    : DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Tampilkan notifikasi status payout setelah withdraw.
  Future<void> showPayoutStatus({
    required String driverId,
    required int    amount,
    required bool   success,
  }) async {
    await init();

    const android = AndroidNotificationDetails(
      'rihlah_payout',
      'Status Penarikan',
      channelDescription: 'Notifikasi status penarikan dana',
      importance: Importance.high,
      priority  : Priority.high,
      playSound : true,
    );

    final earn = _fmtIdr(amount);
    final title = success
        ? '✅ Penarikan Berhasil'
        : '❌ Penarikan Gagal';
    final body  = success
        ? '$earn sedang diproses ke rekeningmu (1×24 jam)'
        : 'Penarikan $earn gagal. Dana dikembalikan dalam 1 hari kerja.';

    await _plugin.show(
      driverId.hashCode.abs() % 99999,
      title, body,
      const NotificationDetails(
        android: android,
        iOS    : DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Konversi orderId string ke int untuk notification id.
  int _orderIdHash(String id) => id.hashCode.abs() % 100000;

  /// Same trip → same notification id, so new messages replace the old
  /// notification instead of stacking up.
  int _chatIdHash(String tripId) => ('chat_$tripId').hashCode.abs() % 100000;

  int _callIdHash(String tripId) => ('call_$tripId').hashCode.abs() % 100000;

  String _fmtIdr(int v) {
    if (v == 0) return 'Rp 0';
    final s      = v.toString();
    final buf    = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}