import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A single KPI stat card for the admin dashboard.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.primary500,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.s8),
              ],
              Expanded(
                child: Text(label,
                    style: AppTypography.bodySm
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(value,
              style: AppTypography.h1.copyWith(fontSize: 26, color: cs.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(subtitle!,
                style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Small colored status label, e.g. "ACTIVE" / "SUSPENDED" / "OPEN".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

/// Shell for a data table screen: title bar + optional actions + scrollable
/// table body — used by every list screen (drivers, passengers, trips…) so
/// they share one consistent frame.
class AdminListScaffold extends StatelessWidget {
  const AdminListScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTypography.h2.copyWith(color: cs.onSurface)),
            const Spacer(),
            ...actions,
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Expanded(child: child),
      ],
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.s12),
          Text(message,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Gagal memuat data: $error',
          style: AppTypography.bodyMd.copyWith(color: AppColors.danger500)),
    );
  }
}

String formatIdr(num v) {
  final s = v.round().toString();
  final buf = StringBuffer('Rp ');
  final offset = s.length % 3;
  for (int i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

String formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
}

/// A "Load More" button for cursor-based pagination in admin list screens.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.onLoad,
    this.loading = false,
    this.hasMore = true,
  });
  final VoidCallback onLoad;
  final bool loading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Muat lebih banyak'),
              ),
      ),
    );
  }
}
