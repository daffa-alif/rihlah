import '../../models/trip_model.dart';

/// Abstract repository for trip lifecycle operations.
/// Implementations: [FirestoreTripRepository] (P2), [ApiTripRepository] (MVP).
abstract class ITripRepository {
  /// Create a new trip (passenger books a ride).
  Future<String> createTrip(Map<String, dynamic> data);

  /// Get a single trip by ID.
  Future<TripModel?> getTrip(String tripId);

  /// Stream a single trip's state (for passenger tracking, driver trip screen).
  Stream<TripModel?> tripStream(String tripId);

  /// Driver accepts a trip.
  Future<void> acceptTrip({required String tripId, required String driverId});

  /// Driver declines (skips) a trip without changing its status.
  Future<void> skipTrip(String tripId, String driverId);

  /// Update trip status to arrived (driver at pickup).
  Future<void> setTripArrived(String tripId);

  /// Update trip status to inTrip (trip has started).
  Future<void> setTripInTrip(String tripId);

  /// Complete a trip.
  Future<void> completeTrip(String tripId);

  /// Cancel a trip.
  Future<void> cancelTrip(String tripId);

  /// Passenger rates a completed trip.
  Future<void> rateTrip({
    required String tripId,
    required int rating,
    required int tip,
    required String review,
  });

  /// Stream of pending (searching) trips a driver can accept.
  Stream<List<TripModel>> pendingTripsStream(
    String serviceType, {
    required String driverId,
  });

  /// Admin: stream all trips, optionally filtered by status.
  Stream<List<TripModel>> allTripsStream({TripStatus? status, int limit = 200});

  /// Stream a passenger's trip history.
  Stream<List<TripModel>> passengerTripsStream(String passengerId, {int limit = 200});

  /// Stream a driver's trip history.
  Stream<List<TripModel>> driverTripsStream(String driverId, {int limit = 200});
}
