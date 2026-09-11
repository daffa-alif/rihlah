import '../../models/chat_message.dart';

/// Abstract repository for in-trip chat operations.
abstract class IChatRepository {
  /// Stream messages for a trip.
  Stream<List<ChatMessage>> tripMessagesStream(String tripId);

  /// Send a message in a trip's chat thread.
  Future<void> sendTripMessage({
    required String tripId,
    required String senderId,
    required String text,
  });
}
