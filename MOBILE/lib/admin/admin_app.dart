import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'admin_router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RIHLAH Ops Console',
      theme: AppTheme.light,
      routerConfig: adminRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
