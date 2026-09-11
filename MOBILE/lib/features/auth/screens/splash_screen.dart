import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../router.dart';
import '../../../core/core.dart';
import 'package:rihlah/core/dev/dev_menu.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  int       _tapCount     = 0;
  DateTime? _firstTapTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNavigation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scheduleNavigation() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      _checkAuth(),
    ]);
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(Routes.onboarding);
      return;
    }

    // Self-heal: restore name from Firebase Auth if Firestore was
    // overwritten to default by old bug (runs on every app start).
    FirestoreService.instance.healUserName(user.uid);

    try {
      final profile = await FirestoreService.instance.getUser(user.uid);
      if (!mounted) return;
      if (profile == null || !profile.hasRole) {
        context.go(Routes.role);
      } else if (profile.isDriver) {
        context.go(Routes.dHome);
      } else {
        context.go(Routes.pHome);
      }
    } catch (_) {
      if (mounted) context.go(Routes.onboarding);
    }
  }

  // ── 5-tap dev trigger ─────────────────────────────────────────────────────

  void _onLogoTap() {
    final now = DateTime.now();
    if (_firstTapTime == null ||
        now.difference(_firstTapTime!) > const Duration(seconds: 2)) {
      _firstTapTime = now;
      _tapCount     = 1;
    } else {
      _tapCount++;
    }
    if (_tapCount >= 5) {
      _tapCount     = 0;
      _firstTapTime = null;
      HapticFeedback.mediumImpact();
      showDevMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary500,
        body: Stack(
          children: [
            // ── Centre — logo + wordmark ──────────────────
            Center(
              child: GestureDetector(
                onTap: _onLogoTap,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) => Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: child,
                    ),
                  ),
                  child: const _Logomark(),
                ),
              ),
            ),

            // ── Bottom — version tag ──────────────────────
            Positioned(
              bottom: 48,
              left: 0, right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, __) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Text(
                    'v1.0 · Prototype',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.ink0.withOpacity(0.45),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logomark ──────────────────────────────────────────────────────────────────

class _Logomark extends StatelessWidget {
  const _Logomark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon — white rounded square with custom logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.ink0,
            borderRadius: AppRadius.xlAll,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink900.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(painter: _RihlahLogoPainter()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s28),

        // Wordmark
        Text(
          'RIHLAH',
          style: AppTypography.displayLg.copyWith(
            color: AppColors.ink0,
            letterSpacing: 6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),

        // Tagline
        Text(
          'YOUR BANDUNG JOURNEY',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.ink0.withOpacity(0.75),
            letterSpacing: 3.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Logo painter — "A" shape with accent dot ──────────────────────────────────

class _RihlahLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final greenPaint = Paint()
      ..color = AppColors.primary500
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = AppColors.accent500
      ..style = PaintingStyle.fill;

    // ── "A" / mountain shape ─────────────────────────────
    // Two diagonal strokes forming an inverted-V (like a location arrow)
    final strokeW = w * 0.135;
    final roofPaint = Paint()
      ..color = AppColors.primary500
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(w * 0.12, h * 0.82)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.88, h * 0.82);

    canvas.drawPath(path, roofPaint);

    // Crossbar
    final crossPaint = Paint()
      ..color = AppColors.primary500
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.85
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.29, h * 0.555),
      Offset(w * 0.71, h * 0.555),
      crossPaint,
    );

    // ── Orange accent dot (below the A) ──────────────────
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.895),
      w * 0.085,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── spacing shim ──────────────────────────────────────────────────────────────
extension on AppSpacing {
  static const s28 = 28.0;
}