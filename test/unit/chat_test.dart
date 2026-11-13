import 'package:femalerider/core/notifications/push_service.dart';
import 'package:femalerider/core/router/routes.dart';
import 'package:femalerider/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat thread parses messages, roles and send permission', () {
    final t = ChatThread.fromJson({
      'viewer_role': 'customer',
      'can_send': true,
      'max_length': 500,
      'messages': [
        {'id': 'm1', 'seq': 10, 'sender_role': 'customer', 'body': 'I am at the gate', 'client_id': 'c1', 'read_at': '2026-11-13T10:00:00Z', 'created_at': '2026-11-13T09:59:00Z'},
        {'id': 'm2', 'seq': 11, 'sender_role': 'driver', 'body': 'Coming', 'read_at': null, 'created_at': '2026-11-13T10:00:30Z'},
      ],
    });
    expect(t.canSend, isTrue);
    expect(t.messages, hasLength(2));
    expect(t.messages.first.isMine(t.viewerRole), isTrue);
    expect(t.messages.first.readAt, isNotNull);
    expect(t.messages.last.isMine(t.viewerRole), isFalse);
    expect(t.messages.last.seq, 11);
  });

  test('closed chat thread is read-only', () {
    final t = ChatThread.fromJson({'viewer_role': 'driver', 'can_send': false, 'messages': []});
    expect(t.canSend, isFalse);
    expect(t.maxLength, 500);
  });

  test('chat push opens the trip chat in either mode', () {
    expect(routeForNotification({'screen': 'trip_chat', 'trip_id': 't1'}), Routes.tripChat('t1'));
    expect(routeForNotification({'screen': 'trip_chat', 'trip_id': 't1'}, driverMode: true), Routes.tripChat('t1'));
  });
}
