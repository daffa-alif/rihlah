import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class RihlahTextField extends StatelessWidget {
  const RihlahTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingTap,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.ink700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: AppTypography.bodyMd.copyWith(color: AppColors.ink900),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            helperStyle: AppTypography.bodySm.copyWith(color: AppColors.ink500),
            errorStyle: AppTypography.bodySm.copyWith(color: AppColors.danger500),
            prefixIcon: leadingIcon != null
                ? Icon(leadingIcon, size: 20, color: AppColors.ink500)
                : null,
            suffixIcon: trailingIcon != null
                ? GestureDetector(
                    onTap: onTrailingTap,
                    child: Icon(trailingIcon, size: 20, color: AppColors.ink500),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}