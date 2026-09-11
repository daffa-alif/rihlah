import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firestore_service.dart';
import '../../data/models/user_model.dart';

final adminAuthStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final adminCurrentUserProvider = Provider<User?>((ref) {
  ref.watch(adminAuthStateProvider); // re-evaluate on auth changes
  return FirebaseAuth.instance.currentUser;
});

/// The signed-in admin's Firestore profile. Null while loading, signed out,
/// or the account has no matching `users/{uid}` doc — callers gate on
/// `.value?.isAdmin == true` rather than juggling error states for the
/// expected "not an admin" case.
final adminProfileProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(adminCurrentUserProvider);
  if (user == null) return null;
  return FirestoreService.instance.getUser(user.uid);
});
