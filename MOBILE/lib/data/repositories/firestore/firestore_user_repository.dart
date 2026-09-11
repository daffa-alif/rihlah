import '../../../core/services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/saved_address.dart';
import '../interfaces/iuser_repository.dart';

class FirestoreUserRepository implements IUserRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Future<void> createUserProfile({
    required String uid,
    required String phone,
    String name = 'Pengguna RIHLAH',
    String role = '',
  }) => _svc.createUserProfile(uid: uid, phone: phone, name: name, role: role);

  @override
  Future<void> setUserRole(String uid, String role) => _svc.setUserRole(uid, role);

  @override
  Future<void> updateUserName(String uid, String name) =>
      _svc.updateUserName(uid, name);

  @override
  Future<UserModel?> getUser(String uid) => _svc.getUser(uid);

  @override
  Stream<UserModel?> userStream(String uid) => _svc.userStream(uid);

  @override
  Future<void> updateDriverProfile(
    String uid, {
    String? vehicleType,
    String? plate,
    String? ktpNumberMasked,
    String? bpjsKt,
    String? bpjsKs,
    String? bpjsInsurance,
  }) => _svc.updateDriverProfile(
    uid,
    vehicleType: vehicleType,
    plate: plate,
    ktpNumberMasked: ktpNumberMasked,
    bpjsKt: bpjsKt,
    bpjsKs: bpjsKs,
    bpjsInsurance: bpjsInsurance,
  );

  @override
  Future<void> setAccountStatus(String uid, String status) =>
      _svc.setAccountStatus(uid, status);

  @override
  Stream<List<UserModel>> usersStream({String? role, int limit = 200}) =>
      _svc.usersStream(role: role, limit: limit);

  @override
  Stream<List<SavedAddress>> addressesStream(String uid) =>
      _svc.addressesStream(uid);

  @override
  Future<void> addAddress(String uid, SavedAddress address) =>
      _svc.addAddress(uid, address);

  @override
  Future<void> updateAddress(String uid, SavedAddress address) =>
      _svc.updateAddress(uid, address);

  @override
  Future<void> removeAddress(String uid, String addressId) =>
      _svc.removeAddress(uid, addressId);
}
