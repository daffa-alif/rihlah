import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FareBreakdown — table-style component with mono numbers
// ─────────────────────────────────────────────────────────────────────────────

class FareBreakdownRow {
  const FareBreakdownRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isHighlighted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final bool isHighlighted;
  final Color? valueColor;
}

class FareBreakdown extends StatelessWidget {
  const FareBreakdown({super.key, required this.rows, this.title});

  final List<FareBreakdownRow> rows;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.s16),
        ],
        ...rows.map((row) {
          final isLast = row == rows.last;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: row.isTotal
                          ? AppTypography.bodyLg.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink900,
                            )
                          : AppTypography.bodyMd.copyWith(color: AppColors.ink700),
                    ),
                    Text(
                      row.value,
                      style: AppTypography.mono.copyWith(
                        fontWeight: row.isTotal ? FontWeight.w700 : FontWeight.w500,
                        color: row.valueColor ??
                            (row.isTotal ? AppColors.ink900 : AppColors.ink700),
                        fontSize: row.isTotal ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: AppColors.ink100),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RatingStars — interactive 1–5 with haptic feedback
// ─────────────────────────────────────────────────────────────────────────────

class RatingStars extends StatefulWidget {
  const RatingStars({
    super.key,
    this.initialRating = 0,
    this.onRatingChanged,
    this.size = 40,
    this.readOnly = false,
  });

  final int initialRating;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final bool readOnly;

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  void _setRating(int value) {
    if (widget.readOnly) return;
    HapticFeedback.lightImpact();
    setState(() => _rating = value);
    widget.onRatingChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return GestureDetector(
          onTap: () => _setRating(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _rating >= starValue ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey('$starValue-${_rating >= starValue}'),
                size: widget.size,
                color: _rating >= starValue ? AppColors.accent500 : AppColors.ink300,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyState — illustration + title + body + optional CTA
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.ctaLabel,
    this.onCtaTap,
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 40,
                color: AppColors.ink500,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text(
              body,
              style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onCtaTap,
                  child: Text(ctaLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toast — top-anchored, brand-colored, auto-dismiss 3s
// ─────────────────────────────────────────────────────────────────────────────

enum ToastType { info, success, warning, danger }

class Toast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final (bg, fg, defaultIcon) = switch (type) {
      ToastType.info    => (AppColors.info500,    AppColors.ink0, Icons.info_outline_rounded),
      ToastType.success => (AppColors.success500, AppColors.ink0, Icons.check_circle_outline_rounded),
      ToastType.warning => (AppColors.warning500, AppColors.ink0, Icons.warning_amber_rounded),
      ToastType.danger  => (AppColors.danger500,  AppColors.ink0, Icons.error_outline_rounded),
    };

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.s16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          content: Row(
            children: [
              Icon(icon ?? defaultIcon, color: fg, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMd.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      );
  }
}