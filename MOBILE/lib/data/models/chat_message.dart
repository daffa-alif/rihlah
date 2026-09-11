import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final Timestamp? sentAt;

  static String? _str(dynamic v) => v is String ? v : null;
  static Timestamp? _ts(dynamic v) => v is Timestamp ? v : null;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: _str(d['senderId']) ?? '',
      text: _str(d['text']) ?? '',
      sentAt: _ts(d['sentAt']),
    );
  }
}
