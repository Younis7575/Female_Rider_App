import 'dart:convert';

import '../network/json.dart';

/// A decoded Pusher protocol frame.
///
/// Pusher sends `{"event": "...", "channel": "...", "data": "<json string>"}` where
/// `data` is usually a JSON-encoded *string*; we decode it into [data].
class PusherMessage {
  const PusherMessage({required this.event, this.channel, this.data = const {}, this.rawData});

  final String event;
  final String? channel;
  final Json data;
  final Object? rawData;

  bool get isConnectionEstablished => event == 'pusher:connection_established';
  bool get isPing => event == 'pusher:ping';
  bool get isPong => event == 'pusher:pong';
  bool get isError => event == 'pusher:error';
  bool get isSubscriptionSucceeded => event == 'pusher_internal:subscription_succeeded';
  bool get isSubscriptionError => event == 'pusher:subscription_error';
  bool get isInternal => event.startsWith('pusher:') || event.startsWith('pusher_internal:');

  String? get socketId => asStringOrNull(data['socket_id']);
  int? get activityTimeout => asIntOrNull(data['activity_timeout']);
  int? get errorCode => asIntOrNull(data['code']);
  String? get errorMessage => asStringOrNull(data['message']);

  /// Parses a raw websocket frame; returns null for malformed input.
  static PusherMessage? parse(Object? frame) {
    if (frame is! String) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(frame);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final m = asMap(decoded);
    final event = asStringOrNull(m['event']);
    if (event == null) return null;
    final raw = m['data'];
    Json data = const {};
    if (raw is String) {
      if (raw.isNotEmpty) {
        try {
          final d = jsonDecode(raw);
          data = d is Map ? asMap(d) : {'value': d};
        } catch (_) {
          data = {'value': raw};
        }
      }
    } else if (raw is Map) {
      data = asMap(raw);
    }
    return PusherMessage(event: event, channel: asStringOrNull(m['channel']), data: data, rawData: raw);
  }

  static String subscribe(String channel, {String? auth}) => jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': ?auth},
      });

  static String unsubscribe(String channel) => jsonEncode({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channel},
      });

  static String pong() => jsonEncode({'event': 'pusher:pong', 'data': {}});
  static String ping() => jsonEncode({'event': 'pusher:ping', 'data': {}});
}

/// Builds the Reverb/Pusher websocket URL.
Uri pusherUri({required String scheme, required String host, required int port, required String key}) {
  final s = (scheme == 'https' || scheme == 'wss') ? 'wss' : 'ws';
  return Uri(scheme: s, host: host, port: port, path: '/app/$key', queryParameters: {
    'protocol': '7',
    'client': 'dart',
    'version': '1.0',
    'flash': 'false',
  });
}
