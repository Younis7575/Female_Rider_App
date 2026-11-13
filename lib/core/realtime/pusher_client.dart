import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/json.dart';
import 'pusher_message.dart';

enum RealtimeStatus { disconnected, connecting, connected }

/// An application event received on a subscribed channel.
class RealtimeEvent {
  const RealtimeEvent({required this.channel, required this.event, required this.data});
  final String channel;
  final String event;
  final Json data;

  @override
  String toString() => 'RealtimeEvent($channel, $event)';
}

/// Returns the `auth` signature for a private channel, or null if unauthorized.
typedef ChannelAuthorizer = Future<String?> Function(String socketId, String channelName);
typedef SocketConnector = WebSocketChannel Function(Uri uri);

/// Minimal Pusher protocol v7 client for Laravel Reverb.
///
/// * Handles `pusher:connection_established`, ping/pong and activity timeouts.
/// * Authorises `private-*` channels through [authorizer] and resubscribes after reconnects.
/// * Reconnects with exponential backoff (1s → 30s, with jitter).
class PusherClient {
  PusherClient({required this.uri, required this.authorizer, SocketConnector? connector})
      : _connector = connector ?? WebSocketChannel.connect;

  final Uri Function() uri;
  final ChannelAuthorizer authorizer;
  final SocketConnector _connector;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _status = StreamController<RealtimeStatus>.broadcast();
  final Set<String> _desired = {};
  final Set<String> _subscribed = {};

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _socketId;
  RealtimeStatus _current = RealtimeStatus.disconnected;
  Timer? _reconnectTimer;
  Timer? _activityTimer;
  Timer? _pongTimer;
  int _attempt = 0;
  bool _wantConnected = false;
  Duration _activityTimeout = const Duration(seconds: 120);
  final _rng = Random();

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeStatus> get statusStream => _status.stream;
  RealtimeStatus get status => _current;
  bool get isConnected => _current == RealtimeStatus.connected;
  String? get socketId => _socketId;
  Set<String> get subscribedChannels => Set.unmodifiable(_subscribed);

  void _setStatus(RealtimeStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> connect() async {
    _wantConnected = true;
    if (_current != RealtimeStatus.disconnected) return;
    await _open();
  }

  Future<void> _open() async {
    _reconnectTimer?.cancel();
    _setStatus(RealtimeStatus.connecting);
    try {
      final u = uri();
      final ws = _connector(u);
      _ws = ws;
      _wsSub = ws.stream.listen(_onFrame, onError: (Object e) => _onClosed('error: $e'), onDone: () => _onClosed('done'), cancelOnError: true);
      // Surfaces handshake failures (e.g. server down) as errors handled above.
      unawaited(ws.ready.catchError((Object e) => _onClosed('handshake: $e')));
    } catch (e) {
      _onClosed('connect failed: $e');
    }
  }

  void _onFrame(dynamic frame) {
    _resetActivityTimer();
    final msg = PusherMessage.parse(frame);
    if (msg == null) return;
    if (msg.isConnectionEstablished) {
      _socketId = msg.socketId;
      final t = msg.activityTimeout;
      if (t != null && t > 0) _activityTimeout = Duration(seconds: t);
      _attempt = 0;
      _subscribed.clear();
      _setStatus(RealtimeStatus.connected);
      for (final c in _desired.toList()) {
        unawaited(_subscribe(c));
      }
      return;
    }
    if (msg.isPing) {
      _send(PusherMessage.pong());
      return;
    }
    if (msg.isPong) {
      _pongTimer?.cancel();
      return;
    }
    if (msg.isError) {
      debugPrint('Pusher error ${msg.errorCode}: ${msg.errorMessage}');
      // 4000-4099: do not reconnect; 4100-4199: reconnect after backoff; 4200+: reconnect now.
      final code = msg.errorCode ?? 0;
      if (code >= 4000 && code < 4100) {
        _wantConnected = false;
      }
      return;
    }
    if (msg.isSubscriptionSucceeded) {
      if (msg.channel != null) _subscribed.add(msg.channel!);
      return;
    }
    if (msg.isSubscriptionError) {
      if (msg.channel != null) _subscribed.remove(msg.channel!);
      return;
    }
    if (msg.isInternal || msg.channel == null) return;
    if (!_events.isClosed) _events.add(RealtimeEvent(channel: msg.channel!, event: msg.event, data: msg.data));
  }

  void _resetActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer(_activityTimeout, () {
      _send(PusherMessage.ping());
      _pongTimer?.cancel();
      _pongTimer = Timer(const Duration(seconds: 30), () => _onClosed('pong timeout'));
    });
  }

  void _onClosed(String reason) {
    if (_ws == null && _current == RealtimeStatus.disconnected) return;
    debugPrint('Realtime closed: $reason');
    _teardownSocket();
    _setStatus(RealtimeStatus.disconnected);
    if (_wantConnected) _scheduleReconnect();
  }

  void _teardownSocket() {
    _activityTimer?.cancel();
    _pongTimer?.cancel();
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    _socketId = null;
    _subscribed.clear();
  }

  /// Exposed for tests.
  static Duration backoffFor(int attempt, {double jitter = 0}) {
    final base = min(30, pow(2, attempt).toInt());
    return Duration(milliseconds: (base * 1000 * (1 + jitter)).round());
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = backoffFor(_attempt, jitter: _rng.nextDouble() * 0.3);
    _attempt = min(_attempt + 1, 6);
    _reconnectTimer = Timer(delay, () {
      if (_wantConnected && _current == RealtimeStatus.disconnected) _open();
    });
  }

  /// Retry immediately (e.g. app resumed / network back).
  void reconnectNow() {
    if (!_wantConnected) return;
    if (_current == RealtimeStatus.disconnected) {
      _attempt = 0;
      _open();
    }
  }

  Future<void> subscribe(String channel) async {
    _desired.add(channel);
    if (isConnected && !_subscribed.contains(channel)) await _subscribe(channel);
  }

  Future<void> _subscribe(String channel) async {
    final sid = _socketId;
    if (sid == null) return;
    String? auth;
    if (channel.startsWith('private-') || channel.startsWith('presence-')) {
      try {
        auth = await authorizer(sid, channel);
      } catch (e) {
        debugPrint('Channel auth failed for $channel: $e');
        return;
      }
      if (auth == null) return;
    }
    if (_socketId != sid) return; // reconnected meanwhile; will resubscribe.
    _send(PusherMessage.subscribe(channel, auth: auth));
  }

  void unsubscribe(String channel) {
    _desired.remove(channel);
    if (_subscribed.remove(channel) || isConnected) _send(PusherMessage.unsubscribe(channel));
  }

  void _send(String data) {
    try {
      _ws?.sink.add(data);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _desired.clear();
    _teardownSocket();
    _setStatus(RealtimeStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _status.close();
  }
}
