import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/user_model.dart';
import '../admin_router.dart';
import '../widgets/admin_widgets.dart';

class PassengerListScreen extends StatefulWidget {
  const PassengerListScreen({super.key});

  @override
  State<PassengerListScreen> createState() => _PassengerListScreenState();
}

class _PassengerListScreenState extends State<PassengerListScreen> {
  String _query = '';
  final Set<String> _updating = {};

  Future<void> _toggle(UserModel u) async {
    setState(() => _updating.add(u.uid));
    final next = u.isSuspended ? 'active' : 'suspended';
    await FirestoreService.instance.setAccountStatus(u.uid, next);
    if (mounted) setState(() => _updating.remove(u.uid));
  }

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      title: 'Passengers',
      actions: [
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: 'Cari nama atau telepon…',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
      ],
      child: StreamBuilder<List<UserModel>>(
        stream: FirestoreService.instance.usersStream(role: 'passenger'),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var passengers = snap.data!;
          if (_query.isNotEmpty) {
            passengers = passengers
                .where((p) =>
                    p.name.toLowerCase().contains(_query) ||
                    p.phone.toLowerCase().contains(_query))
                .toList();
          }
          if (passengers.isEmpty) {
            return const AdminEmptyState(message: 'Tidak ada penumpang ditemukan.');
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Telepon')),
                  DataColumn(label: Text('Bergabung')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aksi')),
                  DataColumn(label: Text('Detail')),
                ],
                rows: passengers.map((p) {
                  final joined = p.createdAt?.toDate();
                  final busy = _updating.contains(p.uid);
                  return DataRow(cells: [
                    DataCell(Text(p.name)),
                    DataCell(Text(p.phone)),
                    DataCell(Text(joined != null
                        ? '${joined.day}/${joined.month}/${joined.year}'
                        : '—')),
                    DataCell(StatusPill(
                      label: p.isSuspended ? 'Ditangguhkan' : 'Aktif',
                      color: p.isSuspended ? AppColors.danger500 : AppColors.success500,
                    )),
                    DataCell(TextButton(
                      onPressed: busy ? null : () => _toggle(p),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            p.isSuspended ? AppColors.success500 : AppColors.danger500,
                      ),
                      child: Text(p.isSuspended ? 'Aktifkan' : 'Tangguhkan'),
                    )),
                    DataCell(TextButton(
                      onPressed: () =>
                          context.push(AdminRoutes.passengerDetail(p.uid)),
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
