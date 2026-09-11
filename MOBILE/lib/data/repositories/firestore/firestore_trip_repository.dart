import '../../../core/services/firestore_service.dart';
import '../../models/trip_model.dart';
import '../interfaces/itrip_repository.dart';

class FirestoreTripRepository implements ITripRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Future<String> createTrip(Map<String, dynamic> data) => _svc.createTrip(data);

  @override
  Future<TripModel?> getTrip(String tripId) => _svc.getTrip(tripId);

  @override
  Stream<TripModel?> tripStream(String tripId) => _svc.tripStream(tripId);

  @override
  Future<void> acceptTrip({required String tripId, required String driverId}) =>
      _svc.acceptTrip(tripId: tripId, driverId: driverId);

  @override
  Future<void> skipTrip(String tripId, String driverId) =>
      _svc.skipTrip(tripId, driverId);

  @override
  Future<void> setTripArrived(String tripId) => _svc.setTripArrived(tripId);

  @override
  Future<void> setTripInTrip(String tripId) => _svc.setTripInTrip(tripId);

  @override
  Future<void> completeTrip(String tripId) => _svc.completeTrip(tripId);

  @override
  Future<void> cancelTrip(String tripId) => _svc.cancelTrip(tripId);

  @override
  Future<void> rateTrip({
    required String tripId,
    required int rating,
    required int tip,
    required String review,
  }) => _svc.rateTrip(tripId: tripId, rating: rating, tip: tip, review: review);

  @override
  Stream<List<TripModel>> pendingTripsStream(
    String serviceType, {
    required String driverId,
  }) => _svc.pendingTripsStream(serviceType, driverId: driverId);

  @override
  Stream<List<TripModel>> allTripsStream({TripStatus? status, int limit = 200}) =>
      _svc.allTripsStream(status: status, limit: limit);

  @override
  Stream<List<TripModel>> passengerTripsStream(String passengerId, {int limit = 200}) =>
      _svc.passengerTripsStream(passengerId, limit: limit);

  @override
  Stream<List<TripModel>> driverTripsStream(String driverId, {int limit = 200}) =>
      _svc.driverTripsStream(driverId, limit: limit);
}
