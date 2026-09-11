import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core.dart';
import '../services/firestore_service.dart';
import '../../data/models/chat_message.dart';

/// Real-time chat between the passenger and driver of a trip, backed by
/// Firestore (`trips/{tripId}/messages`). Used by both trip screens.
class TripChatSheet extends StatefulWidget {
  const TripChatSheet({
    super.key,
    required this.tripId,
    required this.otherName,
  });

  final String tripId;
  final String otherName;

  @override
  State<TripChatSheet> createState() => _TripChatSheetState();
}

class _TripChatSheetState extends State<TripChatSheet> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool  _sending = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final uid  = _uid;
    if (text.isEmpty || uid == null || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      await FirestoreService.instance.sendTripMessage(
        tripId  : widget.tripId,
        senderId: uid,
        text    : text,
      );
    } catch (_) {
      if (mounted) {
        Toast.show(context,
            message: 'Pesan gagal terkirim', type: ToastType.warning);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Text('Chat dengan ${widget.otherName}',
                style: AppTypography.h3),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 320,
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.instance.tripMessagesStream(widget.tripId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 32, color: AppColors.ink300),
                        const SizedBox(height: AppSpacing.s8),
                        Text('Gagal memuat pesan',
                            style: AppTypography.bodyMd
                                .copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                final messages = snap.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Text('Kirim pesan',
                        style: AppTypography.bodyMd
                            .copyWith(color: cs.onSurfaceVariant)),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  children: messages
                      .map((m) => _Bubble(
                          text: m.text, isMe: m.senderId == _uid))
                      .toList(),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                        hintText: 'Ketik pesan…'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded,
                      color: AppColors.primary500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isMe});
  final String text;
  final bool   isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary500 : cs.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
        child: Text(text,
            style: AppTypography.bodyMd.copyWith(
                color: isMe ? AppColors.ink0 : cs.onSurface)),
      ),
    );
  }
}
