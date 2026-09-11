import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahan untuk mengambil UID pengguna
import '../../../core/core.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/firestore_service.dart'; // Tambahan untuk komunikasi ke Firestore
import 'package:rihlah/l10n/app_localizations.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulse1;
  late AnimationController _pulse2;
  late AnimationController _pulse3;

  int    _secondsActive = 0;
  Timer? _activeTimer;
  static const _autoDismiss = 60;

  // Live location state
  LatLng? _currentLocation;
  bool    _loadingLocation = false;

  // Status simulasi audio
  bool _isAudioRecording = false;

  @override
  void initState() {
    super.initState();
    _initPulse();
    _startActiveTimer();
    HapticFeedback.heavyImpact();
    _fetchLocationAndLog(); // Mengambil GPS dan langsung log ke Firestore
  }

  void _initPulse() {
    _pulse1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _pulse2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _pulse3 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    Future.delayed(const Duration(milliseconds: 600),
            () { if (mounted) _pulse2.forward(from: 0.33); });
    Future.delayed(const Duration(milliseconds: 1200),
            () { if (mounted) _pulse3.forward(from: 0.66); });
  }

  // Menggabungkan fetch lokasi dan pengiriman log darurat agar mendapat titik koordinat nyata
  Future<void> _fetchLocationAndLog() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLocation  = pos;
        _loadingLocation  = false;
      });
      // Setelah lokasi didapat, tulis ke Hive dan Firestore
      await _logSos(pos);
    } catch (e) {
      if (mounted) setState(() => _loadingLocation = false);
      // Jika GPS gagal, tetap log SOS tanpa titik lokasi
      await _logSos(null);
    }
  }

  Future<void> _logSos(LatLng? pos) async {
    final box = Hive.box('settings');
    final log = (box.get('sosLog') as List?)?.cast<Map>() ?? [];
    log.add({'timestamp': DateTime.now().toIso8601String()});
    await box.put('sosLog', log);

    // [MODIFIKASI MVP D-S8 / P-S7]: Mengirimkan Event ke Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final role = box.get('user_role', defaultValue: 'unknown') as String;

      // Ambil ID trip yang sedang aktif jika ada (opsional)
      final tripId = box.get('active_trip_id', defaultValue: '') as String;

      await FirestoreService.instance.reportSosEvent(
        userId: uid,
        role: role,
        tripId: tripId.isNotEmpty ? tripId : null,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
    } catch (e) {
      debugPrint("Gagal merekam SOS ke server: $e");
    }

    // Mulai simulasi perekaman audio 30 detik (seperti yang disyaratkan di MVP)
    _startSimulatedAudioCapture();
  }

  // [MODIFIKASI MVP D-S8]: Simulasi Rekam Audio
  void _startSimulatedAudioCapture() async {
    if (mounted) setState(() => _isAudioRecording = true);

    // Menunggu selama 30 detik
    await Future.delayed(const Duration(seconds: 30));

    if (mounted) {
      setState(() => _isAudioRecording = false);
      Toast.show(context,
          message: 'Rekaman sekitar berhasil dikirimkan secara anonim ke pusat bantuan.',
          type: ToastType.success);
    }
  }

  void _startActiveTimer() {
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsActive++);
      if (_secondsActive >= _autoDismiss) _cancel();
    });
  }

  void _cancel() {
    _activeTimer?.cancel();
    if (mounted) context.pop();
  }

  String get _timerLabel {
    final m = _secondsActive ~/ 60;
    final s = _secondsActive % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _mapsLink(LatLng pos) =>
      'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

  @override
  void dispose() {
    _pulse1.dispose();
    _pulse2.dispose();
    _pulse3.dispose();
    _activeTimer?.cancel();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onCallPolice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.danger500,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _FakeCallSheet(
        label: 'Polisi 110',
        onEnd: () => Navigator.pop(context),
      ),
    );
  }

  void _onShare() {
    if (_loadingLocation) {
      Toast.show(context,
          message: 'Sedang mengambil lokasi…',
          type: ToastType.info);
      return;
    }

    final link = _currentLocation != null
        ? _mapsLink(_currentLocation!)
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ShareSheet(
        locationLink: link,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.danger500,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Pulse rings ──────────────────────────────
              Center(
                child: SizedBox(
                  width: 320, height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _Ring(controller: _pulse1, baseColor: AppColors.ink0),
                      _Ring(controller: _pulse2, baseColor: AppColors.ink0),
                      _Ring(controller: _pulse3, baseColor: AppColors.ink0),
                    ],
                  ),
                ),
              ),

              // ── Timer badge ──────────────────────────────
              Positioned(
                top: AppSpacing.s16,
                right: AppSpacing.s16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.ink0.withOpacity(0.2),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: AppColors.ink0, size: 14),
                      const SizedBox(width: 4),
                      Text(_timerLabel,
                          style: AppTypography.mono.copyWith(
                              color: AppColors.ink0,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              // ── Audio Recording Indicator (Simulasi) ───
              if (_isAudioRecording)
                Positioned(
                  top: AppSpacing.s16,
                  left: AppSpacing.s16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.ink0.withOpacity(0.2),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent, // Indikator merekam
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Merekam Suara Sekitar (Otomatis)...',
                            style: AppTypography.bodySm.copyWith(
                                color: AppColors.ink0,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

              // ── GPS loading indicator ────────────────────
              if (_loadingLocation && !_isAudioRecording)
                Positioned(
                  top: AppSpacing.s16,
                  left: AppSpacing.s16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.ink0.withOpacity(0.2),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              color: AppColors.ink0,
                              strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text('Mengambil lokasi…',
                            style: AppTypography.bodySm.copyWith(
                                color: AppColors.ink0)),
                      ],
                    ),
                  ),
                ),

              // ── Main content ─────────────────────────────
              Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96, height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.ink0,
                          ),
                          child: const Center(
                            child: Text('🚨',
                                style: TextStyle(fontSize: 46)),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        Text(s.sos_triggered,
                            style: AppTypography.displayLg.copyWith(
                                color: AppColors.ink0,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.s8),
                        Text(s.sos_help_way,
                            style: AppTypography.bodyLg.copyWith(
                                color: AppColors.ink0,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppSpacing.s8),
                        Text(s.sos_sharing,
                            style: AppTypography.bodySm.copyWith(
                                color: AppColors.ink0.withOpacity(0.8)),
                            textAlign: TextAlign.center),

                        // Koordinat saat ini
                        if (_currentLocation != null) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: 6.0),
                            decoration: BoxDecoration(
                              color: AppColors.ink0.withOpacity(0.15),
                              borderRadius: AppRadius.pillAll,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.ink0, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentLocation!.latitude.toStringAsFixed(5)}, '
                                      '${_currentLocation!.longitude.toStringAsFixed(5)}',
                                  style: AppTypography.mono.copyWith(
                                      color: AppColors.ink0,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Action cards ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s16, 0,
                        AppSpacing.s16, AppSpacing.s16),
                    child: Column(
                      children: [
                        _ActionCard(
                          icon: Icons.phone_rounded,
                          iconBg: const Color(0xFFFFEBEE),
                          iconColor: AppColors.danger500,
                          label: s.sos_call_police,
                          subtitle: s.sos_call_sub,
                          onTap: _onCallPolice,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        _ActionCard(
                          icon: Icons.share_location_rounded,
                          iconBg: const Color(0xFFE8EAF6),
                          iconColor: AppColors.info500,
                          label: s.sos_share_contacts,
                          subtitle: _loadingLocation
                              ? 'Mengambil lokasi GPS…'
                              : _currentLocation != null
                              ? 'Lokasi siap dibagikan'
                              : s.sos_share_sub,
                          onTap: _onShare,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            onPressed: _cancel,
                            style: TextButton.styleFrom(
                              backgroundColor:
                              AppColors.ink0.withOpacity(0.15),
                              foregroundColor: AppColors.ink0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.mdAll),
                            ),
                            child: Text(s.sos_cancel,
                                style: AppTypography.bodyLg.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pulse ring ────────────────────────────────────────────────────────────────

class _Ring extends StatelessWidget {
  const _Ring({required this.controller, required this.baseColor});
  final AnimationController controller;
  final Color               baseColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t       = controller.value;
        final size    = 80.0 + t * 240.0;
        final opacity = (1 - t) * 0.20;
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: baseColor.withOpacity(opacity),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData     icon;
  final Color        iconBg;
  final Color        iconColor;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: AppRadius.mdAll),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.ink500),
          ],
        ),
      ),
    );
  }
}

