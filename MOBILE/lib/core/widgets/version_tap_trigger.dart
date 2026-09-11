import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../dev/dev_menu.dart';

/// Shows the app version; tapping it 7× within ~3s opens the dev menu, in
/// debug builds only. Mirrors Android's classic "tap build number" gesture —
/// replaces the old app-wide 3-finger long-press, which collided with OS
/// accessibility/screenshot gestures on some phones and (unlike this) had no
/// debug-only gate, so it shipped live in release builds too.
class VersionTapTrigger extends StatefulWidget {
  const VersionTapTrigger({super.key});

  @override
  State<VersionTapTrigger> createState() => _VersionTapTriggerState();
}

class _VersionTapTriggerState extends State<VersionTapTrigger> {
  static const _tapsRequired = 7;
  static const _tapWindow = Duration(seconds: 3);

  int _taps = 0;
  DateTime? _firstTapAt;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = 'v${info.version}+${info.buildNumber}');
  }

  void _onTap() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!) > _tapWindow) {
      _firstTapAt = now;
      _taps = 1;
      return;
    }
    _taps++;
    if (_taps >= 3) HapticFeedback.selectionClick();
    if (_taps >= _tapsRequired) {
      _taps = 0;
      _firstTapAt = null;
      HapticFeedback.heavyImpact();
      showDevMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Versi Aplikasi $_version',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
