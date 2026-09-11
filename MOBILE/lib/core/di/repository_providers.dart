import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore_for_file: unused_import
//
// Some API repository imports are only used when compiled with
// --dart-define=USE_API=true. The Dart compiler tree-shakes unused
// imports; the linter warning is a false positive for this pattern.
import '../../data/repositories/interfaces/itrip_repository.dart';
import '../../data/repositories/interfaces/iuser_repository.dart';
import '../../data/repositories/interfaces/idriver_repository.dart';
import '../../data/repositories/interfaces/ipayment_repository.dart';
import '../../data/repositories/interfaces/ipayout_repository.dart';
import '../../data/repositories/interfaces/ichat_repository.dart';
import '../../data/repositories/interfaces/isos_repository.dart';
import '../../data/repositories/interfaces/ipromo_repository.dart';
import '../../data/repositories/firestore/firestore_trip_repository.dart';
import '../../data/repositories/firestore/firestore_user_repository.dart';
import '../../data/repositories/firestore/firestore_driver_repository.dart';
import '../../data/repositories/firestore/firestore_payment_repository.dart';
import '../../data/repositories/firestore/firestore_payout_repository.dart';
import '../../data/repositories/api/api_payment_repository.dart';
import '../../data/repositories/api/api_payout_repository.dart';
import '../../data/repositories/firestore/firestore_chat_repository.dart';
import '../../data/repositories/firestore/firestore_sos_repository.dart';
import '../../data/repositories/firestore/firestore_promo_repository.dart';

// ── Feature flag ────────────────────────────────────────────────────────────────
//
// Set this to true to use the NestJS API backend instead of Firestore-direct.
// In MVP builds: flutter run --dart-define=USE_API=true
const bool _useApi = bool.fromEnvironment('USE_API', defaultValue: false);

// ── Singleton providers (one instance per app lifetime) ─────────────────────────

final tripRepositoryProvider = Provider<ITripRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiTripRepository not yet built');
  return FirestoreTripRepository();
});

final userRepositoryProvider = Provider<IUserRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiUserRepository not yet built');
  return FirestoreUserRepository();
});

final driverRepositoryProvider = Provider<IDriverRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiDriverRepository not yet built');
  return FirestoreDriverRepository();
});

final paymentRepositoryProvider = Provider<IPaymentRepository>((ref) {
  if (_useApi) return ApiPaymentRepository();
  return FirestorePaymentRepository();
});

final payoutRepositoryProvider = Provider<IPayoutRepository>((ref) {
  if (_useApi) return ApiPayoutRepository();
  return FirestorePayoutRepository();
});

final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiChatRepository not yet built');
  return FirestoreChatRepository();
});

final sosRepositoryProvider = Provider<ISosRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiSosRepository not yet built');
  return FirestoreSosRepository();
});

final promoRepositoryProvider = Provider<IPromoRepository>((ref) {
  if (_useApi) throw UnimplementedError('ApiPromoRepository not yet built');
  return FirestorePromoRepository();
});
