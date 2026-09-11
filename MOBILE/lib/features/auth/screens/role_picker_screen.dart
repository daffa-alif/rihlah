import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import '../../../router.dart';

class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen> {
  String? _selected;
  bool _loading = false;

  // Fungsi ini HANYA mengubah warna visual kartu, tidak langsung berpindah halaman
  void _onRoleTap(String role) {
    if (_loading) return;
    setState(() => _selected = role);
  }

  // Fungsi ini dieksekusi HANYA saat tombol "Continue" ditekan
  Future<void> _onConfirm() async {
    if (_selected == null || _loading) return;

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Kita bungkus pembaruan role dengan try-catch terpisah
        try {
          await FirestoreService.instance.setUserRole(uid, _selected!);
        } catch (e) {
          // Jika error-nya adalah 'not-found', abaikan saja karena dokumen
          // memang belum ada dan akan dibuat di layar Profile Setup/KYC nanti.
          if (e.toString().contains('not-found')) {
            debugPrint('Dokumen pengguna belum ada, lanjut ke pembuatan profil...');
          } else {
            // Jika error lain (misal koneksi putus), lempar error-nya
            rethrow;
          }
        }
      }

      if (!mounted) return;
      // Lanjut navigasi dengan aman ke layar pengisian profil / KYC
      context.go(Routes.profileSetup(_selected!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink0,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.s32),

                  // ── Heading ─────────────────────────────────────────
                  Text(
                    'How will you use\nRIHLAH today?',
                    style: AppTypography.h1.copyWith(fontSize: 28, height: 1.2),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'You can switch any time from Profile.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
                  ),

                  const SizedBox(height: AppSpacing.s32),

                  // ── Passenger card ──────────────────────────────────
                  _RoleListCard(
                    role: 'passenger',
                    title: 'Order a ride',
                    subtitle: 'Cars, bikes, or send a package',
                    bgColor: AppColors.primary100,
                    icon: Icons.directions_walk_rounded,
                    iconColor: AppColors.primary500,
                    isSelected: _selected == 'passenger',
                    onTap: () => _onRoleTap('passenger'),
                  ),

                  const SizedBox(height: AppSpacing.s16),

                  // ── Driver card ─────────────────────────────────────
                  _RoleListCard(
                    role: 'driver',
                    title: 'Drive with us',
                    subtitle: 'Earn on your own schedule',
                    bgColor: const Color(0xFFFEEED6),
                    icon: Icons.directions_car_rounded,
                    iconColor: AppColors.accent500,
                    isSelected: _selected == 'driver',
                    onTap: () => _onRoleTap('driver'),
                  ),

                  const Spacer(),

                  // ── Confirmation Button ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      // Tombol mati (disable) jika belum memilih role
                      onPressed: (_selected == null || _loading) ? null : _onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.ink0,
                        disabledBackgroundColor: AppColors.primary100,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll),
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.ink0,
                          strokeWidth: 2.5,
                        ),
                      )
                          : Text(
                        'Continue',
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role list card (horizontal layout matching mockup) ────────────────────────

class _RoleListCard extends StatelessWidget {
  const _RoleListCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  final String role;
  final String title;
  final String subtitle;
  final Color bgColor;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isSelected ? AppColors.primary500 : AppColors.ink300,
            width: isSelected ? 2 : 1,
          ),
          // Tambahan shadow tipis jika terpilih agar lebih menarik
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary500.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: AppSpacing.s16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),

            // Check indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Container(
                key: const ValueKey('check'),
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary500,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.ink0,
                  size: 16,
                ),
              )
                  : const SizedBox(key: ValueKey('empty'), width: 28, height: 28),
            ),
          ],
        ),
      ),
    );
  }
}