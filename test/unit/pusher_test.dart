import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:femalerider/core/realtime/pusher_client.dart';
import 'package:femalerider/core/realtime/pusher_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory websocket: [server] pushes frames to the client, [sent] records client frames.
class FakeSocket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  final server = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  late final _sink = _FakeSink(this);

  @override
  Stream<dynamic> get stream => server.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void push(Map<String, dynamic> frame) => server.add(jsonEncode(frame));
}

class _FakeSink extends DelegatingStreamSink<dynamic> implements WebSocketSink {
  _FakeSink(this.socket) : super(StreamController<dynamic>());
  final FakeSocket socket;

  @override
  void add(dynamic data) => socket.sent.add(jsonDecode(data as String) as Map<String, dynamic>);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

void main() {
  group('PusherMessage.parse', () {
    test('connection_established with JSON-string data', () {
      final m = PusherMessage.parse(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '123.456', 'activity_timeout': 30}),
      }))!;
      expect(m.isConnectionEstablished, isTrue);
      expect(m.socketId, '123.456');
      expect(m.activityTimeout, 30);
    });

    test('application event on a private channel', () {
      final m = PusherMessage.parse(jsonEncode({
        'event': 'offer.created',
        'channel': 'private-ride.abc',
        'data': jsonEncode({
          'ride_id': 'abc',
          'offer': {'id': 5, 'amount': 450},
        }),
      }))!;
      expect(m.isInternal, isFalse);
      expect(m.channel, 'private-ride.abc');
      expect((m.data['offer'] as Map)['amount'], 450);
    });

    test('map data, ping, errors and malformed frames', () {
      expect(PusherMessage.parse(jsonEncode({'event': 'pusher:ping', 'data': {}}))!.isPing, isTrue);
      final err = PusherMessage.parse(jsonEncode({'event': 'pusher:error', 'data': {'code': 4001, 'message': 'App key not found'}}))!;
      expect(err.isError, isTrue);
      expect(err.errorCode, 4001);
      expect(PusherMessage.parse('not json'), isNull);
      expect(PusherMessage.parse(jsonEncode([1, 2])), isNull);
      expect(PusherMessage.parse(jsonEncode({'data': 'x'})), isNull);
      expect(PusherMessage.parse(42), isNull);
    });

    test('subscribe / pong frames', () {
      expect(jsonDecode(PusherMessage.subscribe('private-trip.1', auth: 'k:s')), {
        'event': 'pusher:subscribe',
        'data': {'channel': 'private-trip.1', 'auth': 'k:s'},
      });
      expect(jsonDecode(PusherMessage.subscribe('public')), {
        'event': 'pusher:subscribe',
        'data': {'channel': 'public'},
      });
      expect(jsonDecode(PusherMessage.pong())['event'], 'pusher:pong');
    });

    test('pusherUri builds the Reverb app URL', () {
      final u = pusherUri(scheme: 'http', host: '10.0.2.2', port: 8080, key: 'abc');
      expect(u.scheme, 'ws');
      expect(u.host, '10.0.2.2');
      expect(u.port, 8080);
      expect(u.path, '/app/abc');
      expect(u.queryParameters['protocol'], '7');
      expect(pusherUri(scheme: 'wss', host: 'x', port: 443, key: 'k').scheme, 'wss');
    });
  });

  group('PusherClient', () {
    test('connects, authorises private channels, answers pings and emits events', () async {
      final socket = FakeSocket();
      final authCalls = <String>[];
      final client = PusherClient(
        uri: () => Uri.parse('ws://localhost:8080/app/key'),
        authorizer: (socketId, channel) async {
          authCalls.add('$socketId|$channel');
          return 'key:sig-$channel';
        },
        connector: (_) => socket,
      );
      final events = <RealtimeEvent>[];
      client.events.listen(events.add);

      await client.subscribe('private-user.1');
      await client.connect();
      expect(client.status, RealtimeStatus.connecting);

      socket.push({'event': 'pusher:connection_established', 'data': jsonEncode({'socket_id': '1.2', 'activity_timeout': 120})});
      await pumpEventQueue();
      expect(client.status, RealtimeStatus.connected);
      expect(authCalls, ['1.2|private-user.1']);
      expect(socket.sent.last, {
        'event': 'pusher:subscribe',
        'data': {'channel': 'private-user.1', 'auth': 'key:sig-private-user.1'},
      });

      socket.push({'event': 'pusher_internal:subscription_succeeded', 'channel': 'private-user.1', 'data': '{}'});
      socket.push({'event': 'pusher:ping', 'data': '{}'});
      socket.push({'event': 'notification.created', 'channel': 'private-user.1', 'data': jsonEncode({'title': 'Hi'})});
      await pumpEventQueue();
      expect(client.subscribedChannels, contains('private-user.1'));
      expect(socket.sent.any((f) => f['event'] == 'pusher:pong'), isTrue);
      expect(events.single.event, 'notification.created');
      expect(events.single.data['title'], 'Hi');

      // Subscribing after connect authorises immediately.
      await client.subscribe('private-ride.r1');
      await pumpEventQueue();
      expect(authCalls.last, '1.2|private-ride.r1');

      client.unsubscribe('private-ride.r1');
      expect(socket.sent.last['event'], 'pusher:unsubscribe');

      await client.dispose();
    });

    test('drops subscription when authorisation fails', () async {
      final socket = FakeSocket();
      final client = PusherClient(
        uri: () => Uri.parse('ws://x/app/k'),
        authorizer: (_, _) async => null,
        connector: (_) => socket,
      );
      await client.subscribe('private-trip.forbidden');
      await client.connect();
      socket.push({'event': 'pusher:connection_established', 'data': jsonEncode({'socket_id': '9.9'})});
      await pumpEventQueue();
      expect(socket.sent.where((f) => f['event'] == 'pusher:subscribe'), isEmpty);
      await client.dispose();
    });

    test('reconnects with backoff after the socket closes and resubscribes', () async {
      final sockets = <FakeSocket>[];
      final client = PusherClient(
        uri: () => Uri.parse('ws://x/app/k'),
        authorizer: (sid, ch) async => 'k:$sid',
        connector: (_) {
          final s = FakeSocket();
          sockets.add(s);
          return s;
        },
      );
      final statuses = <RealtimeStatus>[];
      client.statusStream.listen(statuses.add);
      await client.subscribe('private-trip.t1');
      await client.connect();
      sockets.first.push({'event': 'pusher:connection_established', 'data': jsonEncode({'socket_id': '1.1'})});
      await pumpEventQueue();
      expect(client.isConnected, isTrue);

      await sockets.first.server.close(); // server drops the connection
      await pumpEventQueue();
      expect(client.status, RealtimeStatus.disconnected);

      await Future<void>.delayed(const Duration(milliseconds: 1500)); // first backoff ~1s (+<=30% jitter)
      expect(sockets, hasLength(2));
      sockets.last.push({'event': 'pusher:connection_established', 'data': jsonEncode({'socket_id': '2.2'})});
      await pumpEventQueue();
      expect(client.isConnected, isTrue);
      expect(sockets.last.sent.single, {
        'event': 'pusher:subscribe',
        'data': {'channel': 'private-trip.t1', 'auth': 'k:2.2'},
      });
      expect(statuses, containsAllInOrder([RealtimeStatus.connected, RealtimeStatus.disconnected, RealtimeStatus.connecting, RealtimeStatus.connected]));
      await client.dispose();
    });

    test('exponential backoff is capped at 30s', () {
      expect(PusherClient.backoffFor(0), const Duration(seconds: 1));
      expect(PusherClient.backoffFor(1), const Duration(seconds: 2));
      expect(PusherClient.backoffFor(3), const Duration(seconds: 8));
      expect(PusherClient.backoffFor(6), const Duration(seconds: 30));
      expect(PusherClient.backoffFor(10), const Duration(seconds: 30));
    });
  });
}

