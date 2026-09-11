import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _focusNodes  = List.generate(_length, (_) => FocusNode());

  bool _loading   = false;
  int  _countdown = 60;
  Timer? _timer;

  List<String> get _digits =>
      _controllers.map((c) => c.text.trim()).toList();
  bool get _complete => _digits.every((d) => d.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    final phone = ref.read(pendingPhoneProvider);
    if (phone == null) return;

    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    _startCountdown();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!mounted) return;
        Toast.show(context,
            message: e.message ?? 'Gagal mengirim ulang kode',
            type: ToastType.danger);
      },
      codeSent: (verificationId, _) {
        ref.read(verificationIdProvider.notifier).state = verificationId;
        if (mounted) {
          Toast.show(context,
              message: 'Kode baru telah dikirim', type: ToastType.success);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        ref.read(verificationIdProvider.notifier).state = verificationId;
      },
    );
  }

  void _onChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= _length) {
      for (int i = 0; i < _length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[_length - 1].requestFocus();
      setState(() {});
      _tryAutoVerify();
      return;
    }

    if (value.isEmpty) return;

    _controllers[index].text = digits.isEmpty ? '' : digits[digits.length - 1];
    if (index < _length - 1 && _controllers[index].text.isNotEmpty) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    if (_complete) _tryAutoVerify();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  void _tryAutoVerify() {
    if (_complete && !_loading) {
      Future.delayed(const Duration(milliseconds: 120), _onVerify);
    }
  }

  Future<void> _onVerify() async {
    if (!_complete || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final verificationId = ref.read(verificationIdProvider);
    if (verificationId == null) {
      setState(() => _loading = false);
      Toast.show(context,
          message: 'Sesi kadaluarsa. Minta kode baru.',
          type: ToastType.danger);
      return;
    }

    final smsCode = _digits.join();
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;

      HapticFeedback.mediumImpact();

      final uid   = result.user?.uid;
      final phone = ref.read(pendingPhoneProvider) ?? '';

      if (uid == null) {
        setState(() => _loading = false);
        Toast.show(context,
            message: 'Login gagal. Coba lagi.', type: ToastType.danger);
        return;
      }

      // Create/merge user profile in Firestore
      await FirestoreService.instance.createUserProfile(
        uid: uid,
        phone: phone,
      );

      // Check if user already has a role
      final user = await FirestoreService.instance.getUser(uid);
      if (!mounted) return;

      if (user != null && user.hasRole) {
        if (user.isDriver) {
          context.go(Routes.dHome);
        } else {
          context.go(Routes.pHome);
        }
      } else {
        context.go(Routes.role);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = switch (e.code) {
        'invalid-verification-code' => 'Kode OTP salah. Periksa kembali.',
        'session-expired'           => 'Sesi kadaluarsa. Minta kode baru.',
        'invalid-verification-id'   => 'Sesi tidak valid. Mulai ulang.',
        _                           => e.message ?? 'Verifikasi gagal',
      };
      Toast.show(context, message: msg, type: ToastType.danger);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Toast.show(context,
          message: 'Gagal terhubung. Coba lagi.',
          type: ToastType.danger);
    }
  }

  String get _countdownText {
    final m = _countdown ~/ 60;
    final s = _countdown % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(pendingPhoneProvider) ?? '+62 ***';

    return Scaffold(
      backgroundColor: AppColors.ink0,
      appBar: AppBar(
        backgroundColor: AppColors.ink0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s8),

              Text('Enter the 6-digit code', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.s8),

              Row(
                children: [
                  Text(
                    'Sent to $phone ',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.ink500),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Edit',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),

              // ── OTP boxes ─────────────────────────────────────────────
              Row(
                children: List.generate(_length, (i) {
                  return Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: i < _length - 1 ? 8.0 : 0),
                      child: AspectRatio(
                        aspectRatio: 0.9,
                        child: _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) => _onChanged(i, v),
                          onKeyEvent: (e) => _onKeyEvent(i, e),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.s24),

              Center(
                child: _countdown > 0
                    ? Text(
                        'Resend in $_countdownText',
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.ink500,
                            fontFamily: 'JetBrainsMono'),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: Text(
                          'Resend code',
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
              ),

              const Spacer(),

              AnimatedOpacity(
                opacity: _complete ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _complete && !_loading ? _onVerify : null,
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
                        : Text('Verify',
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

// ── OTP Box ───────────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: filled ? AppColors.ink0 : AppColors.ink100,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: _focused
                ? AppColors.primary500
                : filled
                    ? AppColors.primary500
                    : AppColors.ink300,
            width: _focused ? 2 : 1.5,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
          style: AppTypography.mono.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink900,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
