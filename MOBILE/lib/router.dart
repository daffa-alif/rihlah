import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/phone_entry_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/role_picker_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/passenger/home/passenger_home_screen.dart';
import 'features/passenger/booking/search_screen.dart';
import 'features/passenger/booking/confirm_screen.dart';
import 'features/passenger/booking/searching_screen.dart';
import 'features/passenger/tracking/trip_screen.dart';
import 'features/passenger/tracking/trip_complete_screen.dart';
import 'features/passenger/history/activity_screen.dart';
import 'features/passenger/profile/profile_screen.dart';
import 'features/passenger/sos/sos_screen.dart';
import 'features/passenger/profile/saved_addresses_screen.dart';
import 'features/passenger/booking/map_picker_screen.dart';
import 'features/passenger/promos/promos_screen.dart';
import 'features/passenger/history/trip_detail_screen.dart';
import 'features/driver/home/driver_home_screen.dart';
import 'features/driver/booking/incoming_order_screen.dart';
import 'features/driver/tracking/driver_trip_screen.dart';
import 'features/driver/tracking/driver_trip_complete_screen.dart';
import 'features/driver/earnings/earnings_screen.dart';
import 'features/driver/profile/driver_profile_screen.dart';
import 'features/driver/history/driver_history_screen.dart';
import 'features/driver/profile/referral_dashboard_screen.dart';
import 'features/passenger/profile/payment_methods_screen.dart';
import 'features/passenger/profile/safety_settings_screen.dart';
import 'features/shared/trip_tracking_screen.dart';

// Import Layar Registrasi KYC Lama
import 'features/auth/screens/face_rec_dummy_screen.dart';

// Import Layar Registrasi KYC Baru
import 'features/auth/screens/driver_requirements_screen.dart';
import 'features/auth/screens/driver_ktp_camera_screen.dart';
import 'features/auth/screens/driver_ktp_form_screen.dart';

// ── Placeholder screen ────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Text(name, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// ── Route name constants ──────────────────────────────────────────────────────
abstract final class Routes {
  // Auth
  static const splash      = '/splash';
  static const onboarding  = '/onboarding';
  static const authPhone   = '/auth/phone';
  static const authOtp     = '/auth/otp';
  static const role        = '/role';
  static String profileSetup(String role) => '/auth/profile-setup/$role';

  // Passenger
  static const pHome       = '/p/home';
  static const pSearch     = '/p/search';
  static const pServices   = '/p/services';
  static const pConfirm    = '/p/confirm';
  static const pSearching  = '/p/searching';
  static String pTrip(String tripId)           => '/p/trip/$tripId';
  static String pTripComplete(String tripId)   => '/p/trip/$tripId/complete';
  static const pActivity   = '/p/activity';
  static String pActivityDetail(String tripId) => '/p/activity/$tripId';
  static const pPromos     = '/p/promos';
  static const pProfile            = '/p/profile';
  static const pProfilePayment     = '/p/profile/payment-methods';
  static const pProfileSafety      = '/p/profile/safety';
  static const pSos            = '/p/sos';
  static const pSavedAddresses = '/p/saved-addresses';

  // Driver
  static const dHome       = '/d/home';
  static String dIncoming(String orderId)      => '/d/incoming/$orderId';
  static String dTrip(String tripId)           => '/d/trip/$tripId';
  static String dTripComplete(String tripId)   => '/d/trip/$tripId/complete';
  static const dEarnings    = '/d/earnings';
  static const dWithdraw    = '/d/earnings/withdraw';
  static const dHistory     = '/d/history';
  static const dProfile     = '/d/profile';
  static const dProfileDocs = '/d/profile/docs';
  static const dReferral    = '/d/profile/referral';

  // Shared
  static String track(String tripId) => '/track/$tripId';
}

