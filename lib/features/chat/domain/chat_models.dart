import '../../../core/network/json.dart';

/// One customer ⇄ driver chat message (`TripMessage::toPayload`).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.seq,
    required this.senderRole,
    required this.body,
    this.clientId,
    this.readAt,
    this.createdAt,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final int seq;
  final String senderRole;
  final String body;
  final String? clientId;
  final DateTime? readAt;
  final DateTime? createdAt;

  /// Local-only states for optimistic sends.
  final bool pending;
  final bool failed;

  bool isMine(String? viewerRole) => senderRole == viewerRole;

  ChatMessage copyWith({DateTime? readAt, bool? pending, bool? failed}) => ChatMessage(
        id: id,
        seq: seq,
        senderRole: senderRole,
        body: body,
        clientId: clientId,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );

  factory ChatMessage.fromJson(Json j) => ChatMessage(
        id: asString(j['id']),
        seq: asInt(j['seq']),
        senderRole: asString(j['sender_role']),
        body: asString(j['body']),
        clientId: asStringOrNull(j['client_id']),
        readAt: asDate(j['read_at']),
        createdAt: asDate(j['created_at']),
      );
}

class ChatThread {
  const ChatThread({required this.viewerRole, required this.canSend, required this.maxLength, required this.messages});
  final String? viewerRole;
  final bool canSend;
  final int maxLength;
  final List<ChatMessage> messages;

  factory ChatThread.fromJson(Json j) => ChatThread(
        viewerRole: asStringOrNull(j['viewer_role']),
        canSend: asBool(j['can_send']),
        maxLength: asInt(j['max_length'], 500),
        messages: asListOf(j['messages'], ChatMessage.fromJson),
      );
}
