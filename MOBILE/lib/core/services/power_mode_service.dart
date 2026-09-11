import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects battery saver / low-power mode on Android.
///
/// SRS P-S3: "Position update frequency reduces to 10 s when battery saver
/// detected."  Exposes a [ValueNotifier] that driver screens can read when
/// computing their RTDB write throttle interval.
class PowerModeService {
  PowerModeService._() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static final instance = PowerModeService._();

  static const _channel = MethodChannel('rihlah/power_mode');

  /// Whether the device is currently in battery-saver / low-power mode.
  /// Defaults to `false` until the native side reports back.
  final ValueNotifier<bool> isPowerSaveMode = ValueNotifier(false);

  /// Ask the platform for the current power-save state and start listening
  /// for changes.  Call once during app startup (e.g. from main.dart).
  Future<void> start() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPowerSaveMode');
      if (result != null) isPowerSaveMode.value = result;
    } catch (e) {
      debugPrint('PowerModeService: platform channel unavailable — $e');
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'powerSaveModeChanged':
        final value = call.arguments as bool?;
        if (value != null) isPowerSaveMode.value = value;
        break;
    }
  }
}
