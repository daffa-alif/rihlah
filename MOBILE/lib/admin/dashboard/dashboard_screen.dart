import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../widgets/admin_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripModel>>(
      stream: FirestoreService.instance.allTripsStream(limit: 500),
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorState(error: snap.error!);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final trips = snap.data!;
        final now = DateTime.now();
        final todayTrips = trips.where((t) {
          final d = t.createdAt?.toDate();
          return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        final completedToday =
            todayTrips.where((t) => t.status == TripStatus.completed).toList();
        final cancelledToday =
            todayTrips.where((t) => t.status == TripStatus.cancelled).toList();
        final gmvToday = completedToday.fold<int>(0, (sum, t) => sum + t.totalFare);
        final ratings = trips
            .where((t) => t.passengerRating != null)
            .map((t) => t.passengerRating!)
            .toList();
        final avgRating = ratings.isEmpty
            ? 0.0
            : ratings.reduce((a, b) => a + b) / ratings.length;

        final last7 = List.generate(7, (i) {
          final day = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: 6 - i));
          final dayTrips = trips.where((t) {
            final d = t.createdAt?.toDate();
            return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
          }).toList();
          final completed =
              dayTrips.where((t) => t.status == TripStatus.completed).toList();
          final gmv = completed.fold<int>(0, (sum, t) => sum + t.totalFare);
          return (day, dayTrips.length, gmv);
        });

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s16),
              FutureBuilder<int>(
                future: FirestoreService.instance.onlineDriversCount(),
                builder: (context, onlineSnap) {
                  return Wrap(
                    spacing: AppSpacing.s16,
                    runSpacing: AppSpacing.s16,
                    children: [
                      SizedBox(
                        width: 220,
                        child: KpiCard(
                          label: 'Driver Online Sekarang',
                          value: '${onlineSnap.data ?? '—'}',
                          icon: Icons.two_wheeler_rounded,
                          color: AppColors.primary500,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: KpiCard(
                          label: 'Trip Hari Ini',
                          value: '${todayTrips.length}',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.info500,
                          subtitle: '${completedToday.length} selesai · ${cancelledToday.length} batal',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: KpiCard(
                          label: 'GMV Hari Ini',
                          value: formatIdr(gmvToday),
                          icon: Icons.payments_rounded,
                          color: AppColors.success500,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: KpiCard(
                          label: 'Rating Rata-rata Driver',
                          value: avgRating.toStringAsFixed(2),
                          icon: Icons.star_rounded,
                          color: AppColors.accent500,
                          subtitle: '${ratings.length} penilaian (500 trip terakhir)',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s32),
              Text('7 Hari Terakhir', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.s12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Tanggal')),
                      DataColumn(label: Text('Jumlah Trip'), numeric: true),
                      DataColumn(label: Text('GMV'), numeric: true),
                    ],
                    rows: last7.reversed.map((row) {
                      final (day, count, gmv) = row;
                      return DataRow(cells: [
                        DataCell(Text('${day.day}/${day.month}/${day.year}')),
                        DataCell(Text('$count')),
                        DataCell(Text(formatIdr(gmv))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              if (trips.length >= 500)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: Text(
                    'Menampilkan 500 trip terakhir saja — cukup untuk demo/MVP, belum untuk skala besar.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.ink400),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
