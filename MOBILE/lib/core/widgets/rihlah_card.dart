import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RihlahCard
// ─────────────────────────────────────────────────────────────────────────────

class RihlahCard extends StatelessWidget {
  const RihlahCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.ink0,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppElevation.card,
        border: Border.all(color: AppColors.ink300),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadius.lgAll,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RihlahSheet — draggable bottom sheet with snap points
// ─────────────────────────────────────────────────────────────────────────────

class RihlahSheet extends StatelessWidget {
  const RihlahSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s8,
      AppSpacing.s16,
      AppSpacing.s24,
    ),
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  /// Show this sheet using [showModalBottomSheet] with these snap sizes:
  /// peek=0.35, half=0.6, full=0.95
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
    List<double> snapSizes = const [0.35, 0.6, 0.95],
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: snapSizes.first,
        minChildSize: snapSizes.first,
        maxChildSize: snapSizes.last,
        expand: false,
        snap: true,
        snapSizes: snapSizes.sublist(1, snapSizes.length - 1),
        builder: (_, scrollController) => RihlahSheet(
          title: title,
          child: SingleChildScrollView(
            controller: scrollController,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink300,
                borderRadius: AppRadius.pillAll,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Text(title!, style: AppTypography.h3),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleCard — large 2-up tile for role picker screen
// ─────────────────────────────────────────────────────────────────────────────

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary100 : AppColors.ink0,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isSelected ? AppColors.primary500 : AppColors.ink300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppElevation.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary500 : AppColors.ink100,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.ink0 : AppColors.ink700,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              title,
              style: AppTypography.h3.copyWith(
                color: isSelected ? AppColors.primary600 : AppColors.ink900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle,
              style: AppTypography.bodySm.copyWith(color: AppColors.ink500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}