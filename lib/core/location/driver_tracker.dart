import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/driver/data/driver_repository.dart';
import '../config/config_repository.dart';
import '../network/api_envelope.dart';
import 'location_service.dart';

@immutable
class DriverTrackerState {
  const DriverTrackerState({
    this.online = false,
    this.tracking = false,
    this.busy = false,
    this.intervalS = 10,
    this.sequence = 0,
    this.lastFix,
    this.lastSentAt,
    this.activeTripId,
    this.error,
  });

  final bool online;
  final bool tracking;
  final bool busy;
  final int intervalS;
  final int sequence;
  final LocationFix? lastFix;
  final DateTime? lastSentAt;
  final String? activeTripId;
  final String? error;

  DriverTrackerState copyWith({
    bool? online,
    bool? tracking,
    bool? busy,
    int? intervalS,
    int? sequence,
    LocationFix? lastFix,
    DateTime? lastSentAt,
    String? activeTripId,
    bool clearTrip = false,
    String? error,
    bool clearError = false,
  }) =>
      DriverTrackerState(
        online: online ?? this.online,
        tracking: tracking ?? this.tracking,
        busy: busy ?? this.busy,
        intervalS: intervalS ?? this.intervalS,
        sequence: sequence ?? this.sequence,
        lastFix: lastFix ?? this.lastFix,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        activeTripId: clearTrip ? null : (activeTripId ?? this.activeTripId),
        error: clearError ? null : (error ?? this.error),
      );
}

/// Driver availability + location streaming.
///
/// While online (or on an active trip) the latest GPS fix is POSTed to
/// `/driver/location` every `next_interval_s` seconds (server-driven, adaptive),
/// with a strictly increasing `sequence`. Android uses a foreground service so
/// updates continue while the app is backgrounded.
class DriverTracker extends Notifier<DriverTrackerState> {
  StreamSubscription<LocationFix>? _posSub;
  Timer? _timer;
  bool _sending = false;

  @override
  DriverTrackerState build() {
    ref.onDispose(_cancelTimers);
    ref.read(sessionProvider.notifier).addLogoutHook(() async => _stopLoop(reset: true));
    final interval = ref.read(appConfigProvider).location.online;
    return DriverTrackerState(intervalS: interval);
  }

  DriverRepository get _repo => ref.read(driverRepositoryProvider);
  LocationService get _loc => ref.read(locationServiceProvider);

  /// Go online: requires location permission and a fix. Throws [ApiException] on server errors
  /// (e.g. `driver_not_compliant`, `outside_service_area`).
  Future<void> goOnline() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final access = await _loc.ensurePermission(background: true);
      if (access != LocationAccess.granted) {
        throw ApiException(
          message: access == LocationAccess.serviceDisabled
              ? 'Turn on location services to go online.'
              : 'Location permission is required to go online. Enable it in Settings.',
          code: 'location_permission',
        );
      }
      final fix = await _loc.current();
      if (fix == null) {
        throw const ApiException(message: 'We could not get your location. Move to an open area and try again.', code: 'location_unavailable');
      }
      final interval = await _repo.goOnline(fix.lat, fix.lng);
      state = state.copyWith(online: true, busy: false, intervalS: interval, lastFix: fix);
      _ensureLoop();
      _syncSession();
    } catch (e) {
      state = state.copyWith(busy: false, error: errorMessage(e));
      rethrow;
    }
  }

  Future<void> goOffline() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.goOffline();
      state = state.copyWith(online: false, busy: false);
      if (state.activeTripId == null) _stopLoop();
      _syncSession();
    } catch (e) {
      state = state.copyWith(busy: false, error: errorMessage(e));
      rethrow;
    }
  }

  /// Align with server truth (dashboard / me). Starts tracking if the server says online.
  void syncFromServer({required bool online, String? activeTripId}) {
    state = state.copyWith(online: online, activeTripId: activeTripId, clearTrip: activeTripId == null);
    if (online || activeTripId != null) {
      _ensureLoop();
    } else {
      _stopLoop();
    }
  }

  /// Keep sending during an active trip even if the driver toggled offline.
  void attachTrip(String tripId) {
    state = state.copyWith(activeTripId: tripId, intervalS: ref.read(appConfigProvider).location.trip);
    _ensureLoop();
  }

  void detachTrip() {
    state = state.copyWith(clearTrip: true, intervalS: ref.read(appConfigProvider).location.online);
    if (!state.online) _stopLoop();
  }

  /// Keeps `/me` (driver.is_online) in sync after availability changes.
  void _syncSession() {
    if (ref.read(currentUserProvider) == null) return;
    unawaited(ref.read(sessionProvider.notifier).refreshMe());
  }

  void _ensureLoop() {
    if (_timer != null) return;
    state = state.copyWith(tracking: true);
    _posSub ??= _loc.stream(background: true).listen(
      (fix) => state = state.copyWith(lastFix: fix),
      onError: (Object e) => debugPrint('Location stream error: $e'),
    );
    _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    _timer = Timer(immediate ? const Duration(milliseconds: 300) : Duration(seconds: state.intervalS.clamp(2, 60)), _tick);
  }

  Future<void> _tick() async {
    if (_sending) return _schedule();
    // The position stream only emits when the device moves. A stationary driver must still send a
    // fresh heartbeat, so refresh the fix when the last one is getting old.
    var fix = state.lastFix;
    if (fix == null || DateTime.now().difference(fix.timestamp) > const Duration(seconds: 20)) {
      final fresh = await _loc.current();
      if (fresh != null) {
        fix = fresh;
        state = state.copyWith(lastFix: fresh);
      }
    }
    if (fix == null) return _schedule();
    _sending = true;
    final seq = state.sequence + 1;
    try {
      final res = await _repo.sendLocation(
        lat: fix.lat,
        lng: fix.lng,
        heading: fix.heading,
        speed: fix.speed,
        accuracy: fix.accuracy,
        sequence: seq,
        recordedAt: fix.timestamp,
      );
      state = state.copyWith(
        sequence: seq,
        lastSentAt: DateTime.now(),
        intervalS: res.nextIntervalS ?? state.intervalS,
        activeTripId: res.activeTripId,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(sequence: seq, error: e.message);
      if (e.code == 'driver_offline' || e.code == 'driver_not_approved') {
        state = state.copyWith(online: false);
        if (state.activeTripId == null) {
          _sending = false;
          _stopLoop();
          return;
        }
      }
    } catch (e) {
      debugPrint('Location ping failed: $e');
    } finally {
      _sending = false;
    }
    if (_timer != null) _schedule();
  }

  /// Cancels timers/streams without touching state (safe inside onDispose).
  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _posSub?.cancel();
    _posSub = null;
  }

  void _stopLoop({bool reset = false}) {
    _cancelTimers();
    if (reset) {
      state = DriverTrackerState(intervalS: state.intervalS);
    } else {
      state = state.copyWith(tracking: false);
    }
  }
}

final driverTrackerProvider = NotifierProvider<DriverTracker, DriverTrackerState>(DriverTracker.new);
