import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/core.dart';
import '../../../router.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/widgets/version_tap_trigger.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import 'package:rihlah/core/providers/locale_provider.dart';
import '../../../core/widgets/custom_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tripCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final box = Hive.box('settings');
    final history = (box.get('trip_history') as List?)?.cast<Map>() ?? [];
    setState(() {
      _tripCount = history.where((m) => m['status'] == 'completed').length;
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onPayment() => context.push(Routes.pProfilePayment);
  void _onSavedAddresses() => context.push(Routes.pSavedAddresses);
  void _onSafety() => context.push(Routes.pProfileSafety);
  void _onLanguage() => LanguagePickerSheet.show(context);
  void _onHelp() => Toast.show(context, message: 'Pusat bantuan segera hadir', type: ToastType.info);

  void _onSignOut() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SignOutSheet(
        onConfirm: () async {
          final box = Hive.box('settings');
          await box.delete('authed');
          await box.delete('role');
          if (!mounted) return;
          Navigator.pop(context);
          context.go(Routes.onboarding);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'en' ? 'English' : 'Bahasa Indonesia';
    final profile = ref.watch(userProfileProvider).value;

    // Fallback nama & nomor HP
    final name = (profile != null && profile.name.isNotEmpty) ? profile.name : 'Sarah Jenkins';
    final phone = (profile != null && profile.phone.isNotEmpty) ? profile.phone : '+62 812-3456-7890';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Background abu-abu muda
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary500),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.pHome);
            }
          },
        ),
        title: Text(
          'Profile',
          style: AppTypography.h3.copyWith(color: AppColors.primary600, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
                child: Column(
                  children: [
                    // ── 1. Profile Header (Avatar, Name, Badge) ──
                    Row(
                      children: [
                        // Avatar
                        // Avatar
                        CustomAvatar(
                          // Ganti 'profile?.name' dengan nama variabel yang menyimpan nama user di halaman ini
                          name: profile?.name ?? 'Penumpang',

                          // Ganti 'profile?.photoUrl' dengan variabel foto dari database.
                          // Jika masih ingin pakai foto dummy sementara, biarkan baris di bawah ini.
                          // Jika ingin tes inisial namanya, ubah menjadi imageUrl: null,
                          imageUrl: profile?.photoUrl ?? 'https://i.pravatar.cc/150?img=32',

                          size: 72.0,
                          fontSize: 28.0,
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        // Detail
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTypography.h2.copyWith(color: AppColors.ink900, fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(phone, style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
                              const SizedBox(height: 8),
                              // Gold Member Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6), // Kuning muda
                                  borderRadius: AppRadius.pillAll,
                                  border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Color(0xFFF57F17), size: 14),
                                    const SizedBox(width: 4),
                                    Text('Gold Member', style: AppTypography.label.copyWith(color: const Color(0xFFF57F17), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── 2. Stats Row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatCard(value: '$_tripCount', label: 'Trips'),
                        const SizedBox(width: 12),
                        const _StatCard(value: '4.9 ★', label: 'Rating'),
                        const SizedBox(width: 12),
                        const _StatCard(value: '850', label: 'Points'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── 3. Settings List ──
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.ink0,
                        borderRadius: AppRadius.lgAll,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          _SettingsItem(
                            icon: Icons.credit_card_rounded, iconBg: const Color(0xFFF0F5FF), iconColor: AppColors.info500,
                            label: s.profile_payment, onTap: _onPayment,
                          ),
                          const Divider(height: 1, indent: 64, color: Color(0xFFF1F3F5)),
                          _SettingsItem(
                            icon: Icons.bookmark_outline_rounded, iconBg: const Color(0xFFE8F5E9), iconColor: AppColors.success500,
                            label: 'Alamat Tersimpan', onTap: _onSavedAddresses,
                          ),
                          const Divider(height: 1, indent: 64, color: Color(0xFFF1F3F5)),
                          _SettingsItem(
                            icon: Icons.shield_outlined, iconBg: const Color(0xFFE8F5E9), iconColor: AppColors.success500,
                            label: 'Keamanan & SOS', onTap: _onSafety,
                          ),
                          const Divider(height: 1, indent: 64, color: Color(0xFFF1F3F5)),
                          _SettingsItem(
                            icon: Icons.language_rounded, iconBg: const Color(0xFFF0F5FF), iconColor: AppColors.info500,
                            label: 'Bahasa', trailingText: langLabel, onTap: _onLanguage,
                          ),
                          const Divider(height: 1, indent: 64, color: Color(0xFFF1F3F5)),
                          _SettingsItem(
                            icon: Icons.help_outline_rounded, iconBg: const Color(0xFFFFF3E0), iconColor: AppColors.accent500,
                            label: 'Bantuan', onTap: _onHelp,
                          ),
                          const Divider(height: 1, indent: 64, color: Color(0xFFF1F3F5)),
                          _SettingsItem(
                            icon: Icons.dark_mode_rounded, iconBg: const Color(0xFF1E293B), iconColor: AppColors.ink300,
                            label: 'Mode malam', showChevron: false,
                            trailingWidget: Switch(
                              value: ref.watch(themeModeProvider.notifier).isDark,
                              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                              activeColor: AppColors.primary500,
                            ),
                            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s32),

                    // ── 4. Logout Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _onSignOut,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFFFEBEE), width: 1.5), // Merah sangat pudar untuk border
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: AppColors.danger500, size: 20),
                            const SizedBox(width: 8),
                            Text('Logout', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.danger500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Version text
                    const VersionTapTrigger(),
                    const SizedBox(height: AppSpacing.s32),
                  ],
                ),
              ),
            ),

            // ── 5. Bottom Navigation ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.ink0,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: const _BottomNav(currentIndex: 2), // Index 2 = Profile
            )
          ],
        ),
      ),
    );
  }
}

// ── Komponen Tambahan ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.lgAll,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.h3.copyWith(color: AppColors.primary600, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon, required this.iconBg, required this.iconColor, required this.label,
    this.trailingText, this.trailingWidget, this.showChevron = true, required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? trailingText;
  final Widget? trailingWidget;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: AppRadius.smAll),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink900)),
            ),
            if (trailingText != null) ...[
              Text(trailingText!, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
              const SizedBox(width: 8),
            ],
            if (trailingWidget != null) trailingWidget!,
            if (showChevron) const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink500),
          ],
        ),
      ),
    );
  }
}

// ── Sign Out Sheet ────────────────────────────────────────────────────────────

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet({required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keluar dari RIHLAH?', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            Text('Kamu harus masuk kembali untuk memesan perjalanan.', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(label: 'Keluar', variant: RihlahButtonVariant.danger, onPressed: onConfirm),
            const SizedBox(height: AppSpacing.s8),
            RihlahButton(label: 'Batal', variant: RihlahButtonVariant.secondary, onPressed: onCancel),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav Baru ───────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Activity'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final (activeIcon, inactiveIcon, label) = _items[i];
            final isActive = i == currentIndex;

            return GestureDetector(
              onTap: () {
                if (i == currentIndex) return;
                switch (i) {
                  case 0:
                    while (context.canPop()) { context.pop(); }
                    context.go(Routes.pHome);
                  case 1:
                    context.pushReplacement(Routes.pActivity);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: isActive ? BoxDecoration(
                  color: AppColors.success500,
                  borderRadius: AppRadius.pillAll,
                ) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? activeIcon : inactiveIcon,
                      size: 24,
                      color: isActive ? AppColors.ink0 : AppColors.ink500,
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: isActive ? AppColors.ink0 : AppColors.ink500,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}