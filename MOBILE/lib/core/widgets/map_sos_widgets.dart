import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MapPanel — wraps flutter_map with overlay slots (top, bottom, fab)
// ─────────────────────────────────────────────────────────────────────────────

class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.mapWidget,
    this.topOverlay,
    this.bottomOverlay,
    this.fab,
    this.fabPosition = const Offset(16, 16),
  });

  /// Pass your FlutterMap widget here
  final Widget mapWidget;

  /// Pinned to top — e.g. address search bar or status banner
  final Widget? topOverlay;

  /// Pinned to bottom — e.g. driver info card or booking confirmation
  final Widget? bottomOverlay;

  /// Floating action button (e.g. recenter, SOS shortcut)
  final Widget? fab;

  /// Bottom-right offset for FAB from the bottom of the map area
  final Offset fabPosition;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base map
        Positioned.fill(child: mapWidget),

        // Top overlay
        if (topOverlay != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: topOverlay!,
          ),

        // Bottom overlay
        if (bottomOverlay != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: bottomOverlay!,
          ),

        // FAB
        if (fab != null)
          Positioned(
            right: fabPosition.dx,
            bottom: (bottomOverlay != null ? 200 : 0) + fabPosition.dy,
            child: fab!,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SosButton — pulsing red button with 3-second long-press
// ─────────────────────────────────────────────────────────────────────────────

class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onTriggered});

  final VoidCallback onTriggered;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  double _holdProgress = 0;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() { _holding = true; _holdProgress = 0; });
    _runCountdown();
  }

  void _runCountdown() async {
    const totalMs = 3000;
    const stepMs = 50;
    int elapsed = 0;
    while (_holding && elapsed < totalMs) {
      await Future.delayed(const Duration(milliseconds: stepMs));
      if (!_holding) break;
      elapsed += stepMs;
      if (mounted) {
        setState(() => _holdProgress = elapsed / totalMs);
      }
    }
    if (_holding && elapsed >= totalMs && mounted) {
      widget.onTriggered();
    }
    if (mounted) setState(() { _holding = false; _holdProgress = 0; });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() { _holding = false; _holdProgress = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: ScaleTransition(
        scale: _holding ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger500.withOpacity(0.2),
                ),
              ),
              // Progress ring while holding
              if (_holding)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: _holdProgress,
                    strokeWidth: 4,
                    color: AppColors.ink0,
                    backgroundColor: AppColors.danger500,
                  ),
                ),
              // Core button
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger500,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sos_rounded, color: AppColors.ink0, size: 22),
                    Text(
                      'SOS',
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink0,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}