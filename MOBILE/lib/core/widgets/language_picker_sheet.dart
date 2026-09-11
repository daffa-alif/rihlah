import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class LanguagePickerSheet extends ConsumerWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localeProvider.notifier);
    final current  = ref.watch(localeProvider);

    const langs = [
      ('id', '🇮🇩', 'Bahasa Indonesia', 'Indonesian'),
      ('en', '🇬🇧', 'English',           'Inggris'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink300,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            Text('Pilih Bahasa / Select Language',
                style: AppTypography.h3),
            const SizedBox(height: AppSpacing.s16),

            // Language options
            ...langs.map((l) {
              final isActive = current.languageCode == l.$1;
              return GestureDetector(
                onTap: () async {
                  await notifier.setLocale(Locale(l.$1));
                  if (context.mounted) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary500
                          : Theme.of(context).colorScheme.outline,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(l.$2,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.$3,
                                style: AppTypography.bodyLg.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                )),
                            Text(l.$4,
                                style: AppTypography.bodySm
                                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary500,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.ink0, size: 14),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}