// ── Router ────────────────────────────────────────────────────────────────────
final router = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  routes: [
    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.splash,
      name: 'splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.onboarding,
      name: 'onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.authPhone,
      name: 'auth-phone',
      builder: (_, __) => const PhoneEntryScreen(),
    ),
    GoRoute(
      path: Routes.authOtp,
      name: 'auth-otp',
      builder: (_, __) => const OtpScreen(),
    ),
    GoRoute(
      path: Routes.role,
      name: 'role',
      builder: (_, __) => const RolePickerScreen(),
    ),
    GoRoute(
      path: '/auth/profile-setup/:role',
      name: 'profile-setup',
      builder: (_, state) => ProfileSetupScreen(
        role: state.pathParameters['role']!,
      ),
    ),
    GoRoute(
      path: '/auth/face-rec',
      name: 'dummy-face-rec',
      builder: (_, __) => const FaceRecDummyScreen(),
    ),

    // ── KYC Driver Baru ───────────────────────────────────────────────────────
    GoRoute(
      path: '/d/register/terms',
      name: 'dummy-driver-term',
      builder: (_, __) => const DriverRequirementsScreen(),
    ),
    GoRoute(
      path: '/d/register/ktp-cam',
      builder: (_, __) => const DriverKtpCameraScreen(),
    ),
    GoRoute(
      path: '/d/register/ktp-form',
      builder: (_, __) => const DriverKtpFormScreen(),
    ),

    // ── Shared ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/track/:tripId',
      name: 'track',
      builder: (_, state) => TripTrackingScreen(
        tripId: state.pathParameters['tripId']!,
      ),
    ),
    // ── Passenger ────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.pHome,
      name: 'p-home',
      builder: (_, __) => const PassengerHomeScreen(),
    ),
    GoRoute(
      path: Routes.pSearch,
      name: 'p-search',
      builder: (_, __) => const SearchScreen(),
    ),

    GoRoute(
      path: Routes.pConfirm,
      name: 'p-confirm',
      builder: (_, __) => const ConfirmScreen(),
    ),
    GoRoute(
      path: Routes.pSearching,
      name: 'p-searching',
      builder: (_, __) => const SearchingScreen(),
    ),
    GoRoute(
      path: '/p/trip/:tripId',
      name: 'p-trip',
      builder: (_, state) => TripScreen(
        tripId: state.pathParameters['tripId']!,
      ),
      routes: [
        GoRoute(
          path: 'complete',
          name: 'p-trip-complete',
          builder: (_, state) => TripCompleteScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: Routes.pActivity,
      name: 'p-activity',
      builder: (_, __) => const ActivityScreen(),
      routes: [
        GoRoute(
          path: ':tripId',
          name: 'p-activity-detail',
          builder: (_, state) => TripDetailScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: Routes.pPromos,
      name: 'p-promos',
      builder: (_, __) => const PromosScreen(),
    ),
    GoRoute(
      path: Routes.pProfile,
      name: 'p-profile',
      builder: (_, __) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'payment-methods',
          name: 'p-payment-methods',
          builder: (_, __) => const PaymentMethodsScreen(),
        ),
        GoRoute(
          path: 'safety',
          name: 'p-safety',
          builder: (_, __) => const SafetySettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: Routes.pSos,
      name: 'p-sos',
      pageBuilder: (_, state) => BottomSheetPage(
        key: state.pageKey,
        child: const SosScreen(),
      ),
    ),
    GoRoute(
      path: Routes.pSavedAddresses,
      builder: (_, __) => const SavedAddressesScreen(),
    ),
    GoRoute(
      path: '/p/map-picker',
      builder: (context, state) {
        final title =
            state.uri.queryParameters['title'] ?? 'Pilih Lokasi';
        return MapPickerScreen(title: title);
      },
    ),
    // ── Driver ───────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.dHome,
      name: 'd-home',
      builder: (_, __) => const DriverHomeScreen(),
    ),
    GoRoute(
      path: '/d/incoming/:orderId',
      name: 'd-incoming',
      builder: (_, state) => IncomingOrderScreen(
        orderId: state.pathParameters['orderId']!,
      ),
    ),
    GoRoute(
      path: '/d/trip/:tripId',
      name: 'd-trip',
      builder: (_, state) => DriverTripScreen(
        tripId: state.pathParameters['tripId']!,
      ),
      routes: [
        GoRoute(
          path: 'complete',
          name: 'd-trip-complete',
          builder: (_, state) => DriverTripCompleteScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: Routes.dEarnings,
      name: 'd-earnings',
      builder: (_, __) => const EarningsScreen(),
      routes: [
        GoRoute(
          path: 'withdraw',
          name: 'd-withdraw',
          builder: (_, __) =>
          const _Placeholder('Withdraw Sheet'),
        ),
      ],
    ),
    GoRoute(
      path: Routes.dHistory,
      name: 'd-history',
      builder: (_, __) => const DriverHistoryScreen(),
    ),
    GoRoute(
      path: Routes.dProfile,
      name: 'd-profile',
      builder: (_, __) => const DriverProfileScreen(),
      routes: [
        GoRoute(
          path: 'docs',
          name: 'd-docs',
          builder: (_, __) => const DriverDocsScreen(),
        ),
        GoRoute(
          path: 'referral',
          name: 'd-referral',
          builder: (_, __) => const ReferralDashboardScreen(),
        ),
      ],
    ),
  ],
);

// ── Custom page untuk bottom sheet routes ─────────────────────────────────────
class BottomSheetPage<T> extends Page<T> {
  const BottomSheetPage({required this.child, super.key});
  final Widget child;
  @override
  Route<T> createRoute(BuildContext context) {
    return ModalBottomSheetRoute<T>(
      settings: this,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }
}