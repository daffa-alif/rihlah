import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rihlah/core/core.dart';
import 'package:rihlah/router.dart';
import 'package:rihlah/core/providers/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'package:rihlah/core/providers/theme_mode_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/voice_guidance_service.dart';
import 'data/mock/seed_data.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Jika sistem menolak karena Firebase sudah menyala,
    // kita tangkap error-nya di sini dan biarkan aplikasi tetap berjalan.
    print("Firebase peringatan: $e");
  }

  // Connect to Firebase Emulators when running locally.
  // Use: flutter run --dart-define=USE_EMULATOR=true
  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
    FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9001);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }

  // App Check — abuse prevention (SRS §10.2.2)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  // Crashlytics — crash reporting (SRS §4.7)
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Remote Config — feature flags + fare formula tuning (SRS §4.7)
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setDefaults({
    'fare_formula_version': 1,
    'platform_fee_rate': 0.05,
    'max_trip_distance_car': 50,
    'max_trip_distance_bike': 25,
    'enable_surge': false,
    'enable_female_driver_filter': false,
    'min_app_version_android': '0.1.0',
  });
  await remoteConfig.fetchAndActivate();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  HiveRatingSeeder.init(Hive.box('settings'));
  await NotificationService.instance.init();
  await VoiceGuidanceService.instance.init();
  runApp(const ProviderScope(child: RihlahApp()));
}

class RihlahApp extends ConsumerWidget {
  const RihlahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RIHLAH',
      theme: AppTheme.light,
      darkTheme:  AppTheme.dark,                      // ← tambah
      themeMode:  themeMode,
      routerConfig: router,
      locale: locale,                          // ← inject locale
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}