import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.bgColor,
    required this.accentColor,
  });
  final String title;
  final String subtitle;
  final Widget illustration;
  final Color bgColor;
  final Color accentColor;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardingPage> _buildPages(AppLocalizations s) => [
    _OnboardingPage(
      title: s.onboarding_title_1,
      subtitle: s.onboarding_sub_1,
      bgColor: AppColors.primary100,
      accentColor: AppColors.primary500,
      illustration: const _IllustrationCity(),
    ),
    _OnboardingPage(
      title: s.onboarding_title_2,
      subtitle: s.onboarding_sub_2,
      bgColor: AppColors.primary100,
      accentColor: AppColors.primary500,
      illustration: const _IllustrationReceipt(),
    ),
    _OnboardingPage(
      title: s.onboarding_title_3,
      subtitle: s.onboarding_sub_3,
      bgColor: AppColors.primary100,
      accentColor: AppColors.primary500,
      illustration: const _IllustrationSafe(),
    ),
  ];

  void _goToAuth() => context.go(Routes.authPhone);

  void _nextPage(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToAuth();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s     = AppLocalizations.of(context);
    final pages = _buildPages(s);
    final page  = pages[_currentPage];
    final isLast = _currentPage == pages.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: page.bgColor,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: page.bgColor,
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                    vertical: AppSpacing.s16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo wordmark
                      Text(
                        'RIHLAH',
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink900.withOpacity(0.6),
                          letterSpacing: 4,
                        ),
                      ),
                      // Skip button
                      if (!isLast)
                        TextButton(
                          onPressed: _goToAuth,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary500.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                          ),
                          child: Text(
                            s.onboarding_skip,
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.ink900.withOpacity(0.7),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 60),
                    ],
                  ),
                ),

                // ── Page view ─────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => _OnboardingCard(page: pages[i]),
                  ),
                ),

                // ── Bottom controls ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24, AppSpacing.s24,
                    AppSpacing.s24, AppSpacing.s32,
                  ),
                  child: Column(
                    children: [
                      // Dot indicator
                      _DotIndicator(
                        count: pages.length,
                        current: _currentPage,
                        activeColor: page.accentColor,
                      ),
                      const SizedBox(height: AppSpacing.s32),
                      // CTA button
                      _OnboardingButton(
                        label: isLast ? s.onboarding_start : s.onboarding_next,
                        accentColor: page.accentColor,
                        onTap: () => _nextPage(pages.length),
                      ),
                    ],
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

// ── Onboarding card ───────────────────────────────────────────────────────────

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});
  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: Column(
        children: [
          // Illustration
          Expanded(
            flex: 5,
            child: Center(child: page.illustration),
          ),
          // Text content
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.title,
                  style: AppTypography.displayLg.copyWith(
                    color: AppColors.ink900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  page.subtitle,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.ink900.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
  });
  final int count;
  final int current;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : AppColors.ink900.withOpacity(0.3),
            borderRadius: AppRadius.pillAll,
          ),
        );
      }),
    );
  }
}

// ── CTA button ────────────────────────────────────────────────────────────────

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: AppColors.ink900.withOpacity(0.15),
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.ink900.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.ink900.withOpacity(0.3),
                width: 1,
              ),
              borderRadius: AppRadius.mdAll,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Illustrations (SVG-style custom paint) ────────────────────────────────────

// Card 1 — City skyline with car + bike
class _IllustrationCity extends StatelessWidget {
  const _IllustrationCity();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(painter: _CityPainter()),
    );
  }
}

class _CityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = AppColors.primary500.withOpacity(0.9);
    final faint = AppColors.primary500.withOpacity(0.2);
    final accent = AppColors.accent500;
    final p = Paint()..style = PaintingStyle.fill;

    // Ground
    p.color = AppColors.primary500.withOpacity(0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.75, w, h * 0.25),
        const Radius.circular(16),
      ),
      p,
    );

    // Buildings (back layer)
    p.color = faint;
    _rect(canvas, p, w * 0.05, h * 0.38, w * 0.13, h * 0.37);
    _rect(canvas, p, w * 0.20, h * 0.28, w * 0.10, h * 0.47);
    _rect(canvas, p, w * 0.55, h * 0.32, w * 0.12, h * 0.43);
    _rect(canvas, p, w * 0.72, h * 0.22, w * 0.09, h * 0.53);
    _rect(canvas, p, w * 0.84, h * 0.38, w * 0.13, h * 0.37);

    // Buildings (front layer)
    p.color = AppColors.primary500.withOpacity(0.12);
    _rect(canvas, p, w * 0.00, h * 0.50, w * 0.18, h * 0.25);
    _rect(canvas, p, w * 0.32, h * 0.42, w * 0.20, h * 0.33);
    _rect(canvas, p, w * 0.64, h * 0.46, w * 0.16, h * 0.29);

    // Windows
    p.color = accent.withOpacity(0.5);
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              w * 0.35 + col * w * 0.055,
              h * 0.46 + row * h * 0.07,
              w * 0.035,
              h * 0.04,
            ),
            const Radius.circular(2),
          ),
          p,
        );
      }
    }

    // Road line
    p.color = AppColors.primary500.withOpacity(0.15);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.75, w, 2), p);

    // Dashes on road
    p.color = AppColors.primary500.withOpacity(0.25);
    for (int i = 0; i < 6; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05 + i * w * 0.16, h * 0.835, w * 0.08, 3),
          const Radius.circular(2),
        ),
        p,
      );
    }

    // Car (simple block)
    p.color = white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.70, w * 0.28, h * 0.10),
        const Radius.circular(6),
      ),
      p,
    );
    // Car cabin
    p.color = AppColors.primary100.withOpacity(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.665, w * 0.16, h * 0.07),
        const Radius.circular(5),
      ),
      p,
    );
    // Car wheels
    p.color = AppColors.ink900.withOpacity(0.6);
    canvas.drawCircle(Offset(w * 0.25, h * 0.815), w * 0.038, p);
    canvas.drawCircle(Offset(w * 0.40, h * 0.815), w * 0.038, p);

    // Bike (simple shape)
    p.color = accent;
    canvas.drawCircle(Offset(w * 0.67, h * 0.805), w * 0.03, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent);
    canvas.drawCircle(Offset(w * 0.76, h * 0.805), w * 0.03, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent);
    p.color = accent;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.5;
    final bikePath = Path()
      ..moveTo(w * 0.67, h * 0.805)
      ..lineTo(w * 0.715, h * 0.755)
      ..lineTo(w * 0.76, h * 0.805);
    canvas.drawPath(bikePath, p);
  }

  void _rect(Canvas c, Paint p, double x, double y, double w, double h) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// Card 2 — Receipt + handshake
