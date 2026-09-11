import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier()
      : super(
          Hive.box('settings').get('darkMode', defaultValue: false) as bool
              ? ThemeMode.dark
              : ThemeMode.light,
        );

  Future<void> toggle() async {
    final next = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = next;
    await Hive.box('settings').put('darkMode', next == ThemeMode.dark);
  }

  bool get isDark => state == ThemeMode.dark;
}