import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/fare_calculator.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';

const _dagoCenter = LatLng(-6.8750, 107.6175);

class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key});

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with TickerProviderStateMixin {
  final _mapCtrl = MapController();
  bool _mapCentered = true;

  late AnimationController _pulse1;
  late AnimationController _pulse2;
  late AnimationController _pulse3;

  int    _subtitleIndex  = 0;
  int    _timeoutSeconds = 90;
  Timer? _subtitleTimer;
  Timer? _timeoutTimer;
  bool   _cancelling = false;

  String? _tripId;
  StreamSubscription? _tripSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initPulse();
    _startSubtitleRotation();
    _startTimeoutCountdown();
    _createTrip();
  }

  void _initPulse() {
    _pulse1 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _pulse2 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _pulse3 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    Future.delayed(const Duration(milliseconds: 800),  () { if (mounted) _pulse2.forward(from: 0.33); });
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) _pulse3.forward(from: 0.66); });
  }

  void _startSubtitleRotation() {
    _subtitleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _subtitleIndex = (_subtitleIndex + 1) % 3);
    });
  }

  void _startTimeoutCountdown() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeoutSeconds--);
      if (_timeoutSeconds <= 0) {
        _timeoutTimer?.cancel();
        _onNoDriverFound();
      }
    });
  }

  void _onNoDriverFound() {
    if (!mounted) return;
    if (_tripId != null) {
      FirestoreService.instance.cancelTrip(_tripId!,
          cancelledBy: 'passenger');
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NoDriverDialog(
        onTryAgain: () {
          Navigator.pop(context);
          setState(() {
            _timeoutSeconds = 90;
            _tripId = null;
          });
          _tripSub?.cancel();
          _pollTimer?.cancel();
          _startTimeoutCountdown();
          _createTrip();
        },
        onCancel: () {
          Navigator.pop(context);
          context.go(Routes.pHome);
        },
      ),
    );
  }

  Future<void> _createTrip() async {
    final trip = ref.read(tripBookingProvider);
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    final km          = trip.hasRoute ? trip.route.distanceKm : 3.2;
    final durationMin = trip.hasRoute ? trip.route.durationMin : 8;
    final devSurge    = ref.read(devSettingsProvider).surgePricing;
    final rcEnabled   = FirebaseRemoteConfig.instance.getBool('enable_surge');
    final surge       = FareCalculator.surgeMultiplier(
      devSurgeEnabled: devSurge,
      remoteConfigEnabled: rcEnabled,
    );
    final fareResult  = FareCalculator.calculate(
      distanceKm: km,
      service   : trip.service,
      surge     : surge,
    );
    final totalFare  = (fareResult.totalFare - trip.appliedDiscount)
        .clamp(0, 999999) as int;
    final platformFee = (totalFare * 0.05).round();
    final driverEarns = totalFare - platformFee;

    final paymentMethod = trip.paymentMethod;

    final serviceType = switch (trip.service) {
      RihlahService.car  => 'car',
      RihlahService.bike => 'bike',
      RihlahService.send => 'send',
    };

    final userProfile = await FirestoreService.instance.getUser(uid);

    // SRS P-S6: exclude drivers the passenger previously rated 1 star
    final oneStarDriverIds =
        await FirestoreService.instance.getOneStarDriverIds(uid);

    try {
      final tripId = await FirestoreService.instance.createTrip({
        'passengerId': uid,
        'serviceType': serviceType,
        'pickupLat'  : trip.pickupLatLng?.latitude  ?? 0.0,
        'pickupLng'  : trip.pickupLatLng?.longitude ?? 0.0,
        'dropoffLat' : trip.dropoffLatLng?.latitude  ?? 0.0,
        'dropoffLng' : trip.dropoffLatLng?.longitude ?? 0.0,
        'pickupAddress'  : trip.pickupName,
        'dropoffAddress' : trip.dropoffName,
        'distanceKm'  : km,
        'durationMin' : durationMin,
        'totalFare'   : totalFare,
        'platformFee' : platformFee,
        'driverEarns' : driverEarns,
        'paymentMethod': paymentMethod,
        'status'      : 'searching',
        'passengerName' : userProfile?.name ?? 'Pengguna RIHLAH',
        'passengerPhone': userProfile?.phone ?? '',
        if (oneStarDriverIds.isNotEmpty) 'skippedBy': oneStarDriverIds,
        if (surge > 1.0) 'surgeMultiplier': surge,
        if (trip.appliedDiscount > 0) 'appliedDiscount': trip.appliedDiscount,
        if (trip.appliedVoucherCode != null)
          'appliedVoucherCode': trip.appliedVoucherCode,
        if (trip.note != null && trip.note!.isNotEmpty)
          'note': trip.note,
        'createdAt'   : FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _tripId = tripId);

      _tripSub = FirestoreService.instance.tripStream(tripId).listen((model) {
        if (!mounted || model == null || _cancelling) return;
        if (model.driverId != null &&
            model.status.name != 'searching' &&
            model.status.name != 'cancelled') {
          _pollTimer?.cancel();
          _tripSub?.cancel();
          _timeoutTimer?.cancel();
          context.go(Routes.pTrip(tripId));
        }
      });

      // Poll every 5 s as a fallback in case the realtime stream misses an update
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted || _cancelling) return;
        try {
          final trip = await FirestoreService.instance.getTrip(tripId);
          if (trip == null) return;
          if (trip.driverId != null &&
              trip.status.name != 'searching' &&
              trip.status.name != 'cancelled') {
            _pollTimer?.cancel();
            _tripSub?.cancel();
            _timeoutTimer?.cancel();
            if (mounted) context.go(Routes.pTrip(tripId));
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: 'Gagal membuat pesanan. Periksa koneksi.',
            type: ToastType.danger);
      }
    }
  }

  void _recenter(LatLng center) {
    _mapCtrl.move(center, 14);
    setState(() => _mapCentered = true);
  }

  void _onCancelTap() {
    setState(() => _cancelling = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CancelSheet(
        onConfirm: () {
          _tripSub?.cancel();
          _pollTimer?.cancel();
          _timeoutTimer?.cancel();
          if (_tripId != null) {
            FirestoreService.instance.cancelTrip(_tripId!,
                cancelledBy: 'passenger');
          }
          Navigator.pop(context);
          context.go(Routes.pHome);
          Toast.show(context, message: 'Pesanan dibatalkan',
              type: ToastType.info);
        },
        onKeep: () {
          setState(() => _cancelling = false);
          Navigator.pop(context);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _cancelling = false);
    });
  }

  @override
  void dispose() {
    _pulse1.dispose();
    _pulse2.dispose();
    _pulse3.dispose();
    _subtitleTimer?.cancel();
    _timeoutTimer?.cancel();
    _tripSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip   = ref.watch(tripBookingProvider);
    final center = trip.pickupLatLng ?? _dagoCenter;

    // Real fare from provider
    final km         = trip.hasRoute ? trip.route.distanceKm : 3.2;
    final fareResult = FareCalculator.calculate(
      distanceKm: km,
      service   : trip.service,
    );
    final totalAfterDiscount = (fareResult.totalFare - trip.appliedDiscount)
        .clamp(0, 999999);
    final fareFormatted = _fmtIdr(totalAfterDiscount);

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen interactive map ───────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _mapCentered) {
                    setState(() => _mapCentered = false);
                  }
                },
              ),
              children: [
                RihlahCachedTileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rihlah',
                  tileBuilder: _tintTile,
                ),
                MarkerLayer(markers: [
                  // Radar rings
                  Marker(
                    point: center,
                    width: 280, height: 280,
                    child: _RadarRings(
                        pulse1: _pulse1,
                        pulse2: _pulse2,
                        pulse3: _pulse3),
                  ),
                  // User dot
                  Marker(
                    point: center,
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.info500,
                        border: Border.all(
                            color: AppColors.ink0, width: 3),
                        boxShadow: AppElevation.card,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // ── Recenter button ───────────────────────────
          if (!_mapCentered)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSpacing.s12,
              right: AppSpacing.s16,
              child: _MapBtn(
                onTap: () => _recenter(center),
                child: const Icon(Icons.my_location_rounded,
                    size: 20, color: AppColors.primary500),
              ),
            ),

          // ── Bottom panel ──────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              subtitleIndex  : _subtitleIndex,
              dropoffName    : trip.dropoffName.isNotEmpty
                  ? trip.dropoffName : 'Tujuan',
              fareFormatted  : fareFormatted,
              serviceLabel   : _serviceLabel(trip.service, context),
              timeoutSeconds : _timeoutSeconds,
              onCancel       : _onCancelTap,
            ),
          ),
        ],
      ),
    );
  }

  String _serviceLabel(RihlahService service, BuildContext context) {
    final s = AppLocalizations.of(context);
    return switch (service) {
      RihlahService.car  => s.services_car,
      RihlahService.bike => s.services_bike,
      RihlahService.send => s.services_send,
    };
  }

  String _fmtIdr(int v) {
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

// ── Radar rings ───────────────────────────────────────────────────────────────

class _RadarRings extends StatelessWidget {
  const _RadarRings({
    required this.pulse1,
    required this.pulse2,
    required this.pulse3,
  });
  final AnimationController pulse1, pulse2, pulse3;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      _Ring(controller: pulse1),
      _Ring(controller: pulse2),
      _Ring(controller: pulse3),
    ],
  );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t       = controller.value;
        final size    = 40.0 + t * 240.0;
        final opacity = (1 - t) * 0.35;
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary500.withOpacity(opacity),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.subtitleIndex,
    required this.dropoffName,
    required this.fareFormatted,
    required this.serviceLabel,
    required this.timeoutSeconds,
    required this.onCancel,
  });

  final int    subtitleIndex;
  final String dropoffName;
  final String fareFormatted;
  final String serviceLabel;
  final int    timeoutSeconds;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final subtitles = [
      s.searchingLooking,
      s.searchingAlmost,
      s.searchingHang,
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
        boxShadow: AppElevation.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Status row
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary500, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Text(
                            subtitles[subtitleIndex],
                            key: ValueKey(subtitleIndex),
                            style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface),
                          ),
                        ),
                        Text(s.searchingMatching,
                            style: AppTypography.bodySm
                                .copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s16),

              // Timeout countdown bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mencari driver…',
                          style: AppTypography.bodySm
                              .copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        '${timeoutSeconds}s',
                        style: AppTypography.mono.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: timeoutSeconds <= 15
                              ? AppColors.danger500
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: timeoutSeconds / 90,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        timeoutSeconds <= 15
                            ? AppColors.danger500
                            : AppColors.primary500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Trip summary row — real data
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dropoffName · ${s.confirm_payment}',
                          style: AppTypography.bodySm
                              .copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fareFormatted,
                          style: AppTypography.mono.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(serviceLabel,
                        style: AppTypography.label
                            .copyWith(color: AppColors.primary600)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outline),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll),
                  ),
                  child: Text(s.searchingCancel,
                      style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cancel sheet ──────────────────────────────────────────────────────────────

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.onConfirm, required this.onKeep});
  final VoidCallback onConfirm;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.cancelOrderTitle, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            Text(s.cancelOrderBody,
                style: AppTypography.bodyMd
                    .copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(
              label: s.cancelYes,
              variant: RihlahButtonVariant.danger,
              onPressed: onConfirm,
            ),
            const SizedBox(height: AppSpacing.s12),
            RihlahButton(
              label: s.cancelKeep,
              variant: RihlahButtonVariant.secondary,
              onPressed: onKeep,
            ),
          ],
        ),
      ),
    );
  }
}

