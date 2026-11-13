import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

sealed class SessionState {
  const SessionState();
}

/// App just launched; splash is resolving token + /me.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.onboardingSeen = false});
  final bool onboardingSeen;
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.me);
  final MeResult me;
  AppUser get user => me.user;
}

/// Hooks other layers (push, realtime, tracker) register to run on logout.
typedef LogoutHook = Future<void> Function();

/// Owns authentication state: token persistence, `/me`, mode, logout.
class SessionController extends Notifier<SessionState> {
  final List<LogoutHook> _logoutHooks = [];
  StreamSubscription<void>? _unauthSub;
  bool _loggingOut = false;

  @override
  SessionState build() {
    _unauthSub?.cancel();
    _unauthSub = ref.watch(unauthorizedSignalProvider).stream.listen((_) => _handleUnauthorized());
    ref.onDispose(() => _unauthSub?.cancel());
    return const SessionUnknown();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  AppStorage get _storage => ref.read(appStorageProvider);

  MeResult? get me => switch (state) {
        SessionSignedIn(:final me) => me,
        _ => null,
      };

  void addLogoutHook(LogoutHook hook) => _logoutHooks.add(hook);

  /// Restores the session on app start. Throws [ApiException] on network failure
  /// (splash shows retry) — a 401 resolves to signed-out.
  Future<SessionState> bootstrap() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      state = SessionSignedOut(onboardingSeen: await _storage.onboardingSeen());
      return state;
    }
    try {
      final me = await _auth.me();
      state = SessionSignedIn(me);
    } on ApiException catch (e) {
      if (e.isUnauthenticated || e.code.startsWith('account_')) {
        await _storage.writeToken(null);
        state = SessionSignedOut(onboardingSeen: await _storage.onboardingSeen());
      } else {
        rethrow;
      }
    }
    return state;
  }

  /// Called after OTP verification succeeds.
  Future<void> signIn(AuthResult result) async {
    await _storage.writeToken(result.token);
    await _storage.setOnboardingSeen();
    try {
      final me = await _auth.me();
      state = SessionSignedIn(me);
    } catch (_) {
      state = SessionSignedIn(MeResult(user: result.user));
    }
  }

  Future<MeResult?> refreshMe() async {
    if (state is! SessionSignedIn) return null;
    try {
      final me = await _auth.me();
      state = SessionSignedIn(me);
      return me;
    } on ApiException catch (e) {
      debugPrint('refreshMe failed: $e');
      return me;
    }
  }

  void updateUser(AppUser user) {
    final current = me;
    if (current != null) state = SessionSignedIn(current.copyWith(user: user));
  }

  void setActiveTrip(String? tripId) {
    final current = me;
    if (current != null) state = SessionSignedIn(current.copyWith(activeTripId: tripId, clearTrip: tripId == null, clearRide: tripId != null));
  }

  void setActiveRide(String? rideId) {
    final current = me;
    if (current != null) state = SessionSignedIn(current.copyWith(activeRideId: rideId, clearRide: rideId == null));
  }

  void setUnread(int count) {
    final current = me;
    if (current != null) state = SessionSignedIn(current.copyWith(unreadNotifications: count));
  }

  Future<void> markOnboardingSeen() async {
    await _storage.setOnboardingSeen();
    if (state is SessionSignedOut) state = const SessionSignedOut(onboardingSeen: true);
  }

  /// Full logout: unregister push, revoke token server-side, clear local state.
  Future<void> logout({bool callServer = true}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      for (final hook in List.of(_logoutHooks)) {
        try {
          await hook();
        } catch (e) {
          debugPrint('logout hook failed: $e');
        }
      }
      if (callServer) {
        try {
          await _auth.logout(deviceToken: await _storage.fcmToken());
        } catch (_) {}
      }
      await _storage.writeToken(null);
      state = const SessionSignedOut(onboardingSeen: true);
    } finally {
      _loggingOut = false;
    }
  }

  /// Local-only sign out after account deletion request (tokens already revoked server-side).
  Future<void> clearLocal() => logout(callServer: false);

  void _handleUnauthorized() {
    if (state is SessionSignedIn) {
      unawaited(logout(callServer: false));
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience: current user or null.
final currentUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionSignedIn ? s.user : null;
});
