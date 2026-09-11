import '../../models/sos_event_model.dart';

/// Abstract repository for SOS emergency events.
abstract class ISosRepository {
  /// Create a new SOS event in Firestore.
  Future<String> createSosEvent(SosEventModel event);

  /// Admin: update SOS event status (acknowledge).
  Future<void> updateSosEventStatus(String eventId, String status);

  /// Admin: stream all SOS events.
  Stream<List<SosEventModel>> sosEventsStream({int limit = 200});
}