// ── Fake call sheet ───────────────────────────────────────────────────────────

class _FakeCallSheet extends StatefulWidget {
  const _FakeCallSheet({required this.label, required this.onEnd});
  final String       label;
  final VoidCallback onEnd;

  @override
  State<_FakeCallSheet> createState() => _FakeCallSheetState();
}

class _FakeCallSheetState extends State<_FakeCallSheet>
    with SingleTickerProviderStateMixin {
  int    _elapsed = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= 5) { _t?.cancel(); widget.onEnd(); }
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = _elapsed % 60;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.ink0),
              child: const Center(
                  child: Text('🚔',
                      style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(widget.label,
                style: AppTypography.h2
                    .copyWith(color: AppColors.ink0)),
            Text('Calling… 0:0$s',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.ink0.withOpacity(0.8))),
            const SizedBox(height: AppSpacing.s32),
            GestureDetector(
              onTap: widget.onEnd,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ink0.withOpacity(0.3),
                ),
                child: const Icon(Icons.call_end_rounded,
                    color: AppColors.ink0, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Share sheet ───────────────────────────────────────────────────────────────

const _trustedContacts = [
  _Contact(name: 'Ibu',          phone: '6281299990001', lastChat: '2 jam lalu'),
  _Contact(name: 'Bapak',        phone: '6281299990002', lastChat: 'Kemarin'),
  _Contact(name: 'Teman — Reza', phone: '6281299990003', lastChat: '3 hari lalu'),
];

class _Contact {
  const _Contact({
    required this.name,
    required this.phone,
    required this.lastChat,
  });
  final String name;
  final String phone;
  final String lastChat;
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.locationLink,
    required this.onClose,
  });
  final String?      locationLink;
  final VoidCallback onClose;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _sent = <String>{};

  String get _shareText =>
      '🚨 SOS dari Aisha! Saya butuh bantuan.\n'
          '📍 Lokasi saya: ${widget.locationLink ?? "-"}\n'
          '_Dikirim via RIHLAH_';

  Future<void> _sendToContact(_Contact contact) async {
    final encoded = Uri.encodeComponent(_shareText);
    final url     = Uri.parse(
        'https://wa.me/${contact.phone}?text=$encoded');
    try {
      final canOpen = await canLaunchUrl(url);
      await launchUrl(
        url,
        mode: canOpen
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
      if (!mounted) return;
      setState(() => _sent.add(contact.phone));
    } catch (_) {
      if (!mounted) return;
      Toast.show(context,
          message: 'Gagal membuka WhatsApp',
          type: ToastType.warning);
    }
  }

  Future<void> _sendViaWhatsApp() async {
    final encoded = Uri.encodeComponent(_shareText);
    final url     = Uri.parse('whatsapp://send?text=$encoded');
    try {
      final canOpen = await canLaunchUrl(url);
      await launchUrl(
        url,
        mode: canOpen
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } catch (_) {
      if (!mounted) return;
      Toast.show(context,
          message: 'WhatsApp tidak tersedia',
          type: ToastType.warning);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    Toast.show(context,
        message: 'Disalin ke clipboard',
        type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagikan lokasi darurat',
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 2),
                if (widget.locationLink != null)
                  Text(widget.locationLink!,
                      style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                else
                  Text('Lokasi tidak tersedia',
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.danger500)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // 3 kontak terbaru
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16),
            child: Row(
              children: _trustedContacts.map((contact) {
                final isSent = _sent.contains(contact.phone);
                return Expanded(
                  child: GestureDetector(
                    onTap: widget.locationLink != null
                        ? () => _sendToContact(contact)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: isSent
                                    ? AppColors.success500
                                    .withOpacity(0.15)
                                    : AppColors.primary100,
                                child: Text(
                                  contact.name[0],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isSent
                                        ? AppColors.success500
                                        : AppColors.primary500,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0, bottom: 0,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF25D366),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSent
                                        ? Icons.check_rounded
                                        : Icons.send_rounded,
                                    size: isSent ? 12 : 10,
                                    color: AppColors.ink0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            contact.name.split(' ').first,
                            style: AppTypography.bodySm.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            contact.lastChat,
                            style: AppTypography.bodySm.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.s16),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: AppSpacing.s12),

          // App row: WhatsApp + Salin
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AppIcon(
                  color: const Color(0xFF25D366),
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  onTap: _sendViaWhatsApp,
                ),
                _AppIcon(
                  color: cs.surfaceContainerHighest,
                  iconColor: cs.onSurface,
                  icon: Icons.copy_rounded,
                  label: 'Salin',
                  onTap: _copyLink,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
  final Color        color;
  final Color?       iconColor;
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.lgAll,
            ),
            child: Icon(icon, size: 26,
                color: iconColor ?? AppColors.ink0),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTypography.bodySm
                  .copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

extension on AppSpacing {
  static const s6 = 6.0;
}