import '../../../core/services/firestore_service.dart';
import '../../models/chat_message.dart';
import '../interfaces/ichat_repository.dart';

class FirestoreChatRepository implements IChatRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Stream<List<ChatMessage>> tripMessagesStream(String tripId) =>
      _svc.tripMessagesStream(tripId);

  @override
  Future<void> sendTripMessage({
    required String tripId,
    required String senderId,
    required String text,
  }) => _svc.sendTripMessage(tripId: tripId, senderId: senderId, text: text);
}
