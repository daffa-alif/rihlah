import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/admin_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _rangeDays = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<TripModel>>(
      // Bounded fetch — reports are computed client-side over the most
      // recent 1000 trips, a documented scale limitation for this MVP.
      stream: FirestoreService.instance.allTripsStream(limit: 1000),
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorState(error: snap.error!);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
        final trips = snap.data!.where((t) {
          final d = t.createdAt?.toDate();
          return d != null && d.isAfter(cutoff);
        }).toList();
        final completed = trips.where((t) => t.status == TripStatus.completed).toList();
        final cancelled = trips.where((t) => t.status == TripStatus.cancelled).toList();
        final gmv = completed.fold<int>(0, (sum, t) => sum + t.totalFare);
        final platformRevenue = completed.fold<int>(0, (sum, t) => sum + t.platformFee);
        final avgFare = completed.isEmpty ? 0 : gmv ~/ completed.length;

        final byDriver = <String, List<TripModel>>{};
        for (final t in completed) {
          final id = t.driverId;
          if (id == null) continue;
          byDriver.putIfAbsent(id, () => []).add(t);
        }
        final topDrivers = byDriver.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Reports', style: AppTypography.h2),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _rangeDays,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 hari terakhir')),
                      DropdownMenuItem(value: 30, child: Text('30 hari terakhir')),
                      DropdownMenuItem(value: 90, child: Text('90 hari terakhir')),
                    ],
                    onChanged: (v) => setState(() => _rangeDays = v ?? 7),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Wrap(
                spacing: AppSpacing.s16,
                runSpacing: AppSpacing.s16,
                children: [
                  SizedBox(width: 220, child: KpiCard(
                    label: 'Total Trip', value: '${trips.length}',
                    icon: Icons.receipt_long_rounded, color: AppColors.info500,
                    subtitle: '${completed.length} selesai · ${cancelled.length} batal',
                  )),
                  SizedBox(width: 220, child: KpiCard(
                    label: 'GMV', value: formatIdr(gmv),
                    icon: Icons.payments_rounded, color: AppColors.success500,
                  )),
                  SizedBox(width: 220, child: KpiCard(
                    label: 'Pendapatan Platform (5%)', value: formatIdr(platformRevenue),
                    icon: Icons.account_balance_wallet_rounded, color: AppColors.primary500,
                  )),
                  SizedBox(width: 220, child: KpiCard(
                    label: 'Tarif Rata-rata', value: formatIdr(avgFare),
                    icon: Icons.functions_rounded, color: AppColors.accent500,
                  )),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),
              Text('Top Driver (berdasarkan jumlah trip)', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.s12),
              if (topDrivers.isEmpty)
                const AdminEmptyState(message: 'Belum ada trip selesai pada rentang ini.')
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Driver')),
                        DataColumn(label: Text('Jumlah Trip'), numeric: true),
                        DataColumn(label: Text('Total Pendapatan'), numeric: true),
                      ],
                      rows: topDrivers.take(10).map((e) {
                        final earnings =
                            e.value.fold<int>(0, (sum, t) => sum + t.driverEarns);
                        return DataRow(cells: [
                          DataCell(FutureBuilder<UserModel?>(
                            future: FirestoreService.instance.getUser(e.key),
                            builder: (context, s) => Text(s.data?.name ?? e.key),
                          )),
                          DataCell(Text('${e.value.length}')),
                          DataCell(Text(formatIdr(earnings))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              if (snap.data!.length >= 1000)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: Text(
                    'Dihitung dari 1000 trip terakhir saja — cukup untuk demo/MVP, belum untuk skala besar.',
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
