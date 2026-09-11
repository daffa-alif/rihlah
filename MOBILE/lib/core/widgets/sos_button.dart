// lib/core/widgets/sos_button.dart
//
// Tombol SOS untuk driver. Long-press 3 detik untuk trigger.
// Tampilkan di driver_home_screen (saat online) dan driver_trip_screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/sos_service.dart';
import '../core.dart';

class DriverSosButton extends StatefulWidget {
  const DriverSosButton({
    super.key,
    this.tripId,
    this.mini = false,
  });
  final String? tripId;
  /// mini=true untuk driver_trip_screen (ukuran lebih kecil)
  final bool    mini;

  @override
  State<DriverSosButton> createState() => _DriverSosButtonState();
}

class _DriverSosButtonState extends State<DriverSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _driverId => Hive.box('settings')
      .get('active_driver_id', defaultValue: 'driver-001') as String;

  void _onLongPressStart() {
    HapticFeedback.heavyImpact();
    _pulseCtrl.repeat(reverse: true);

    SosService.instance.startCountdown(
      driverId  : _driverId,
      tripId    : widget.tripId,
      onConfirmed: () {
        _pulseCtrl.stop();
        _pulseCtrl.value = 1.0;
        if (mounted) _showConfirmDialog();
      },
      onCancelled: () {
        _pulseCtrl.stop();
        _pulseCtrl.value = 1.0;
      },
    );
  }

  void _onLongPressEnd() {
    // Jika masih countdown → batalkan
    if (SosService.instance.status == SosStatus.countdown) {
      SosService.instance.cancelCountdown();
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }
  }

  void _showConfirmDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.success500.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success500, size: 40),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('SOS Terkirim',
                style: AppTypography.h2,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Tim RIHLAH dan kontak darurat kamu '
              'sudah diberitahu. Bantuan sedang dalam perjalanan.',
              style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context)
                      .colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.ink0,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SosStatus>(
      valueListenable: SosService.instance.statusNotifier,
      builder: (_, status, __) {
        final isCountdown = status == SosStatus.countdown;
        final isActive    = status != SosStatus.idle
            && status != SosStatus.confirmed;
        final size = widget.mini ? 44.0 : 56.0;
        final iconSize = widget.mini ? 18.0 : 22.0;

        return GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd  : (_) => _onLongPressEnd(),
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: isActive ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple saat countdown
                if (isCountdown)
                  Container(
                    width: size + 16,
                    height: size + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger500.withOpacity(0.2),
                    ),
                  ),
                // Tombol utama
                Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.danger500
                        : AppColors.danger500.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger500.withOpacity(
                            isActive ? 0.5 : 0.3),
                        blurRadius: isActive ? 16 : 8,
                        spreadRadius: isActive ? 4 : 0,
                      ),
                    ],
                  ),
                  child: isCountdown
                      ? _CountdownFace(
                          size    : size,
                          iconSize: iconSize,
                        )
                      : status == SosStatus.recording ||
                              status == SosStatus.sending
                          ? SizedBox(
                              width: iconSize, height: iconSize,
                              child: const CircularProgressIndicator(
                                  color: AppColors.ink0,
                                  strokeWidth: 2.5),
                            )
                          : Icon(Icons.sos_rounded,
                              color: AppColors.ink0,
                              size: iconSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Countdown face ────────────────────────────────────────────────────────────

class _CountdownFace extends StatelessWidget {
  const _CountdownFace({
    required this.size,
    required this.iconSize,
  });
  final double size, iconSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SosService.instance.countdownNotifier,
      builder: (_, remaining, __) => Center(
        child: Text(
          '$remaining',
          style: TextStyle(
            color      : AppColors.ink0,
            fontSize   : size * 0.45,
            fontWeight : FontWeight.w900,
            height     : 1,
          ),
        ),
      ),
    );
  }
}