import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin/admin_app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(child: AdminApp()));
  } catch (e, st) {
    dev.log('Admin app failed to start: $e', error: e, stackTrace: st);
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Startup error: $e',
              style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      ),
    ));
  }
}
