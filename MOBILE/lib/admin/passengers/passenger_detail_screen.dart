import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/admin_widgets.dart';

class PassengerDetailScreen extends StatefulWidget {
  const PassengerDetailScreen({super.key, required this.uid});
  final String uid;

  @override
  State<PassengerDetailScreen> createState() => _PassengerDetailScreenState();
}

class _PassengerDetailScreenState extends State<PassengerDetailScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await FirestoreService.instance.getUser(widget.uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _toggleStatus() async {
    final u = _user;
    if (u == null) return;
    setState(() => _updating = true);
    final next = u.isSuspended ? 'active' : 'suspended';
    await FirestoreService.instance.setAccountStatus(widget.uid, next);
    await _load();
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final u = _user;
    if (u == null) {
      return const AdminEmptyState(message: 'Penumpang tidak ditemukan.');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(u.name, style: AppTypography.h2),
              const SizedBox(width: AppSpacing.s12),
              StatusPill(
                label: u.isSuspended ? 'Ditangguhkan' : 'Aktif',
                color: u.isSuspended ? AppColors.danger500 : AppColors.success500,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _updating ? null : _toggleStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: u.isSuspended ? AppColors.success500 : AppColors.danger500,
                  side: BorderSide(
                      color: u.isSuspended ? AppColors.success500 : AppColors.danger500),
                ),
                child: Text(u.isSuspended ? 'Aktifkan Kembali' : 'Tangguhkan Akun'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s16,
            children: [
              _InfoCard(title: 'Kontak', rows: [
                ('Telepon', u.phone),
                ('UID', u.uid),
                ('Bergabung', u.createdAt != null
                    ? formatDateTime(u.createdAt!.toDate()) : '—'),
              ]),
            ],
          ),
          const SizedBox(height: AppSpacing.s32),
          Text('Riwayat Trip', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.s12),
          StreamBuilder<List<TripModel>>(
            stream: FirestoreService.instance.passengerTripsStream(widget.uid, limit: 100),
            builder: (context, snap) {
              if (snap.hasError) return AdminErrorState(error: snap.error!);
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final trips = snap.data!;
              if (trips.isEmpty) {
                return const AdminEmptyState(message: 'Belum ada trip.');
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
                      DataColumn(label: Text('Rute')),
                      DataColumn(label: Text('Tarif'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: trips.map((t) {
                      final d = t.createdAt?.toDate();
                      return DataRow(cells: [
                        DataCell(Text(d != null ? formatDateTime(d) : '—')),
                        DataCell(SizedBox(
                          width: 220,
                          child: Text(
                            '${t.pickupAddress} → ${t.dropoffAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(formatIdr(t.totalFare))),
                        DataCell(Text(t.status.name)),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.label.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s12),
          for (final (label, value) in rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
                  Flexible(
                    child: Text(value,
                        style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
