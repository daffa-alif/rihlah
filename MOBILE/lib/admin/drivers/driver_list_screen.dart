import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_model.dart';
import '../admin_router.dart';
import '../widgets/admin_widgets.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  String _query = '';
  String _statusFilter = 'all'; // all | active | suspended

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      title: 'Drivers',
      actions: [
        SizedBox(
          width: 240,
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: 'Cari nama, telepon, plat…',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        DropdownButton<String>(
          value: _statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Semua status')),
            DropdownMenuItem(value: 'active', child: Text('Aktif')),
            DropdownMenuItem(value: 'suspended', child: Text('Ditangguhkan')),
          ],
          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
        ),
      ],
      child: StreamBuilder<List<UserModel>>(
        stream: FirestoreService.instance.usersStream(role: 'driver'),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var drivers = snap.data!;
          if (_statusFilter != 'all') {
            drivers = drivers.where((d) => d.accountStatus == _statusFilter).toList();
          }
          if (_query.isNotEmpty) {
            drivers = drivers.where((d) =>
                d.name.toLowerCase().contains(_query) ||
                d.phone.toLowerCase().contains(_query) ||
                (d.plate ?? '').toLowerCase().contains(_query)).toList();
          }
          if (drivers.isEmpty) {
            return const AdminEmptyState(message: 'Tidak ada driver ditemukan.');
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Telepon')),
                  DataColumn(label: Text('Kendaraan')),
                  DataColumn(label: Text('Plat')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('')),
                ],
                rows: drivers.map((d) {
                  return DataRow(cells: [
                    DataCell(Text(d.name)),
                    DataCell(Text(d.phone)),
                    DataCell(Text(d.vehicleType == 'bike' ? 'Motor' : 'Mobil')),
                    DataCell(Text(d.plate ?? '—')),
                    DataCell(Text(d.ratingAvg?.toStringAsFixed(1) ?? '—')),
                    DataCell(StatusPill(
                      label: d.accountStatus == 'suspended' ? 'Ditangguhkan' : 'Aktif',
                      color: d.accountStatus == 'suspended'
                          ? AppColors.danger500
                          : AppColors.success500,
                    )),
                    DataCell(TextButton(
                      onPressed: () =>
                          context.push(AdminRoutes.driverDetail(d.uid)),
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
}
