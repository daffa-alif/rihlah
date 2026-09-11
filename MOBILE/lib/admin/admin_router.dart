import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth/admin_login_screen.dart';
import 'shell/admin_shell.dart';
import 'dashboard/dashboard_screen.dart';
import 'drivers/driver_list_screen.dart';
import 'drivers/driver_detail_screen.dart';
import 'passengers/passenger_detail_screen.dart';
import 'passengers/passenger_list_screen.dart';
import 'trips/trip_list_screen.dart';
import 'payouts/payout_list_screen.dart';
import 'promos/promo_list_screen.dart';
import 'safety/sos_list_screen.dart';
import 'reports/reports_screen.dart';

abstract final class AdminRoutes {
  static const login = '/admin/login';
  static const dashboard = '/admin/dashboard';
  static const drivers = '/admin/drivers';
  static String driverDetail(String uid) => '/admin/drivers/$uid';
  static const passengers = '/admin/passengers';
  static String passengerDetail(String uid) => '/admin/passengers/$uid';
  static const trips = '/admin/trips';
  static const payouts = '/admin/payouts';
  static const promos = '/admin/promos';
  static const safety = '/admin/safety';
  static const reports = '/admin/reports';
}

final adminRouter = GoRouter(
  initialLocation: AdminRoutes.login,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AdminRoutes.login,
      name: 'admin-login',
      builder: (_, __) => const AdminLoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: AdminRoutes.dashboard,
          name: 'admin-dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: AdminRoutes.drivers,
          name: 'admin-drivers',
          builder: (_, __) => const DriverListScreen(),
          routes: [
            GoRoute(
              path: ':uid',
              name: 'admin-driver-detail',
              builder: (_, state) =>
                  DriverDetailScreen(uid: state.pathParameters['uid']!),
            ),
          ],
        ),
        GoRoute(
          path: AdminRoutes.passengers,
          name: 'admin-passengers',
          builder: (_, __) => const PassengerListScreen(),
          routes: [
            GoRoute(
              path: ':uid',
              name: 'admin-passenger-detail',
              builder: (_, state) =>
                  PassengerDetailScreen(uid: state.pathParameters['uid']!),
            ),
          ],
        ),
        GoRoute(
          path: AdminRoutes.trips,
          name: 'admin-trips',
          builder: (_, __) => const TripListScreen(),
        ),
        GoRoute(
          path: AdminRoutes.payouts,
          name: 'admin-payouts',
          builder: (_, __) => const PayoutListScreen(),
        ),
        GoRoute(
          path: AdminRoutes.promos,
          name: 'admin-promos',
          builder: (_, __) => const PromoListScreen(),
        ),
        GoRoute(
          path: AdminRoutes.safety,
          name: 'admin-safety',
          builder: (_, __) => const SosListScreen(),
        ),
        GoRoute(
          path: AdminRoutes.reports,
          name: 'admin-reports',
          builder: (_, __) => const ReportsScreen(),
        ),
      ],
    ),
  ],
);