// ── No driver dialog ──────────────────────────────────────────────────────────

class _NoDriverDialog extends StatelessWidget {
  const _NoDriverDialog({
    required this.onTryAgain,
    required this.onCancel,
  });
  final VoidCallback onTryAgain;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger500.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:  Icon(Icons.car_crash_rounded,
                  color: AppColors.danger500, size: 32),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('Tidak ada driver',
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Tidak ada driver yang tersedia dalam 90 detik. '
              'Coba lagi atau batalkan pesanan.',
              style: AppTypography.bodyMd
                  .copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(
              label: 'Coba lagi',
              onPressed: onTryAgain,
            ),
            const SizedBox(height: AppSpacing.s8),
            RihlahButton(
              label: 'Batalkan pesanan',
              variant: RihlahButtonVariant.secondary,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map button ────────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget       child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: AppElevation.card,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Tile tint ─────────────────────────────────────────────────────────────────

Widget _tintTile(BuildContext ctx, Widget tile, TileImage ti) =>
    ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.85, 0.02, 0.02, 0, 5,
        0.00, 0.90, 0.02, 0, 5,
        0.00, 0.04, 0.78, 0, 8,
        0.00, 0.00, 0.00, 1, 0,
      ]),
      child: tile,
    );

extension on AppSpacing {
  static const s12 = 12.0;
}