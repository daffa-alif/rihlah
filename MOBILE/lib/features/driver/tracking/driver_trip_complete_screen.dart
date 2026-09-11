import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../core/utils/fare_calculator.dart';
import '../../../core/utils/driver_receipt_share.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';

class DriverTripCompleteScreen extends StatefulWidget {
  const DriverTripCompleteScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<DriverTripCompleteScreen> createState() =>
      _DriverTripCompleteScreenState();
}

class _DriverTripCompleteScreenState
    extends State<DriverTripCompleteScreen>
    with SingleTickerProviderStateMixin {

  bool _marking    = false;
  bool _showSplash = false;
  bool _loading    = true;

  TripModel? _trip;
  late AnimationController _splashCtrl;
  late Animation<double>   _splashScale;

  int    _discount  = 0;

  // Shortcut getters — fall back gracefully if trip hasn't loaded yet
  String get _pickup       => _trip?.pickupAddress  ?? '';
  String get _dropoff      => _trip?.dropoffAddress ?? '';
  String get _passengerName => _trip?.passengerName ?? 'Penumpang';
  double get _distanceKm   => _trip?.distanceKm   ?? 0;
  int    get _durationMin  => _trip?.durationMin  ?? 0;
  String get _serviceType  => _trip?.serviceType  ?? 'car';
  int    get _totalFare    => _trip?.totalFare    ?? 0;
  int    get _driverEarns  => _trip?.driverEarns  ?? 0;
  int    get _platformCut  => _totalFare - _driverEarns - _discount;

  String get _serviceLabel => switch (_serviceType) {
    'bike' => 'RIHLAH Motor',
    'send' => 'RIHLAH Kurir',
    _      => 'RIHLAH Mobil',
  };

  String get _paymentMethodId => _trip?.paymentMethod ?? 'cash';
  bool   get _isCashPayment   => _paymentMethodId == 'cash';
  String get _paymentLabel => switch (_paymentMethodId) {
    'qris'   => 'QRIS',
    'gopay'  => 'GoPay',
    'ovo'    => 'OVO',
    'dana'   => 'DANA',
    'shopee' => 'ShopeePay',
    _        => 'Tunai',
  };

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _splashScale = CurvedAnimation(
        parent: _splashCtrl, curve: Curves.elasticOut);
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final trip = await FirestoreService.instance.getTrip(widget.tripId);
    if (!mounted) return;
    setState(() {
      _trip    = trip;
      _loading = false;
    });
    _loadDiscountFromHive();
  }

  void _loadDiscountFromHive() {
    final box     = Hive.box('settings');
    final history = (box.get('trip_history') as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final match = history.firstWhere(
      (m) => m['tripId']?.toString() == widget.tripId,
      orElse: () => <String, dynamic>{},
    );
    if (match.isNotEmpty) {
      setState(() => _discount = (match['discount'] as num?)?.toInt() ?? 0);
    }
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    super.dispose();
  }

  String _fmt(int v) => FareCalculator.fmtIdr(v);

  void _onShare() {
    DriverReceiptShare.share(
      context          : context,
      tripId           : widget.tripId,
      pickup           : _pickup,
      dropoff          : _dropoff,
      passengerName    : _passengerName,
      distanceKm       : _distanceKm,
      durationMin      : _durationMin,
      fareAfterDiscount: (_totalFare - _discount).clamp(0, 999999),
      driverEarns      : _driverEarns,
      platformCut      : _platformCut,
      service          : _serviceType,
      date             : DateTime.now(),
      discount         : _discount > 0 ? _discount : null,
    );
  }

  Future<void> _onMarkPaid() async {
    if (_marking) return;
    setState(() => _marking = true);
    HapticFeedback.mediumImpact();

    // Simpan ke driver history per driver
    final box      = Hive.box('settings');
    final driverId = FirebaseAuth.instance.currentUser?.uid
        ?? box.get('active_driver_id', defaultValue: '') as String;
    final historyKey = 'driver_history_$driverId';

    final history = (box.get(historyKey) as List? ?? [])
        .cast<Map>().toList();

    final fareAfterDiscount = (_totalFare - _discount).clamp(0, 999999);
    history.insert(0, {
      'tripId'   : widget.tripId,
      'date'     : DateTime.now().toIso8601String(),
      'pickup'   : _pickup,
      'dropoff'  : _dropoff,
      'fare'     : fareAfterDiscount,
      'discount' : _discount,
      'earn'     : _driverEarns,
      'platform' : _platformCut,
      'tips'     : 0,
      'km'       : _distanceKm,
      'duration' : _durationMin,
      'service'  : _serviceType,
      'passenger': _passengerName,
      'status'   : 'completed',
    });
    await box.put(historyKey, history);

    // Update pendapatan hari ini (tidak dipakai lagi, tapi tetap simpan untuk kompatibilitas)
    final earnKey = 'driver_today_earn_$driverId';
    final prev    = (box.get(earnKey) as num?)?.toInt() ?? 0;
    await box.put(earnKey, prev + _driverEarns);

    // Driver-side completion previously only happened on the passenger's
    // rating screen — if they abandon the app before rating, the trip stayed
    // stuck at `inTrip` in Firestore forever. Complete it here too so
    // Firestore-backed earnings/history are reliable regardless of which
    // side finishes first (completeTrip is idempotent to call twice).
    if (_trip?.status.name != 'completed') {
      try {
        await FirestoreService.instance.completeTrip(widget.tripId);
      } catch (e) {
        debugPrint('completeTrip failed: $e');
      }
    }

    // Cek referral milestone — bonus otomatis jika invitee mencapai 20 trip
    await ReferralService.instance.onInviteeTripCompleted(driverId);

    // Success splash
    setState(() => _showSplash = true);
    _splashCtrl.forward();
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    context.go(Routes.dHome);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.s32),

                        // Header icon
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: AppRadius.lgAll,
                          ),
                          child: Icon(
                              _isCashPayment
                                  ? Icons.payments_rounded
                                  : Icons.check_circle_rounded,
                              color: AppColors.ink0, size: 34),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                            _isCashPayment
                                ? s.collect_title
                                : 'Pembayaran diterima',
                            style: AppTypography.h1),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Perjalanan selesai di $_dropoff',
                          style: AppTypography.bodyMd.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.s24),

                        // Fare card
                        _FareCard(
                          fare        : _fmt((_totalFare - _discount).clamp(0, 999999)),
                          paymentLabel: _paymentLabel,
                          isCash      : _isCashPayment,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Passenger card
                        _PassengerCard(
                          passengerName: _passengerName,
                          durationMin  : _durationMin,
                          distanceKm   : _distanceKm,
                          serviceLabel : _serviceLabel,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Earnings breakdown
                        _EarningsBreakdown(
                          fare           : _fmt(_totalFare),
                          discount       : _discount > 0
                              ? _fmt(_discount) : null,
                          fareFinal      : _fmt((_totalFare - _discount).clamp(0, 999999)),
                          fee            : _fmt(_platformCut),
                          earnings       : _fmt(_driverEarns),
                        ),
                        const SizedBox(height: AppSpacing.s32),
                      ],
                    ),
                  ),
                ),

                // CTA
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s24, AppSpacing.s8,
                    AppSpacing.s24,
                    AppSpacing.s16 +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RihlahButton(
                        label: _marking
                            ? s.collect_saving
                            : (_isCashPayment
                                ? s.collect_mark_paid : 'Lanjutkan'),
                        isLoading: _marking,
                        onPressed: _onMarkPaid,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _onShare,
                          icon: const Text('💬',
                              style: TextStyle(fontSize: 16)),
                          label: const Text('Bagikan via WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF25D366),
                            side: const BorderSide(
                                color: Color(0xFF25D366)),
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.mdAll),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Success splash
          if (_showSplash)
            Positioned.fill(
              child: Container(
                color: AppColors.primary500,
                child: Center(
                  child: ScaleTransition(
                    scale: _splashScale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉',
                            style: TextStyle(fontSize: 64)),
                        const SizedBox(height: AppSpacing.s16),
                        Text(s.collect_earned,
                            style: AppTypography.bodyLg.copyWith(
                                color: AppColors.ink0
                                    .withOpacity(0.8))),
                        Text(
                          _fmt(_driverEarns),
                          style: AppTypography.mono.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Fare card ─────────────────────────────────────────────────────────────────

class _FareCard extends StatelessWidget {
  const _FareCard({
    required this.fare,
    required this.paymentLabel,
    required this.isCash,
  });
  final String fare;
  final String paymentLabel;
  final bool   isCash;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s24,
          horizontal: AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Text(s.collect_total_fare,
              style: AppTypography.bodySm
                  .copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          Text(fare,
              style: AppTypography.mono.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface)),
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              color: isCash
                  ? AppColors.accent100
                  : AppColors.success500.withOpacity(0.12),
              borderRadius: AppRadius.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isCash
                        ? Icons.payments_rounded
                        : Icons.check_circle_rounded,
                    size: 14,
                    color: isCash
                        ? AppColors.accent500 : AppColors.success500),
                const SizedBox(width: AppSpacing.s8),
                Text(
                    isCash
                        ? s.collect_cash
                        : 'Sudah dibayar via $paymentLabel',
                    style: AppTypography.label.copyWith(
                        color: isCash
                            ? AppColors.accent500
                            : AppColors.success500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Passenger card ────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({
    required this.passengerName,
    required this.durationMin,
    required this.distanceKm,
    required this.serviceLabel,
  });
  final String passengerName;
  final int    durationMin;
  final double distanceKm;
  final String serviceLabel;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final initial = passengerName.isNotEmpty ? passengerName[0] : 'P';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent500),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: AppColors.ink0,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passengerName,
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '$durationMin min · '
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: AppTypography.bodySm
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
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
    );
  }
}

// ── Earnings breakdown ────────────────────────────────────────────────────────

class _EarningsBreakdown extends StatelessWidget {
  const _EarningsBreakdown({
    required this.fare,
    required this.discount,
    required this.fareFinal,
    required this.fee,
    required this.earnings,
  });
  final String  fare;
  final String? discount;
  final String  fareFinal;
  final String  fee;
  final String  earnings;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line(label: 'Tarif perjalanan', value: fare),
        if (discount != null) ...[
          const SizedBox(height: AppSpacing.s8),
          _Line(
            label: 'Diskon voucher penumpang',
            value: '-$discount',
            valueColor: AppColors.primary500,
          ),
          const SizedBox(height: AppSpacing.s8),
          _Line(label: s.collect_total_fare, value: fareFinal),
        ],
        const SizedBox(height: AppSpacing.s8),
        _Line(
          label: s.collect_platform_fee,
          value: '-$fee',
          valueColor: AppColors.danger500,
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.collect_your_earn,
                style: AppTypography.bodyLg
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(earnings,
                style: AppTypography.mono.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary600)),
          ],
        ),
      ],
    );
  }
}


class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.bodyMd
                  .copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        Text(value,
            style: AppTypography.mono.copyWith(
                fontSize: 13,
                color: valueColor ?? cs.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}