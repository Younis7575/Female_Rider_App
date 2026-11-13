import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../config/config_repository.dart';
import '../network/api_client.dart';
import '../network/json.dart';
import 'pusher_client.dart';
import 'pusher_message.dart';

export 'pusher_client.dart' show RealtimeEvent, RealtimeStatus;

/// Realtime event names broadcast by the backend (`broadcastAs`).
abstract final class RtEvents {
  static const rideRequested = 'ride.requested';
  static const rideUpdated = 'ride.updated';
  static const rideClosed = 'ride.closed';
  static const rideMatching = 'ride.matching';
  static const rideAccepted = 'ride.accepted';
  static const rideCancelled = 'ride.cancelled';
  static const rideExpired = 'ride.expired';
  static const offerCreated = 'offer.created';
  static const offerCountered = 'offer.countered';
  static const offerRejected = 'offer.rejected';
  static const offerWithdrawn = 'offer.withdrawn';
  static const offerExpired = 'offer.expired';
  static const offerAccepted = 'offer.accepted';
  static const tripUpdated = 'trip.updated';
  static const tripLocation = 'trip.location';
  static const tripMessage = 'trip.message';
  static const tripMessagesRead = 'trip.messages_read';
  static const notificationCreated = 'notification.created';
}

/// App-wide realtime connection bound to the signed-in session.
///
/// * Connects after sign-in and subscribes to `realtime_channels.user` and
///   `realtime_channels.driver` exactly as returned by `/me`.
/// * Screens call [channel] to listen to `private-ride.{uuid}` / `private-trip.{uuid}`;
///   subscriptions are reference-counted and dropped when the last listener cancels.
/// * The server remains the source of truth: screens re-fetch over REST whenever
///   [status] transitions back to connected.
class RealtimeService {
  RealtimeService(this._ref) {
    _client = PusherClient(uri: _buildUri, authorizer: _authorize);
    _client.statusStream.listen((s) => _statusNotifier.value = s);
  }

  final Ref _ref;
  late final PusherClient _client;
  final _statusNotifier = ValueNotifier<RealtimeStatus>(RealtimeStatus.disconnected);
  final Map<String, int> _refCounts = {};
  final Set<String> _sessionChannels = {};

  ValueListenable<RealtimeStatus> get status => _statusNotifier;
  bool get isConnected => _client.isConnected;
  Stream<RealtimeEvent> get events => _client.events;

  Uri _buildUri() {
    final env = _ref.read(envProvider);
    final rt = _ref.read(appConfigProvider).realtime;
    final cfgHost = rt?.host ?? '';
    final host = (cfgHost.isEmpty || cfgHost == '127.0.0.1' || cfgHost == 'localhost') ? env.wsHost : cfgHost;
    // Respect the env scheme/port for local hosts; otherwise use the server-advertised values.
    final useEnv = host == env.wsHost;
    return pusherUri(
      scheme: useEnv ? env.wsScheme : (rt?.scheme ?? env.wsScheme),
      host: host,
      port: useEnv ? env.wsPort : (rt?.port ?? env.wsPort),
      key: rt?.key ?? '',
    );
  }

  Future<String?> _authorize(String socketId, String channelName) async {
    final env = await _ref.read(apiClientProvider).post('/broadcasting/auth', data: {'socket_id': socketId, 'channel_name': channelName});
    final data = env.data;
    return data is Map ? asStringOrNull(data['auth']) : null;
  }

  /// Start (or refresh) the session connection.
  Future<void> start({required List<String> sessionChannels}) async {
    final key = _ref.read(appConfigProvider).realtime?.key ?? '';
    if (key.isEmpty) {
      debugPrint('Realtime disabled: no reverb key in /config');
      return;
    }
    for (final c in _sessionChannels.difference(sessionChannels.toSet())) {
      if ((_refCounts[c] ?? 0) == 0) _client.unsubscribe(c);
    }
    _sessionChannels
      ..clear()
      ..addAll(sessionChannels);
    for (final c in sessionChannels) {
      await _client.subscribe(c);
    }
    await _client.connect();
  }

  Future<void> stop() async {
    _sessionChannels.clear();
    _refCounts.clear();
    await _client.disconnect();
  }

  void reconnectNow() => _client.reconnectNow();

  /// Events for one channel; subscribes on first listen, unsubscribes on last cancel.
  Stream<RealtimeEvent> channel(String channelName) {
    late StreamController<RealtimeEvent> controller;
    StreamSubscription<RealtimeEvent>? sub;
    controller = StreamController<RealtimeEvent>(
      onListen: () {
        _refCounts[channelName] = (_refCounts[channelName] ?? 0) + 1;
        unawaited(_client.subscribe(channelName));
        sub = _client.events.where((e) => e.channel == channelName).listen(controller.add);
      },
      onCancel: () async {
        await sub?.cancel();
        final n = (_refCounts[channelName] ?? 1) - 1;
        if (n <= 0) {
          _refCounts.remove(channelName);
          if (!_sessionChannels.contains(channelName)) _client.unsubscribe(channelName);
        } else {
          _refCounts[channelName] = n;
        }
      },
    );
    return controller.stream;
  }

  /// Events on the session channels (user + driver).
  Stream<RealtimeEvent> get sessionEvents => _client.events.where((e) => _sessionChannels.contains(e.channel));

  static String rideChannel(String rideId) => 'private-ride.$rideId';
  static String tripChannel(String tripId) => 'private-trip.$tripId';

  Future<void> dispose() => _client.dispose();
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the realtime connection in sync with the session (connect on sign-in,
/// resubscribe when the driver channel appears, disconnect on sign-out).
final realtimeBinderProvider = Provider<void>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  ref.listen<SessionState>(sessionProvider, (prev, next) {
    if (next is SessionSignedIn) {
      final channels = [?next.user.userChannel, ?next.user.driverChannel];
      unawaited(service.start(sessionChannels: channels));
    } else if (prev is SessionSignedIn) {
      unawaited(service.stop());
    }
  }, fireImmediately: true);
});

/// Rebuilds widgets when the socket connects/disconnects.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  final controller = StreamController<RealtimeStatus>();
  void listener() => controller.add(service.status.value);
  controller.add(service.status.value);
  service.status.addListener(listener);
  ref.onDispose(() {
    service.status.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});
