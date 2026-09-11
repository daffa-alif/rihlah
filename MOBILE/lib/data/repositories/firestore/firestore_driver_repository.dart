import '../../../core/services/firestore_service.dart';
import '../interfaces/idriver_repository.dart';

class FirestoreDriverRepository implements IDriverRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
    String? tripId,
    double? headingDeg,
  }) => _svc.updateDriverLocation(
    driverId: driverId,
    lat: lat,
    lng: lng,
    tripId: tripId,
    headingDeg: headingDeg,
  );

  @override
  Stream<Map<String, dynamic>?> driverLocationStream(String driverId) =>
      _svc.driverLocationStream(driverId);

  @override
  Future<Map<String, dynamic>?> getDriverLocation(String driverId) =>
      _svc.getDriverLocation(driverId);

  @override
  Future<void> clearDriverLocation(String driverId) =>
      _svc.clearDriverLocation(driverId);

  @override
  Future<int> onlineDriversCount() => _svc.onlineDriversCount();
}
