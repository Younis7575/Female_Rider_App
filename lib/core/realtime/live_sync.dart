import 'dart:async';

import 'package:flutter/widgets.dart';

import 'realtime_service.dart';

/// Combines socket events with REST reconciliation for critical screens:
///
/// * forwards events from [channels] to [onEvent];
/// * calls [refresh] whenever the socket (re)connects and when the app resumes;
/// * polls [refresh] every [pollInterval] while the socket is disconnected
///   (or always, at [connectedPollInterval], if provided).
class LiveSync with WidgetsBindingObserver {
  LiveSync({
    required this.service,
    required this.channels,
    required this.onEvent,
    required this.refresh,
    this.pollInterval = const Duration(seconds: 5),
    this.connectedPollInterval,
  });

  final RealtimeService service;
  final List<String> channels;
  final void Function(RealtimeEvent event) onEvent;
  final Future<void> Function() refresh;
  final Duration pollInterval;
  final Duration? connectedPollInterval;

  final List<StreamSubscription<RealtimeEvent>> _subs = [];
  Timer? _timer;
  RealtimeStatus? _last;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  bool _disposed = false;

  void start() {
    for (final c in channels) {
      _subs.add(service.channel(c).listen(onEvent));
    }
    _last = service.status.value;
    service.status.addListener(_onStatus);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onStatus() {
    final s = service.status.value;
    if (s == RealtimeStatus.connected && _last != RealtimeStatus.connected) {
      _doRefresh();
    }
    _last = s;
  }

  void _tick() {
    final connected = service.status.value == RealtimeStatus.connected;
    final interval = connected ? connectedPollInterval : pollInterval;
    if (interval == null) return;
    if (DateTime.now().difference(_lastRefresh) >= interval) _doRefresh();
  }

  Future<void> _doRefresh() async {
    if (_busy || _disposed) return;
    _busy = true;
    _lastRefresh = DateTime.now();
    try {
      await refresh();
    } catch (_) {
      // Errors surface through the screen's own state; polling keeps trying.
    } finally {
      _busy = false;
    }
  }

  /// Force a refresh now (e.g. after a user action).
  Future<void> refreshNow() => _doRefresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      service.reconnectNow();
      _doRefresh();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    service.status.removeListener(_onStatus);
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
