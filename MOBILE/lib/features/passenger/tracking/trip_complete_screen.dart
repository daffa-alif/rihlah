import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/fare_calculator.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import '../../../core/providers/voucher_provider.dart';

// ── Tag sets by rating ────────────────────────────────────────────────────────

const _tagsPositive = ['Sopan', 'Mobil bersih', 'Perjalanan aman', 'Tahu jalan', 'Tepat waktu'];
const _tagsNeutral  = ['Cukup baik', 'Kecepatan biasa', 'Bisa lebih ramah'];
const _tagsNegative = ['Terlambat', 'Salah rute', 'Tidak sopan', 'Mobil kotor'];

List<String> _tagsForRating(int r) {
  if (r >= 4) return _tagsPositive;
  if (r == 3) return _tagsNeutral;
  return _tagsNegative;
}

// ── Payment method display ──────────────────────────────────────────────────

enum PaymentStatus { cash, processing, paid }

String paymentMethodLabel(String id) => switch (id) {
      'qris'   => 'QRIS',
      'gopay'  => 'GoPay',
      'ovo'    => 'OVO',
      'dana'   => 'DANA',
      'shopee' => 'ShopeePay',
      _        => 'Tunai',
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class TripCompleteScreen extends ConsumerStatefulWidget {
  const TripCompleteScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripCompleteScreen> createState() =>
      _TripCompleteScreenState();
}

class _TripCompleteScreenState extends ConsumerState<TripCompleteScreen>
    with SingleTickerProviderStateMixin {
  int          _rating       = 0;
  final _selectedTags        = <String>{};
  int          _tipAmount    = 0;
  bool         _submitting   = false;
  late AnimationController _celebCtrl;
  late Animation<double>   _celebAnim;

  // Real driver data loaded from Firestore
  TripModel?   _realTrip;
  String       _driverName = '';

  // Payment — cash needs no confirmation step; e-wallet/QRIS runs a brief
  // simulated processing step so "payment completed" is an actual moment,
  // not just silently assumed.
  PaymentStatus _paymentStatus = PaymentStatus.cash;

  String get _paymentMethodId =>
      _realTrip?.paymentMethod ?? ref.read(tripBookingProvider).paymentMethod;
  bool get _isCashPayment => _paymentMethodId == 'cash';

  String _fmt(int v) {
    final s      = v.toString();
    final buf    = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebAnim =
        CurvedAnimation(parent: _celebCtrl, curve: Curves.elasticOut);
    _celebCtrl.forward();
    _loadTripAndDriver();
  }

  Future<void> _loadTripAndDriver() async {
    final trip = await FirestoreService.instance.getTrip(widget.tripId);
    if (!mounted || trip == null) return;
    setState(() => _realTrip = trip);

    if (trip.paymentMethod != 'cash') {
      _processDigitalPayment();
    }

    if (trip.driverId != null) {
      final user = await FirestoreService.instance.getUser(trip.driverId!);
      if (mounted && user != null) {
        setState(() => _driverName = user.name);
      }
    }
  }

  /// Simulated e-wallet/QRIS charge — no real payment gateway is wired up,
  /// so this just gives digital payment an actual "processing → paid"
  /// moment instead of silently treating it the same as cash.
  Future<void> _processDigitalPayment() async {
    setState(() => _paymentStatus = PaymentStatus.processing);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _paymentStatus = PaymentStatus.paid);
  }

  @override
  void dispose() {
    _celebCtrl.dispose();
    super.dispose();
  }

  void _onStarTap(int star) {
    setState(() {
      _rating = star;
      _selectedTags.clear();
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _onTipSelect(int amount) {
    setState(() => _tipAmount = _tipAmount == amount ? 0 : amount);
  }

  void _onCustomTip() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: AppSpacing.s24,
          right: AppSpacing.s24,
          top: AppSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nominal tip', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            RihlahButton(
              label: 'Tambahkan',
              onPressed: () {
                final v = int.tryParse(ctrl.text) ?? 0;
                setState(() => _tipAmount = v);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({bool skip = false}) async {
    final trip   = ref.read(tripBookingProvider);
    final km     = trip.hasRoute ? trip.route.distanceKm : 3.2;
    final fare   = FareCalculator.calculate(
      distanceKm: km,
      service   : trip.service,
    );
    final discount = trip.appliedDiscount;
    final totalAfterDiscount = (fare.totalFare - discount).clamp(0, 999999);
    if (trip.appliedVoucherCode != null) {
      await ref.read(voucherProvider.notifier)
          .markAsUsed(trip.appliedVoucherCode!);
    }

    setState(() => _submitting = true);

    final box     = Hive.box('settings');
    final history = List<Map<String, dynamic>>.from(
      (box.get('trip_history') as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    history.insert(0, {
      'tripId'  : widget.tripId,
      'rating'  : skip ? 0 : _rating,
      'tags'    : _selectedTags.toList(),
      'tip'     : _tipAmount,
      'date'    : DateTime.now().toIso8601String(),
      'pickup'  : _realTrip?.pickupAddress ?? trip.pickupName,
      'dropoff' : _realTrip?.dropoffAddress ?? trip.dropoffName,
      'status'  : 'completed',
      'service' : trip.service.name,
      'driver'  : _driverName,
      'fare'    : totalAfterDiscount,
      'discount': discount,
      'km'      : _realTrip?.distanceKm ?? km,
      'duration': _realTrip?.durationMin ?? fare.durationMin,
    });
    await box.put('trip_history', history);

    // Persist rating to Firestore (best-effort).
    // Driver already called completeTrip, so passenger only submits the rating.
    try {
      await FirestoreService.instance.rateTrip(
        tripId : widget.tripId,
        rating : skip ? 0 : _rating,
        tip    : _tipAmount,
        review : _selectedTags.join(', '),
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    context.go(Routes.pHome);
    Toast.show(context,
        message: 'Terima kasih sudah naik RIHLAH!',
        type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final s    = AppLocalizations.of(context);
    final trip = ref.watch(tripBookingProvider);
    final int totalAfterDiscount;
    if (_realTrip != null) {
      totalAfterDiscount = (_realTrip!.totalFare - trip.appliedDiscount)
          .clamp(0, 999999);
    } else {
      final km = trip.hasRoute ? trip.route.distanceKm : 3.2;
      final fare = FareCalculator.calculate(
        distanceKm: km,
        service   : trip.service,
      );
      totalAfterDiscount = (fare.totalFare - trip.appliedDiscount)
          .clamp(0, 999999);
    }
    final tags = _rating > 0 ? _tagsForRating(_rating) : <String>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s32),

                    // ── Celebration icon ──────────────────────
                    ScaleTransition(
                      scale: _celebAnim,
                      child: Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.primary100,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🎉',
                              style: TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // ── Arrived heading ─────────────────────
                    Text(s.complete_arrived, style: AppTypography.h1),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      trip.dropoffName.isNotEmpty
                          ? trip.dropoffName
                          : 'Tujuan',
                      style: AppTypography.bodyMd.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Fare card ────────────────────────────
                    _FareCard(
                      fare        : _fmt(totalAfterDiscount),
                      driverName  : _driverName.isNotEmpty ? _driverName : 'Driver',
                      paymentLabel: paymentMethodLabel(_paymentMethodId),
                      status      : _isCashPayment
                          ? PaymentStatus.cash : _paymentStatus,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // ── Rating card ──────────────────────────
                    _RatingCard(
                      driverName  : _driverName.isNotEmpty ? _driverName : 'Driver',
                      rating      : _rating,
                      tags        : tags,
                      selectedTags: _selectedTags,
                      onStarTap   : _onStarTap,
                      onTagTap    : _toggleTag,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // ── Tip section ──────────────────────────
                    _TipSection(
                      selected: _tipAmount,
                      onSelect: _onTipSelect,
                      onCustom: _onCustomTip,
                    ),
                    const SizedBox(height: AppSpacing.s32),
                  ],
                ),
              ),
            ),

            // ── Bottom CTAs ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24, AppSpacing.s8,
                AppSpacing.s24, AppSpacing.s16,
              ),
              child: Column(
                children: [
                  RihlahButton(
                    label: _submitting
                        ? 'Menyimpan…'
                        : s.complete_submit,
                    isLoading: _submitting,
                    onPressed: _rating > 0 ? () => _submit() : null,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextButton(
                    onPressed:
                        _submitting ? null : () => _submit(skip: true),
                    child: Text(s.complete_skip,
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.ink500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fare card ─────────────────────────────────────────────────────────────────

class _FareCard extends StatelessWidget {
  const _FareCard({
    required this.fare,
    required this.driverName,
    required this.paymentLabel,
    required this.status,
  });
  final String        fare;
  final String        driverName;
  final String        paymentLabel;
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s24, horizontal: AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Text(s.complete_you_paid,
              style: AppTypography.bodySm
                  .copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          Text(fare,
              style: AppTypography.mono.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              )),
          const SizedBox(height: AppSpacing.s8),
          switch (status) {
            PaymentStatus.cash => Text(
                '${s.complete_cash_to} $driverName',
                style: AppTypography.bodySm
                    .copyWith(color: cs.onSurfaceVariant)),
            PaymentStatus.processing => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary500),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text('Memproses pembayaran via $paymentLabel…',
                      style: AppTypography.bodySm
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            PaymentStatus.paid => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success500.withOpacity(0.12),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.success500),
                    const SizedBox(width: 4),
                    Text('Dibayar via $paymentLabel',
                        style: AppTypography.bodySm.copyWith(
                            color: AppColors.success500,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          },
        ],
      ),
    );
  }
}

// ── Rating card ───────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.driverName,
    required this.rating,
    required this.tags,
    required this.selectedTags,
    required this.onStarTap,
    required this.onTagTap,
  });
  final String               driverName;
  final int                  rating;
  final List<String>         tags;
  final Set<String>          selectedTags;
  final ValueChanged<int>    onStarTap;
  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          // Driver avatar
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary500,
            ),
            child: Center(
              child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                  style: const TextStyle(
                      color: AppColors.ink0,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(driverName.isNotEmpty ? driverName.split(' ').first : 'Driver',
              style: AppTypography.bodyLg
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.s4),
          Text(s.complete_rate_driver,
              style: AppTypography.h3),
          const SizedBox(height: AppSpacing.s16),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onStarTap(star);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      rating >= star
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      key: ValueKey('$star-${rating >= star}'),
                      size: 44,
                      color: rating >= star
                          ? AppColors.accent500
                          : AppColors.ink300,
                    ),
                  ),
                ),
              );
            }),
          ),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                alignment: WrapAlignment.center,
                children: tags.map((tag) {
                  final selected = selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => onTagTap(tag),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary100
                            : cs.surface,
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary500
                              : cs.outline,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(tag,
                          style: AppTypography.bodyMd.copyWith(
                            color: selected
                                ? AppColors.primary600
                                : cs.onSurface,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tip section ───────────────────────────────────────────────────────────────

class _TipSection extends StatelessWidget {
  const _TipSection({
    required this.selected,
    required this.onSelect,
    required this.onCustom,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustom;
  static const _presets = [2000, 5000, 10000];

  String _label(int v) {
    if (v >= 1000) return 'Rp\n${v ~/ 1000}k';
    return 'Rp\n$v';
  }

  @override
  Widget build(BuildContext context) {
    final s  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.complete_add_tip,
            style: AppTypography.bodyLg
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            ..._presets.map((amount) {
              final isSelected = selected == amount;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s8),
                  child: GestureDetector(
                    onTap: () => onSelect(amount),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary100
                            : cs.surface,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary500
                              : cs.outline,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(_label(amount),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary600
                                  : cs.onSurface,
                              height: 1.3,
                            )),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Custom
            Expanded(
              child: GestureDetector(
                onTap: onCustom,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 56,
                  decoration: BoxDecoration(
                    color: (selected > 0 &&
                            !_presets.contains(selected))
                        ? AppColors.primary100
                        : cs.surface,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: (selected > 0 &&
                              !_presets.contains(selected))
                          ? AppColors.primary500
                          : cs.outline,
                      width: (selected > 0 &&
                              !_presets.contains(selected))
                          ? 2
                          : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      selected > 0 && !_presets.contains(selected)
                          ? 'Rp\n${selected ~/ 1000}k'
                          : 'Custom',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}