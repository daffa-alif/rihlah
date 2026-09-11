import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/providers/pending_trip_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../data/mock/seed_data.dart';
import '../../../data/models/trip_model.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/utils/fare_calculator.dart';

const _countdownSeconds = 15;

class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen>
    with SingleTickerProviderStateMixin {
  int    _remaining = _countdownSeconds;
  Timer? _timer;
  bool   _deciding  = false;

  MockOrder? _mockOrder;
  TripModel? _realTrip;
  StreamSubscription<TripModel?>? _tripSub;
  late AnimationController _arcCtrl;

  double? _calculatedDistToPickup;

  // Accessors that prefer real trip data, fallback to mock
  String get _pickup      => _realTrip?.pickupAddress  ?? _mockOrder?.pickup  ?? '';
  String get _dropoff     => _realTrip?.dropoffAddress ?? _mockOrder?.dropoff ?? '';
  String get _passenger   => _realTrip?.passengerName  ?? _mockOrder?.passengerName ?? 'Penumpang';
  double get _distKm      => _realTrip?.distanceKm     ?? _mockOrder?.distanceKm ?? 3.0;
  int    get _durMin      => _realTrip?.durationMin    ?? _mockOrder?.durationMin ?? 10;
  double get _distToPickup => _calculatedDistToPickup  ?? _mockOrder?.driverDistanceKm ?? 0.8;
  String get _serviceStr  => _realTrip?.serviceType    ?? _mockOrder?.service ?? 'car';
  int    get _driverEarns => _realTrip?.driverEarns    ??
      FareCalculator.calculate(
        distanceKm : _distKm,
        durationMin: _durMin,
        service    : FareCalculator.parseService(_serviceStr),
      ).driverEarns;
  double? get _passengerRating => _mockOrder?.passengerRating.toDouble();

  @override
  void initState() {
    super.initState();
    _realTrip  = ref.read(pendingTripProvider);
    _mockOrder = _realTrip == null ? getOrder(widget.orderId) : null;
    if (_realTrip != null) {
      _fetchDriverDistance();
      _watchTripAvailability();
    }
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    )..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 3 || _remaining == 1) HapticFeedback.mediumImpact();
      if (_remaining <= 0) _onExpired();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tripSub?.cancel();
    _arcCtrl.dispose();
    super.dispose();
  }

  /// Watches the trip in real time while the driver is deciding — if the
  /// passenger cancels (or another driver somehow claims it) before this
  /// driver accepts, dismiss immediately instead of leaving a dead order on
  /// screen that could still be accepted.
  void _watchTripAvailability() {
    _tripSub = FirestoreService.instance.tripStream(widget.orderId).listen((trip) {
      if (!mounted || _deciding) return;
      if (trip == null || trip.status.name != 'searching') {
        _timer?.cancel();
        _tripSub?.cancel();
        _recordDecision(null);
        context.go(Routes.dHome);
        Toast.show(context,
            message: 'Pesanan sudah tidak tersedia',
            type: ToastType.warning);
      }
    });
  }

  Future<void> _fetchDriverDistance() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final meters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _realTrip!.pickupLat, _realTrip!.pickupLng,
      );
      if (mounted) setState(() => _calculatedDistToPickup = meters / 1000);
    } catch (_) {}
  }

  void _onExpired() {
    _timer?.cancel();
    _tripSub?.cancel();
    if (!mounted) return;
    _recordDecision(null);
    _cascadeToNextDriver();
    context.go(Routes.dHome);
    Toast.show(context, message: 'Order kadaluarsa', type: ToastType.warning);
  }

  void _onPass() {
    if (_deciding) return;
    setState(() => _deciding = true);
    _timer?.cancel();
    _tripSub?.cancel();
    _recordDecision(false);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_realTrip != null && uid != null) {
      // Fire-and-forget: mark this trip skipped by this driver so
      // pendingTripsStream stops re-offering it to them, without blocking
      // navigation. Other drivers can still be offered the trip.
      FirestoreService.instance.skipTrip(widget.orderId, uid).catchError((e) {
        debugPrint('skipTrip failed: $e');
      });
    }

    // Trigger cascade to next driver
    _cascadeToNextDriver();

    context.go(Routes.dHome);
    Toast.show(context,
        message: 'Dispatcher akan mencari driver lain',
        type: ToastType.info);
  }

  /// Fire-and-forget: calls the cascadeOrderExpiry cloud function to offer
  /// this trip to the next eligible driver. Ignored if the trip was already
  /// accepted by another driver (cloud function validates freshness).
  void _cascadeToNextDriver() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final orderId = _realTrip?.tripId ?? widget.orderId;
    // Fire-and-forget: don't await — the cascade runs server-side
    FirebaseFunctions.instance
        .httpsCallable('cascadeOrderExpiry')
        .call(<String, dynamic>{'tripId': orderId})
        .then((_) {})
        // ignore: body_might_complete_normally_catch_error
        .catchError((_) {});
  }

  Future<void> _onAccept() async {
    if (_deciding) return;
    setState(() => _deciding = true);
    _timer?.cancel();
    _tripSub?.cancel();
    HapticFeedback.heavyImpact();

    // Final freshness check — the trip could have been cancelled in the
    // brief gap between the last stream update and this tap.
    if (_realTrip != null) {
      final fresh = await FirestoreService.instance.getTrip(widget.orderId);
      if (fresh == null || fresh.status.name != 'searching') {
        if (!mounted) return;
        _recordDecision(null);
        context.go(Routes.dHome);
        Toast.show(context,
            message: 'Pesanan sudah tidak tersedia',
            type: ToastType.warning);
        return;
      }
    }

    _recordDecision(true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreService.instance.acceptTrip(
          tripId  : widget.orderId,
          driverId: uid,
        );
      } catch (e) {
        debugPrint('acceptTrip failed: $e');
        if (mounted) {
          Toast.show(context,
              message: 'Gagal konfirmasi ke server: $e',
              type: ToastType.warning);
        }
      }
    }

    if (mounted) context.go(Routes.dTrip(widget.orderId));
  }

  String _formatIdr(int v) {
    if (v == 0) return 'Rp 0';
    final s = v.toString();
    final buf = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String get _serviceLabel => switch (_serviceStr) {
    'bike' => 'RIHLAH Motor',
    'send' => 'RIHLAH Kurir',
    _      => 'RIHLAH Mobil',
  };

  bool get _isSend => _serviceStr == 'send';

  Future<void> _recordDecision(bool? isAccept) async {
    final box      = Hive.box('settings');
    final driverId = box.get('active_driver_id',
        defaultValue: 'driver-001') as String;
    final key      = 'accept_rate_$driverId';

    final raw    = (box.get(key) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    raw.insert(0, {
      'orderId'  : widget.orderId,
      'result'   : isAccept == null ? 'auto' : (isAccept ? 'accept' : 'decline'),
      'date'     : DateTime.now().toIso8601String(),
    });

    // Simpan max 200 record terakhir
    await box.put(key, raw.take(200).toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s24, AppSpacing.s32,
              AppSpacing.s24, AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSend) ...[
                const _SendOrderBanner(),
                const SizedBox(height: AppSpacing.s16),
              ],
              Center(child: _CountdownRing(
                  remaining: _remaining, total: _countdownSeconds,
                  controller: _arcCtrl,
                  accentColor: _isSend
                      ? AppColors.accent500 : AppColors.primary500)),
              const SizedBox(height: AppSpacing.s24),
              Center(
                child: Column(children: [
                  Text(
                    _isSend ? 'Pesanan Kirim Barang' : s.incoming_title,
                    style: AppTypography.h1),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${_distToPickup.toStringAsFixed(1)} km ${s.incoming_from_you}',
                    style: AppTypography.bodyMd.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.s24),
              _RouteCard(
                pickup      : _pickup,
                dropoff     : _dropoff,
                distToPickup: _distToPickup,
                distKm      : _distKm,
              ),
              const SizedBox(height: AppSpacing.s12),
              _EarnCard(
                earn        : _formatIdr(_driverEarns),
                distance    : _distKm,
                duration    : _durMin,
                serviceLabel: _serviceLabel,
                passenger   : _passenger,
                rating      : _passengerRating,
                isSend      : _isSend,
              ),
              const Spacer(),
              Row(children: [
                Expanded(flex: 2, child: SizedBox(height: 56,
                  child: OutlinedButton(
                    onPressed: _deciding ? null : _onPass,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    child: Text(s.incoming_pass,
                        style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                )),
                const SizedBox(width: AppSpacing.s12),
                Expanded(flex: 3, child: SizedBox(height: 56,
                  child: ElevatedButton(
                    onPressed: _deciding ? null : _onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.ink0,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    child: Text(s.incoming_accept,
                        style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.ink0)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Send order banner ─────────────────────────────────────────────────────────
// Shown only for RIHLAH Send (package delivery) orders so a driver can tell
// at a glance this isn't a passenger pickup — these go to both car and bike
// drivers, unlike regular rides which are filtered to one vehicle type.

class _SendOrderBanner extends StatelessWidget {
  const _SendOrderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.accent500.withOpacity(0.12),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.accent500, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.accent500),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppColors.ink0, size: 18),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pesanan Kirim Barang',
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent500)),
                Text('Bukan penjemputan penumpang',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.ink500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Countdown ring ────────────────────────────────────────────────────────────

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.remaining,
    required this.total,
    required this.controller,
    this.accentColor = AppColors.primary500,
  });

  final int remaining;
  final int total;
  final AnimationController controller;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              backgroundColor: AppColors.ink100,
              color: AppColors.ink100,
            ),
          ),
          // Animated arc
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final progress = 1.0 - controller.value;
              return SizedBox.expand(
                child: CustomPaint(
                  painter: _ArcPainter(
                    progress: progress,
                    color: remaining <= 3
                        ? AppColors.danger500
                        : accentColor,
                  ),
                ),
              );
            },
          ),
          // Number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remaining',
                style: AppTypography.mono.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: remaining <= 3
                      ? AppColors.danger500
                      : accentColor,
                ),
              ),
              Text('seconds',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.ink500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,                  // start at top
      2 * math.pi * progress,        // sweep
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.dropoff,
    required this.distToPickup,
    required this.distKm,
  });
  final String pickup;
  final String dropoff;
  final double distToPickup;
  final double distKm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          _RouteStop(
            dotColor: AppColors.primary500,
            label   : pickup,
            sublabel: 'Pickup · ${distToPickup.toStringAsFixed(1)} km',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: SizedBox(
              height: 20,
              child: CustomPaint(painter: _DashedLinePainter()),
            ),
          ),
          _RouteStop(
            dotColor: AppColors.danger500,
            label   : dropoff,
            sublabel: 'Drop · ${distKm.toStringAsFixed(1)} km',
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.dotColor,
    required this.label,
    required this.sublabel,
  });
  final Color  dotColor;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: AppSpacing.s12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.bodyMd
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(sublabel,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.ink500)),
          ],
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.ink300
      ..strokeWidth = 1.5;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
          Offset(4, y), Offset(4, y + 3), p);
      y += 5;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Earn card ─────────────────────────────────────────────────────────────────

