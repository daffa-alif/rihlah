import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core.dart';

Future<void> switchRole(
  BuildContext context, {
  required String toRole,       // 'passenger' | 'driver'
  required String targetRoute,  // Routes.pHome | Routes.dHome
}) async {
  // 1. Persist role
  final box = Hive.box('settings');
  await box.put('role', toRole);

  if (!context.mounted) return;

  // 2. Overlay brand-color sweep
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _SweepOverlay(
      onComplete: () {
        entry.remove();
        context.go(targetRoute);
      },
    ),
  );

  overlay.insert(entry);
}

class _SweepOverlay extends StatefulWidget {
  const _SweepOverlay({required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<_SweepOverlay> createState() => _SweepOverlayState();
}

class _SweepOverlayState extends State<_SweepOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fadeIn;
  late Animation<double>   _fadeOut;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn  = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );
    _fadeOut = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = _ctrl.value <= 0.5
            ? _fadeIn.value
            : 1.0 - _fadeOut.value;
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(color: AppColors.primary500),
          ),
        );
      },
    );
  }
}