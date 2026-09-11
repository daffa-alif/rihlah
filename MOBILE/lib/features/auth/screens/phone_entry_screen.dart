import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../router.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  bool _loading     = false;

  String get _digits => _controller.text.replaceAll('-', '');
  bool   get _valid  => _digits.length >= 9 && _digits.length <= 13;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final digits    = raw.replaceAll('-', '');
    final formatted = _formatPhone(digits);
    if (formatted != raw) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  String _formatPhone(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }

  Future<void> _onContinue() async {
    if (!_valid || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // Pastikan awalan +62 ditambahkan ke angka yang diketik
    final phone = '+62$_digits';
    ref.read(pendingPhoneProvider.notifier).state = phone;

    // FUNGSI INI AKAN MENGIRIM SMS SUNGGUHAN KE NOMOR ASLI
    // Syarat: SHA-1 & SHA-256 wajib didaftarkan di Firebase Console
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Jika HP otomatis mendeteksi SMS OTP yang masuk (Auto-resolve)
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          // Jika sukses, Firebase akan otomatis memicu perubahan status Auth
          // dan pengguna akan diarahkan ke Home oleh logika di Splash/Router.
        } catch (_) {}
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        final msg = switch (e.code) {
          'invalid-phone-number' => 'Nomor telepon tidak valid',
          'too-many-requests'    => 'Terlalu banyak percobaan. Coba lagi nanti.',
          'app-not-authorized'   => 'Aplikasi belum terdaftar di Firebase (Cek SHA-1).',
          _                      => e.message ?? 'Verifikasi gagal',
        };
        Toast.show(context, message: msg, type: ToastType.danger);
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() => _loading = false);
        // Simpan Verification ID lalu pindah ke halaman OTP
        ref.read(verificationIdProvider.notifier).state = verificationId;
        context.push(Routes.authOtp);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        ref.read(verificationIdProvider.notifier).state = verificationId;
      },
    );
  }

  void _onCountryChipTap() {
    RihlahSheet.show(
      context,
      title: 'Pilih Negara',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_rounded, size: 48, color: AppColors.ink300),
            const SizedBox(height: AppSpacing.s16),
            Text('Segera Hadir', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Saat ini hanya mendukung nomor Indonesia (+62).',
              style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink0,
      appBar: AppBar(
        backgroundColor: AppColors.ink0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
          onPressed: () => context.go(Routes.onboarding),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s8),

              Text('Sign in', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'We\'ll send a 6-digit code to verify your phone.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.s32),

              Row(
                children: [
                  GestureDetector(
                    onTap: _onCountryChipTap,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.ink300),
                        borderRadius: AppRadius.mdAll,
                        color: AppColors.ink100,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ID',
                              style: AppTypography.label
                                  .copyWith(color: AppColors.ink700)),
                          const SizedBox(width: 4),
                          Text('+62',
                              style: AppTypography.bodyMd.copyWith(
                                  color: AppColors.ink900,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        onChanged: _onChanged,
                        style: AppTypography.mono
                            .copyWith(fontSize: 16, color: AppColors.ink900),
                        decoration: InputDecoration(
                          hintText: '812-3456-7890',
                          hintStyle: AppTypography.mono.copyWith(
                              fontSize: 16, color: AppColors.ink300),
                          filled: true,
                          fillColor: AppColors.ink0,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: const BorderSide(
                                color: AppColors.primary500, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: const BorderSide(
                                color: AppColors.primary500, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s16),
              _TermsText(),
              const Spacer(),

              AnimatedOpacity(
                opacity: _valid ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _valid && !_loading ? _onContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      disabledBackgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.ink0,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink0))
                        : Text('Continue',
                        style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink0)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.bodySm.copyWith(color: AppColors.ink500),
        children: [
          const TextSpan(text: 'By continuing, you agree to RIHLAH\'s '),
          TextSpan(
            text: 'Terms',
            style: AppTypography.bodySm.copyWith(
                color: AppColors.primary500, fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTypography.bodySm.copyWith(
                color: AppColors.primary500, fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}