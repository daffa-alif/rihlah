import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../admin_router.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Auth-only — role check happens in AdminShell
      if (!mounted) return;
      context.go(AdminRoutes.dashboard);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'user-not-found' || 'wrong-password' || 'invalid-credential' =>
            'Email atau kata sandi salah.',
          'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
          _ => 'Gagal masuk: ${e.message ?? e.code}',
        };
      });
    } catch (e) {
      debugPrint('Admin login error: $e');
      setState(() {
        _loading = false;
        _error = 'Gagal masuk. Pastikan dokumen users/{uid} '
            'sudah dibuat di Firestore dengan field role = "admin".';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(AppSpacing.s24),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RIHLAH Ops Console',
                        style: AppTypography.h1.copyWith(fontSize: 24)),
                    const SizedBox(height: AppSpacing.s8),
                    Text('Masuk untuk mengelola operasional RIHLAH.',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.ink500)),
                    const SizedBox(height: AppSpacing.s24),
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: AppColors.danger500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!,
                            style: AppTypography.bodySm
                                .copyWith(color: AppColors.danger500)),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Masukkan email yang valid'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Kata sandi'),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Masukkan kata sandi'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: AppColors.ink0))
                            : const Text('Masuk'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