class _EarnCard extends StatelessWidget {
  const _EarnCard({
    required this.earn,
    required this.distance,
    required this.duration,
    required this.serviceLabel,
    required this.passenger,
    this.rating,
    this.isSend = false,
  });
  final String  earn;
  final double  distance;
  final int     duration;
  final String  serviceLabel;
  final String  passenger;
  final double? rating;
  final bool    isSend;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final badgeColor = isSend ? AppColors.accent500 : AppColors.primary500;
    final badgeBg    = isSend ? AppColors.accent500.withOpacity(0.12)
                               : AppColors.primary100;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isSend ? badgeBg : AppColors.primary100,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.incoming_will_earn,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.ink500)),
                  const SizedBox(height: 2),
                  Text(earn,
                      style: AppTypography.mono.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isSend ? AppColors.accent500 : AppColors.primary600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(color: badgeColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSend) ...[
                          const Icon(Icons.inventory_2_rounded,
                              size: 14, color: AppColors.accent500),
                          const SizedBox(width: 4),
                        ],
                        Text(serviceLabel,
                            style: AppTypography.label
                                .copyWith(color: isSend ? AppColors.accent500 : AppColors.primary600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Passenger name + rating
                  Row(
                    children: [
                      Text(passenger,
                          style: AppTypography.bodySm.copyWith(
                              color: AppColors.ink500,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.accent500),
                      Text(
                          rating != null
                              ? ' ${rating!.toStringAsFixed(1)}'
                              : ' —',
                          style: AppTypography.bodySm.copyWith(
                              color: AppColors.ink500,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          RichText(
            text: TextSpan(
              style: AppTypography.bodyMd
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
              children: [
                TextSpan(text: '${s.incoming_total_trip}: '),
                TextSpan(
                  text: '${distance.toStringAsFixed(1)} km',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '  ·  '),
                TextSpan(
                  text: '$duration min',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}