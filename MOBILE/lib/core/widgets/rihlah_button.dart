import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum RihlahButtonVariant { primary, secondary, tertiary, danger }

class RihlahButton extends StatelessWidget {
  const RihlahButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RihlahButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final RihlahButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;

  bool get _disabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors;

    return SizedBox(
      height: 52,
      width: width ?? double.infinity,
      child: AnimatedOpacity(
        opacity: _disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.mdAll,
            border: border != null
                ? Border.all(color: border, width: 1.5)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _disabled ? null : onPressed,
              splashColor: fg.withOpacity(0.12),
              highlightColor: fg.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading) ...[
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                    ] else if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: fg, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                    ],
                    Text(
                      label,
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (trailingIcon != null && !isLoading) ...[
                      const SizedBox(width: AppSpacing.s8),
                      Icon(trailingIcon, color: fg, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color bg, Color fg, Color? border) get _colors => switch (variant) {
        RihlahButtonVariant.primary => (
            AppColors.primary500,
            AppColors.ink0,
            null,
          ),
        RihlahButtonVariant.secondary => (
            AppColors.primary100,
            AppColors.primary500,
            null,
          ),
        RihlahButtonVariant.tertiary => (
            Colors.transparent,
            AppColors.primary500,
            AppColors.primary500,
          ),
        RihlahButtonVariant.danger => (
            AppColors.danger500,
            AppColors.ink0,
            null,
          ),
      };
}