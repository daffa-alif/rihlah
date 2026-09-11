import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/admin_widgets.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

const _statusColors = {
  TripStatus.completed: AppColors.success500,
  TripStatus.cancelled: AppColors.danger500,
  TripStatus.searching: AppColors.info500,
};

class _TripListScreenState extends State<TripListScreen> {
  TripStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminListScaffold(
      title: 'Trips / Transaksi',
      actions: [
        DropdownButton<TripStatus?>(
          value: _statusFilter,
          hint: const Text('Semua status'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Semua status')),
            ...TripStatus.values.map(
                (s) => DropdownMenuItem(value: s, child: Text(s.name))),
          ],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ],
      child: StreamBuilder<List<TripModel>>(
        stream: FirestoreService.instance.allTripsStream(
            status: _statusFilter, limit: 300),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snap.data!;
          if (trips.isEmpty) {
            return const AdminEmptyState(message: 'Tidak ada trip ditemukan.');
          }
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Penumpang')),
                  DataColumn(label: Text('Rute')),
                  DataColumn(label: Text('Tarif'), numeric: true),
                  DataColumn(label: Text('Pembayaran')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('')),
                ],
                rows: trips.map((t) {
                  final d = t.createdAt?.toDate();
                  return DataRow(cells: [
                    DataCell(Text(d != null ? formatDateTime(d) : '—')),
                    DataCell(Text(t.passengerName ?? '—')),
                    DataCell(SizedBox(
                      width: 220,
                      child: Text(
                        '${t.pickupAddress} → ${t.dropoffAddress}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    DataCell(Text(formatIdr(t.totalFare))),
                    DataCell(Text(t.paymentMethod)),
                    DataCell(StatusPill(
                      label: t.status.name,
                      color: _statusColors[t.status] ?? AppColors.ink400,
                    )),
                    DataCell(TextButton(
                      onPressed: () => _showDetail(context, t),
                      child: const Text('Detail'),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, TripModel t) {
    showDialog(
      context: context,
      builder: (_) => _TripDetailDialog(trip: t),
    );
  }
}

class _TripDetailDialog extends StatelessWidget {
  const _TripDetailDialog({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    return AlertDialog(
      title: Text('Trip ${t.tripId}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Penumpang', t.passengerName ?? '—'),
              _row('Telepon', t.passengerPhone ?? '—'),
              if (t.driverId != null)
                FutureBuilder<UserModel?>(
                  future: FirestoreService.instance.getUser(t.driverId!),
                  builder: (context, snap) =>
                      _row('Driver', snap.data?.name ?? t.driverId!),
                ),
              const Divider(height: 24),
              _row('Rute', '${t.pickupAddress} → ${t.dropoffAddress}'),
              _row('Jarak', '${t.distanceKm.toStringAsFixed(1)} km'),
              _row('Durasi', '${t.durationMin} menit'),
              const Divider(height: 24),
              _row('Total Tarif', formatIdr(t.totalFare)),
              _row('Biaya Platform (5%)', formatIdr(t.platformFee)),
              _row('Bagian Driver (95%)', formatIdr(t.driverEarns)),
              if (t.appliedDiscount != null)
                _row('Diskon', '- ${formatIdr(t.appliedDiscount!)}'
                    '${t.appliedVoucherCode != null ? ' (${t.appliedVoucherCode})' : ''}'),
              _row('Metode Pembayaran', t.paymentMethod),
              const Divider(height: 24),
              _row('Status', t.status.name),
              if (t.passengerRating != null)
                _row('Rating', '${t.passengerRating} ★'),
              if (t.passengerReview != null && t.passengerReview!.isNotEmpty)
                _row('Ulasan', t.passengerReview!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
            ),
            Expanded(
              child: Text(value,
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
