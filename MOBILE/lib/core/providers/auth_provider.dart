import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stream of auth state changes (null = signed out)
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

// Current signed-in user (null = signed out)
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

// verificationId from FirebaseAuth.verifyPhoneNumber — stored here so
// OtpScreen can read it without being passed as a route param.
final verificationIdProvider = StateProvider<String?>((ref) => null);

// Phone number currently going through OTP (displayed on OTP screen)
final pendingPhoneProvider = StateProvider<String?>((ref) => null);
