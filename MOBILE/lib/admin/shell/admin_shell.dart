import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../admin_router.dart';
import '../auth/admin_auth_provider.dart';

class _NavItem {
  const _NavItem(this.icon, this.label, this.path);
  final IconData icon;
  final String label;
  final String path;
}

const _navItems = [
  _NavItem(Icons.dashboard_outlined, 'Dashboard', AdminRoutes.dashboard),
  _NavItem(Icons.two_wheeler_outlined, 'Drivers', AdminRoutes.drivers),
  _NavItem(Icons.people_outline, 'Passengers', AdminRoutes.passengers),
  _NavItem(Icons.receipt_long_outlined, 'Trips', AdminRoutes.trips),
  _NavItem(Icons.payments_outlined, 'Payouts', AdminRoutes.payouts),
  _NavItem(Icons.local_offer_outlined, 'Promos', AdminRoutes.promos),
  _NavItem(Icons.shield_outlined, 'Safety / SOS', AdminRoutes.safety),
  _NavItem(Icons.bar_chart_outlined, 'Reports', AdminRoutes.reports),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _navItems.indexWhere((n) => location.startsWith(n.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(adminCurrentUserProvider);
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AdminRoutes.login);
      });
      return const SizedBox.shrink();
    }

    final profileAsync = ref.watch(adminProfileProvider);

    // Still loading — show spinner
    if (profileAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show Firestore error
    if (profileAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Firestore error: ${profileAsync.error}',
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go(AdminRoutes.login);
                  },
                  child: const Text('Kembali ke login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = profileAsync.valueOrNull;

    // Not admin or doc missing — show message instead of redirect loop
    if (profile == null) {
      final uid = user.uid;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                const Text('Dokumen Firestore tidak ditemukan.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('UID: $uid',
                    style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 8),
                const Text('Buat dokumen di Firestore:'),
                Text('users/$uid',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('dengan field: role = "admin"'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go(AdminRoutes.login);
                  },
                  child: const Text('Kembali ke login'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!profile.isAdmin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Bukan admin.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Role saat ini: "${profile.role}"',
                    style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go(AdminRoutes.login);
                  },
                  child: const Text('Kembali ke login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selected = _selectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(_navItems[i].path),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.ink100,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Column(
                children: [
                  Text('RIHLAH',
                      style: AppTypography.h3.copyWith(
                          color: AppColors.primary500, fontWeight: FontWeight.w800)),
                  Text('Ops Console',
                      style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        child: Text(
                          profile.name,
                          style: AppTypography.bodySm.copyWith(color: AppColors.ink500),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      IconButton(
                        tooltip: 'Keluar',
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: _navItems
                .map((n) => NavigationRailDestination(
                      icon: Icon(n.icon),
                      label: Text(n.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
