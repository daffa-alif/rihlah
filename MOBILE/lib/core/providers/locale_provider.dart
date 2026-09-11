import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persisted locale provider.
/// Reads initial locale from Hive, defaults to Bahasa Indonesia.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier()
      : super(
          _fromCode(
            Hive.box('settings')
                .get('locale', defaultValue: 'id') as String,
          ),
        );

  static Locale _fromCode(String code) =>
      code == 'en' ? const Locale('en') : const Locale('id');

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await Hive.box('settings').put('locale', locale.languageCode);
  }

  void toggle() {
    final next = state.languageCode == 'id'
        ? const Locale('en')
        : const Locale('id');
    setLocale(next);
  }

  bool get isEnglish => state.languageCode == 'en';
  bool get isIndonesian => state.languageCode == 'id';
}