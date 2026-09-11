import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── StatusPill ────────────────────────────────────────────────────────────────

enum TripStatus { searching, accepted, arriving, inTrip, completed, cancelled }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Text(label, style: AppTypography.label.copyWith(color: fg)),
    );
  }

  (String, Color, Color) get _config => switch (status) {
    TripStatus.searching  => ('Mencari Driver',    AppColors.info500.withOpacity(0.12),    AppColors.info500),
    TripStatus.accepted   => ('Driver Ditemukan',  AppColors.success500.withOpacity(0.12), AppColors.success500),
    TripStatus.arriving   => ('Menuju Kamu',        AppColors.accent100,                   AppColors.accent500),
    TripStatus.inTrip     => ('Dalam Perjalanan',  AppColors.primary100,                  AppColors.primary600),
    TripStatus.completed  => ('Selesai',            AppColors.success500.withOpacity(0.12), AppColors.success500),
    TripStatus.cancelled  => ('Dibatalkan',         AppColors.danger500.withOpacity(0.12),  AppColors.danger500),
  };
}

// ── RouteLine ─────────────────────────────────────────────────────────────────

class RouteLine extends StatelessWidget {
  const RouteLine({super.key, required this.pickup, required this.dropoff, this.dense = false});
  final String pickup;
  final String dropoff;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final dotSize = dense ? 10.0 : 12.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dotSize + 8,
            child: Column(
              children: [
                Container(
                  width: dotSize, height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary500, width: 2),
                  ),
                ),
                Expanded(child: CustomPaint(painter: _DashedLinePainter(color: AppColors.ink300))),
                Container(
                  width: dotSize, height: dotSize,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup,
                  style: (dense ? AppTypography.bodySm : AppTypography.bodyMd)
                      .copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: dense ? 16.0 : AppSpacing.s24),
                Text(dropoff,
                  style: (dense ? AppTypography.bodySm : AppTypography.bodyMd)
                      .copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 4.0, dashSpace = 3.0;
    final paint = Paint()..color = color..strokeWidth = 1.5;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ── TripCard ──────────────────────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.date,
    required this.status,
    this.onTap,
  });

  final String pickup;
  final String dropoff;
  final String fare;
  final String date;
  final TripStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.ink300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 12),
            RouteLine(pickup: pickup, dropoff: dropoff, dense: true),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTypography.bodyMd.copyWith(color: AppColors.ink700)),
                Text(fare, style: AppTypography.mono.copyWith(
                  color: AppColors.ink900, fontWeight: FontWeight.w700,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}