class _IllustrationReceipt extends StatelessWidget {
  const _IllustrationReceipt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(painter: _ReceiptPainter()),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = AppColors.primary500;
    final faint = AppColors.primary500.withOpacity(0.15);
    final accent = AppColors.accent500;
    final p = Paint()..style = PaintingStyle.fill;

    // Receipt card shadow
    p.color = AppColors.primary500.withOpacity(0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.10, w * 0.72, h * 0.65),
        const Radius.circular(16),
      ),
      p,
    );

    // Receipt card
    p.color = AppColors.primary500.withOpacity(0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.72, h * 0.65),
        const Radius.circular(16),
      ),
      p,
    );

    // Receipt header bar
    p.color = AppColors.primary500.withOpacity(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.72, h * 0.12),
        const Radius.circular(16),
      ),
      p,
    );

    // Title text line
    p.color = white.withOpacity(0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.125, w * 0.22, h * 0.04),
        const Radius.circular(3),
      ),
      p,
    );

    // Line items
    final lineY = [0.26, 0.34, 0.42];
    for (final y in lineY) {
      p.color = faint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.20, h * y, w * 0.28, h * 0.028),
          const Radius.circular(3),
        ),
        p,
      );
      p.color = white.withOpacity(0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.60, h * y, w * 0.18, h * 0.028),
          const Radius.circular(3),
        ),
        p,
      );
    }

    // Divider
    p.color = AppColors.primary500.withOpacity(0.1);
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.52, w * 0.60, 1), p);

    // Total row (highlighted)
    p.color = AppColors.primary500.withOpacity(0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.555, w * 0.68, h * 0.055),
        const Radius.circular(6),
      ),
      p,
    );
    p.color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.60, h * 0.562, w * 0.18, h * 0.038),
        const Radius.circular(3),
      ),
      p,
    );

    // Checkmark circle at bottom
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent;
    canvas.drawCircle(Offset(w * 0.50, h * 0.84), w * 0.09, checkPaint);
    final checkPath = Path()
      ..moveTo(w * 0.44, h * 0.84)
      ..lineTo(w * 0.48, h * 0.88)
      ..lineTo(w * 0.57, h * 0.79);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// Card 3 — Shield + SOS
class _IllustrationSafe extends StatelessWidget {
  const _IllustrationSafe();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(painter: _SafePainter()),
    );
  }
}

class _SafePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final danger = AppColors.primary500;
    final white = AppColors.ink0;

    // Outer glow ring
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.30,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primary500.withOpacity(0.08),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.22,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primary500.withOpacity(0.12),
    );

    // Shield body
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.50, h * 0.12);
    shieldPath.lineTo(w * 0.72, h * 0.22);
    shieldPath.lineTo(w * 0.72, h * 0.46);
    shieldPath.quadraticBezierTo(w * 0.72, h * 0.62, w * 0.50, h * 0.72);
    shieldPath.quadraticBezierTo(w * 0.28, h * 0.62, w * 0.28, h * 0.46);
    shieldPath.lineTo(w * 0.28, h * 0.22);
    shieldPath.close();

    canvas.drawPath(
      shieldPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primary500.withOpacity(0.25),
    );
    canvas.drawPath(
      shieldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.primary500.withOpacity(0.7),
    );

    // SOS text inside shield
    final textPainter = TextPainter(
      text: TextSpan(
        text: '✓',
        style: TextStyle(
          color: AppColors.primary100,
          fontSize: w * 0.19,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(w * 0.50 - textPainter.width / 2, h * 0.30),
    );

    // Pulse rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.44),
        w * (0.30 + i * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.accent500.withOpacity(0.49 / i),
      );
    }

    // Bottom: 3 small feature chips
    final chipLabels = ['Verifikasi', 'Live Share', 'SOS 1-tap'];
    for (int i = 0; i < 3; i++) {
      final x = w * (0.08 + i * 0.32);
      // chip bg
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.82, w * 0.26, h * 0.08),
          const Radius.circular(999),
        ),
        Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.primary500.withOpacity(0.08),
      );
      // chip text
      final tp = TextPainter(
        text: TextSpan(
          text: chipLabels[i],
          style: TextStyle(
            color: AppColors.primary600.withOpacity(0.6),
            fontSize: w * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x + (w * 0.26 - tp.width) / 2, h * 0.845),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}