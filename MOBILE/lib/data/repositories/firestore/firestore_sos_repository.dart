import '../../../core/services/firestore_service.dart';
import '../../models/sos_event_model.dart';
import '../interfaces/isos_repository.dart';

class FirestoreSosRepository implements ISosRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Future<String> createSosEvent(SosEventModel event) =>
      _svc.createSosEvent(event);

  @override
  Future<void> updateSosEventStatus(String eventId, String status) =>
      _svc.updateSosEventStatus(eventId, status);

  @override
  Stream<List<SosEventModel>> sosEventsStream({int limit = 200}) =>
      _svc.sosEventsStream(limit: limit);
}
