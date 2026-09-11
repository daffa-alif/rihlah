import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import '../../../core/utils/receipt_image.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Map<String, dynamic>? _trip;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final box     = Hive.box('settings');
    final history = (box.get('trip_history') as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final match = history.where((m) => m['tripId'] == widget.tripId).firstOrNull;

    if (match != null) {
      setState(() => _trip = match);
      return;
    }

    try {
      final trip = await FirestoreService.instance.getTrip(widget.tripId);
      if (trip == null || !mounted) return;

      var driverName = '-'; // Default mock name
      var driverPlate = '-';
      if (trip.driverId != null) {
        final profile = await FirestoreService.instance.getUser(trip.driverId!);
        if (profile != null) {
          if (profile.name.isNotEmpty && profile.name != 'Pengguna RIHLAH') driverName = profile.name;
          if (profile.plate != null && profile.plate!.isNotEmpty) {
            driverPlate = profile.plate!;
          }
        }
      }

      if (!mounted) return;
      final date = (trip.completedAt ?? trip.createdAt)?.toDate() ?? DateTime.now();

      setState(() => _trip = {
        'tripId'  : trip.tripId,
        'pickup'  : trip.pickupAddress,
        'dropoff' : trip.dropoffAddress,
        'fare'    : trip.totalFare,
        'discount': trip.appliedDiscount ?? 0,
        'tip'     : trip.passengerTip ?? 0,
        'rating'  : trip.passengerRating ?? 5,
        'service' : trip.serviceType,
        'driver'  : driverName,
        'plate'   : driverPlate,
        'km'      : trip.distanceKm,
        'duration': trip.durationMin,
        'status'  : trip.status.name,
        'date'    : date.toIso8601String(),
        'tags'    : (trip.passengerReview ?? '').split(', ').where((s) => s.isNotEmpty).toList(),
      });
    } catch (_) {
      // Biarkan _trip null agar loading berputar
    }
  }

  Future<void> _shareReceipt() async {
    final trip = _trip!;
    await ReceiptImage.shareReceipt(
      context    : context,
      tripId     : widget.tripId,
      pickup     : trip['pickup']?.toString()  ?? '-',
      dropoff    : trip['dropoff']?.toString() ?? '-',
      fare       : (trip['fare']     as num?)?.toInt() ?? 0,
      discount   : (trip['discount'] as num?)?.toInt() ?? 0,
      tip        : (trip['tip']      as num?)?.toInt() ?? 0,
      service    : trip['service']?.toString() ?? 'car',
      driver     : trip['driver']?.toString()  ?? 'Budi Santoso',
      km         : (trip['km']       as num?)?.toDouble() ?? 3.0,
      durationMin: (trip['duration'] as num?)?.toInt() ?? 10,
      date       : DateTime.tryParse(trip['date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary500), onPressed: () => context.pop()),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }

    final trip     = _trip!;
    final fare     = (trip['fare'] as num?)?.toInt() ?? 0;
    final rating   = (trip['rating'] as num?)?.toInt() ?? 5;
    final driver   = trip['driver']?.toString() ?? 'Budi Santoso';
    final plate    = trip['plate']?.toString() ?? 'B 1234 XYZ';
    final pickup   = trip['pickup']?.toString() ?? '-';
    final dropoff  = trip['dropoff']?.toString() ?? '-';
    final dateStr  = trip['date']?.toString() ?? '';
    final date     = DateTime.tryParse(dateStr) ?? DateTime.now();
    final km       = (trip['km'] as num?)?.toDouble() ?? 5.5;
    final status   = trip['status']?.toString() ?? 'completed';
    final isCompleted = status == 'completed';

    // Dummy rincian tarif agar visualnya sama dengan mockup
    int serviceFee = 2000;
    int baseFare = 12000;
    int distanceFare = fare - baseFare - serviceFee;
    if (distanceFare < 0) {
      baseFare = fare;
      distanceFare = 0;
      serviceFee = 0;
    }

    // Short ID formatter
    final shortId = widget.tripId.length >= 8 ? widget.tripId.substring(0, 8).toUpperCase() : widget.tripId.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Latar abu-abu sangat muda
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary500),
          onPressed: () => context.pop(),
        ),
        title: Text('Detail Pesanan', style: AppTypography.h3.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ink0,
            borderRadius: AppRadius.xlAll,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header (Tgl & ID & Status) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDateTime(date), style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                        const SizedBox(height: 2),
                        Text('ID: T-$shortId', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.success500.withOpacity(0.15) : AppColors.danger500.withOpacity(0.15),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isCompleted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                              size: 14, color: isCompleted ? AppColors.success500 : AppColors.danger500),
                          const SizedBox(width: 4),
                          Text(isCompleted ? 'Selesai' : 'Batal',
                              style: AppTypography.label.copyWith(
                                  color: isCompleted ? AppColors.success500 : AppColors.danger500,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── Pickup & Dropoff ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.success500, width: 3))),
                        Container(width: 2, height: 28, color: AppColors.ink300),
                        const Icon(Icons.location_on_rounded, color: AppColors.danger500, size: 18),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900)),
                          const SizedBox(height: 18),
                          Text(dropoff, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── Fare Breakdown ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(color: const Color(0xFFF4F7FC), borderRadius: AppRadius.lgAll),
                  child: Column(
                    children: [
                      _FareRow(label: 'Tarif Dasar', value: _fmtIdr(baseFare)),
                      const SizedBox(height: 8),
                      _FareRow(label: 'Jarak (${km.toStringAsFixed(1)} km)', value: _fmtIdr(distanceFare)),
                      const SizedBox(height: 8),
                      _FareRow(label: 'Biaya Layanan', value: _fmtIdr(serviceFee)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.ink300)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Biaya', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                          Text(_fmtIdr(fare), style: AppTypography.h3.copyWith(color: AppColors.ink900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── Driver Info ──
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?img=11'), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                          Text('Kendaraan • $plate', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                        ],
                      ),
                    ),
                    if (rating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 18),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () {
                          Toast.show(context, message: 'Pusat bantuan segera hadir', type: ToastType.info);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3F2FD),
                          foregroundColor: AppColors.info500,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.help_outline_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Bantuan', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: _shareReceipt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: AppColors.ink0,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Bagikan Resi', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    final year = d.year;
    final hr = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hr:$min WIB';
  }

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

// ── Reusable Widget ────────────────────────────────────────────────────────

class _FareRow extends StatelessWidget {
  const _FareRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
        Text(value, style: AppTypography.bodySm.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w500)),
      ],
    );
  }
}