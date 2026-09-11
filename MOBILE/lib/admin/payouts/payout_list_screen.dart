import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/payout_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/admin_widgets.dart';

const _payoutStatusColors = {
  PayoutStatus.processing: AppColors.warning500,
  PayoutStatus.success: AppColors.success500,
  PayoutStatus.failed: AppColors.danger500,
};

class PayoutListScreen extends StatefulWidget {
  const PayoutListScreen({super.key});

  @override
  State<PayoutListScreen> createState() => _PayoutListScreenState();
}

class _PayoutListScreenState extends State<PayoutListScreen> {
  PayoutStatus? _statusFilter;
  final Set<String> _updating = {};

  Future<void> _settle(PayoutModel p, PayoutStatus status) async {
    setState(() => _updating.add(p.payoutId));
    await FirestoreService.instance
        .updatePayoutStatus(p.payoutId, status, setPaidAt: status == PayoutStatus.success);
    if (mounted) setState(() => _updating.remove(p.payoutId));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminListScaffold(
      title: 'Payouts / Penarikan Driver',
      actions: [
        DropdownButton<PayoutStatus?>(
          value: _statusFilter,
          hint: const Text('Semua status'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Semua status')),
            ...PayoutStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
          ],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ],
      child: StreamBuilder<List<PayoutModel>>(
        stream: FirestoreService.instance.payoutsStream(limit: 300),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var payouts = snap.data!;
          if (_statusFilter != null) {
            payouts = payouts.where((p) => p.status == _statusFilter).toList();
          }
          if (payouts.isEmpty) {
            return const AdminEmptyState(message: 'Tidak ada penarikan ditemukan.');
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
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('Jumlah'), numeric: true),
                  DataColumn(label: Text('Biaya'), numeric: true),
                  DataColumn(label: Text('Tujuan')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('')),
                ],
                rows: payouts.map((p) {
                  final d = p.requestedAt?.toDate();
                  final busy = _updating.contains(p.payoutId);
                  return DataRow(cells: [
                    DataCell(Text(d != null ? formatDateTime(d) : '—')),
                    DataCell(FutureBuilder<UserModel?>(
                      future: FirestoreService.instance.getUser(p.driverId),
                      builder: (context, s) => Text(s.data?.name ?? p.driverId),
                    )),
                    DataCell(Text(formatIdr(p.amountIdr))),
                    DataCell(Text(formatIdr(p.feeIdr))),
                    DataCell(Text(p.destination)),
                    DataCell(StatusPill(
                      label: p.status.name,
                      color: _payoutStatusColors[p.status] ?? AppColors.ink400,
                    )),
                    DataCell(
                      p.status == PayoutStatus.processing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _settle(p, PayoutStatus.success),
                                  child: const Text('Selesaikan'),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _settle(p, PayoutStatus.failed),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppColors.danger500),
                                  child: const Text('Gagalkan'),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
