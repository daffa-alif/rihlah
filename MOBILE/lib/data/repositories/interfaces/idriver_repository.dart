/// Abstract repository for driver location and presence operations.
abstract class IDriverRepository {
  /// Update the driver's live location in RTDB.
  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
    String? tripId,
    double? headingDeg,
  });

  /// Stream the driver's live location from RTDB.
  Stream<Map<String, dynamic>?> driverLocationStream(String driverId);

  /// Get a single snapshot of a driver's location.
  Future<Map<String, dynamic>?> getDriverLocation(String driverId);

  /// Remove the driver's location from RTDB (when going offline).
  Future<void> clearDriverLocation(String driverId);

  /// Admin: count of drivers currently online.
  Future<int> onlineDriversCount();
}
