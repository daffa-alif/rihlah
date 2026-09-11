import '../../models/user_model.dart';
import '../../models/saved_address.dart';

/// Abstract repository for user profile operations.
abstract class IUserRepository {
  /// Create or merge a user profile after Firebase Auth signup.
  Future<void> createUserProfile({
    required String uid,
    required String phone,
    String name,
    String role,
  });

  /// Set the user's role claim (passenger / driver / admin).
  Future<void> setUserRole(String uid, String role);

  /// Update the user's display name.
  Future<void> updateUserName(String uid, String name);

  /// Get a single user by UID.
  Future<UserModel?> getUser(String uid);

  /// Stream a user's profile.
  Stream<UserModel?> userStream(String uid);

  /// Update driver KYC/vehicle/BPJS fields.
  Future<void> updateDriverProfile(
    String uid, {
    String? vehicleType,
    String? plate,
    String? ktpNumberMasked,
    String? bpjsKt,
    String? bpjsKs,
    String? bpjsInsurance,
  });

  /// Admin: suspend or activate a user account.
  Future<void> setAccountStatus(String uid, String status);

  /// Admin: stream users by role.
  Stream<List<UserModel>> usersStream({String? role, int limit = 200});

  // ── Saved Addresses (subcollection) ──────────────────────────────────────

  Stream<List<SavedAddress>> addressesStream(String uid);

  Future<void> addAddress(String uid, SavedAddress address);

  Future<void> updateAddress(String uid, SavedAddress address);

  Future<void> removeAddress(String uid, String addressId);
}
