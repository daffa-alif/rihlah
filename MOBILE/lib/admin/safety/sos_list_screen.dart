import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/sos_event_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/admin_widgets.dart';

class SosListScreen extends StatefulWidget {
  const SosListScreen({super.key});

  @override
  State<SosListScreen> createState() => _SosListScreenState();
}

class _SosListScreenState extends State<SosListScreen> {
  final Set<String> _updating = {};

  Future<void> _acknowledge(SosEventModel e) async {
    setState(() => _updating.add(e.eventId));
    await FirestoreService.instance.updateSosEventStatus(e.eventId, 'acknowledged');
    if (mounted) setState(() => _updating.remove(e.eventId));
  }

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      title: 'Safety / SOS',
      child: StreamBuilder<List<SosEventModel>>(
        stream: FirestoreService.instance.sosEventsStream(limit: 200),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const AdminEmptyState(
                message: 'Belum ada peringatan SOS.', icon: Icons.shield_outlined);
          }
          final open = events.where((e) => e.status == 'open').toList();
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (open.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.danger500.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger500.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.danger500),
                        const SizedBox(width: AppSpacing.s8),
                        Text('${open.length} peringatan SOS belum ditangani',
                            style: AppTypography.bodyMd
                                .copyWith(color: AppColors.danger500, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ...events.map((e) => _SosCard(
                      event: e,
                      busy: _updating.contains(e.eventId),
                      onAcknowledge: () => _acknowledge(e),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SosCard extends StatelessWidget {
  const _SosCard({required this.event, required this.busy, required this.onAcknowledge});
  final SosEventModel event;
  final bool busy;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOpen = event.status == 'open';
    final d = event.createdAt?.toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen ? AppColors.danger500.withValues(alpha: 0.4) : cs.outline,
          width: isOpen ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emergency_share_rounded,
              color: isOpen ? AppColors.danger500 : AppColors.ink400),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FutureBuilder<UserModel?>(
                      future: FirestoreService.instance.getUser(event.byUserId),
                      builder: (context, snap) => Text(
                        snap.data?.name ?? event.byUserId,
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    if (event.byUserRole != null)
                      Text('(${event.byUserRole})',
                          style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Lokasi: ${event.lat.toStringAsFixed(6)}, ${event.lng.toStringAsFixed(6)}'
                  '${event.tripId != null ? " · Trip ${event.tripId}" : ""}',
                  style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
                ),
                if (d != null)
                  Text(formatDateTime(d),
                      style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          StatusPill(
            label: isOpen ? 'Terbuka' : 'Ditangani',
            color: isOpen ? AppColors.danger500 : AppColors.success500,
          ),
          if (isOpen) ...[
            const SizedBox(width: AppSpacing.s12),
            ElevatedButton(
              onPressed: busy ? null : onAcknowledge,
              child: const Text('Tandai Ditangani'),
            ),
          ],
        ],
      ),
    );
  }
}
