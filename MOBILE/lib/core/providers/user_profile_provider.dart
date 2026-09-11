import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../di/repository_providers.dart';
import 'auth_provider.dart';

/// The signed-in user's real profile (`users/{uid}`) — the single source of
/// truth for display name/photo/role. Uses the IUserRepository interface so
/// the backend can be swapped via `--dart-define=USE_API=true`.
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  final repo = ref.watch(userRepositoryProvider);
  return repo.userStream(uid);
});
