import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import '../../../router.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.role});
  final String role;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _controller = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool  _loading    = false;
  String _vehicleType = 'car'; // 'car' | 'bike' — driver only

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        await user.updateDisplayName(name);
        await FirestoreService.instance.updateUserName(user.uid, name);
      }
    } catch (_) {
      // Non-fatal: name can be updated later from profile screen
    }

    if (widget.role == 'driver') {
      await Hive.box('settings').put('service_type', _vehicleType);
      if (user != null) {
        try {
          await FirestoreService.instance.updateDriverProfile(
            user.uid,
            vehicleType: _vehicleType,
          );
        } catch (_) {
          // Non-fatal: vehicle type can be set later from driver docs screen
        }
      }
    }

    if (!mounted) return;

    // ─── LOGIKA ROUTING YANG DIMODIFIKASI ────────────────────────────
    if (widget.role == 'driver') {
      // Jika yang mendaftar adalah driver, arahkan ke halaman Dummy KYC
      context.pushNamed('dummy-driver-term');
    } else {
      // Jika yang mendaftar adalah penumpang, langsung masuk ke beranda
      context.go(Routes.pHome);
    }
    // ─────────────────────────────────────────────────────────────────
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink0,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.s32),

                Text(
                  'What\'s your name?',
                  style: AppTypography.h1.copyWith(fontSize: 28, height: 1.2),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  widget.role == 'driver'
                      ? 'Your name is shown to passengers during trips.'
                      : 'Your name is shown to drivers during trips.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
                ),

                const SizedBox(height: AppSpacing.s32),

                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onContinue(),
                  style: AppTypography.bodyLg,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your name';
                    if (v.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Full name',
                    hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.ink400),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.ink300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.ink300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.primary500, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.danger500),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.danger500, width: 2),
                    ),
                  ),
                ),

                if (widget.role == 'driver') ...[
                  const SizedBox(height: AppSpacing.s32),
                  Text(
                    'What do you drive?',
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: _VehicleTypeCard(
                          icon: Icons.directions_car_rounded,
                          label: 'Mobil',
                          selected: _vehicleType == 'car',
                          onTap: () => setState(() => _vehicleType = 'car'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: _VehicleTypeCard(
                          icon: Icons.two_wheeler_rounded,
                          label: 'Motor',
                          selected: _vehicleType == 'bike',
                          onTap: () => setState(() => _vehicleType = 'bike'),
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.ink0,
                      disabledBackgroundColor: AppColors.primary100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
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
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary100 : AppColors.ink0,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: selected ? AppColors.primary500 : AppColors.ink500),
            const SizedBox(height: AppSpacing.s8),
            Text(label,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary600 : AppColors.ink500,
                )),
          ],
        ),
      ),
    );
  }
}