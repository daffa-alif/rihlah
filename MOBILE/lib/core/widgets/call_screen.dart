import 'package:flutter/material.dart';
import '../core.dart';
import '../services/call_service.dart';

/// Full-screen in-app voice call UI, shared by both trip screens. Handles
/// placing/ringing, accept/decline for incoming calls, and the in-call
/// controls (mute, hang up).
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.session,
    required this.otherName,
    required this.isIncoming,
  });

  final CallSession session;
  final String otherName;
  final bool isIncoming;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _closing = false;

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    try {
      await widget.session.acceptIncoming();
    } catch (_) {
      // PERBAIKAN: Gunakan pop() untuk menutup secara paksa
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _decline() async {
    await widget.session.decline();
    // PERBAIKAN: Gunakan pop()
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hangUp() async {
    await widget.session.hangUp();
    // PERBAIKAN: Gunakan pop()
    if (mounted) Navigator.of(context).pop();
  }

  void _scheduleAutoClose() {
    if (_closing) return;
    _closing = true;
    Future.delayed(const Duration(seconds: 2), () {
      // PERBAIKAN: Gunakan pop() agar layar otomatis tertutup setelah 2 detik
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _label(CallPhase p) => switch (p) {
    CallPhase.connecting =>
    widget.isIncoming ? 'Panggilan masuk…' : 'Menghubungkan…',
    CallPhase.ringing   => 'Memanggil…',
    CallPhase.connected => 'Tersambung',
    CallPhase.ended     => 'Panggilan berakhir',
    CallPhase.declined  => 'Panggilan ditolak',
    CallPhase.failed    => 'Panggilan gagal',
  };

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Layar dikunci agar tidak tidak sengaja tertutup oleh tombol Back HP
      child: Scaffold(
        backgroundColor: AppColors.ink900,
        body: SafeArea(
          child: ValueListenableBuilder<CallPhase>(
            valueListenable: widget.session.phase,
            builder: (context, phase, _) {
              final terminal = phase == CallPhase.ended ||
                  phase == CallPhase.declined ||
                  phase == CallPhase.failed;

              if (terminal) _scheduleAutoClose();

              final showIncomingActions =
                  widget.isIncoming && phase == CallPhase.connecting;
              final showInCallActions = !terminal && !showIncomingActions;

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.s32),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 96, height: 96,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.primary500),
                      child: Center(
                        child: Text(
                          widget.otherName.isNotEmpty
                              ? widget.otherName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.ink0,
                              fontSize: 36,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(widget.otherName,
                        style: AppTypography.h2
                            .copyWith(color: AppColors.ink0)),
                    const SizedBox(height: AppSpacing.s8),
                    if (phase == CallPhase.connected)
                      ValueListenableBuilder<int>(
                        valueListenable: widget.session.elapsedSeconds,
                        builder: (_, secs, __) => Text(_fmtDuration(secs),
                            style: AppTypography.bodyMd.copyWith(
                                color: AppColors.ink0.withOpacity(0.7))),
                      )
                    else
                      Text(_label(phase),
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.ink0.withOpacity(0.7))),
                    const Spacer(),
                    if (showIncomingActions)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CircleActionButton(
                              icon : Icons.call_end_rounded,
                              color: AppColors.danger500,
                              onTap: _decline),
                          _CircleActionButton(
                              icon : Icons.call_rounded,
                              color: AppColors.success500,
                              onTap: _accept),
                        ],
                      )
                    else if (showInCallActions)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: widget.session.isMuted,
                            builder: (_, muted, __) => _CircleActionButton(
                              icon : muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              color: muted
                                  ? AppColors.ink500 : AppColors.ink700,
                              onTap: widget.session.toggleMute,
                            ),
                          ),
                          _CircleActionButton(
                              icon : Icons.call_end_rounded,
                              color: AppColors.danger500,
                              onTap: _hangUp),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.s24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: AppColors.ink0, size: 28),
      ),
    );
  }
}