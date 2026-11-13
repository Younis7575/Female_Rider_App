import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/chat/data/chat_repository.dart';
import '../config/env.dart';
import '../network/json.dart';
import '../router/routes.dart';
import '../storage/secure_store.dart';

const kNotificationChannelId = 'femalerider_default';
const kNotificationChannelName = 'FemaleRider updates';

/// Set by `main()` after attempting `Firebase.initializeApp()`.
bool firebaseAvailable = false;

/// Background FCM handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  // Notification messages are displayed by the OS; data-only messages are
  // reconciled via REST when the app next opens.
}

/// Maps a push/notification `data` payload to an in-app route.
String routeForNotification(Map<String, dynamic> data, {bool driverMode = false}) {
  final screen = asString(data['screen']);
  final tripId = asStringOrNull(data['trip_id']);
  final rideId = asStringOrNull(data['ride_id']);
  switch (screen) {
    case 'trip':
      return tripId != null ? (driverMode ? Routes.driverTrip(tripId) : Routes.trip(tripId)) : Routes.home;
    case 'trip_chat':
      return tripId != null ? Routes.tripChat(tripId) : (driverMode ? Routes.driverHome : Routes.home);
    case 'driver_trip':
      return tripId != null ? Routes.driverTrip(tripId) : Routes.driverHome;
    case 'trip_receipt':
      return tripId != null ? (driverMode ? Routes.tripDetail(tripId) : Routes.receipt(tripId)) : Routes.historyBase;
    case 'ride_offers':
      return rideId != null ? Routes.matching(rideId) : Routes.home;
    case 'driver_requests':
      return Routes.driverRequests;
    case 'driver_earnings':
      return Routes.driverEarnings;
    case 'driver_documents':
      return Routes.driverDocuments;
    case 'driver_application':
      return Routes.driverApplicationStatus;
    case 'verification':
      return Routes.verification;
    case 'payments':
      return Routes.payments;
    case 'home':
      return driverMode ? Routes.driverHome : Routes.home;
    default:
      return Routes.notifications;
  }
}

/// Firebase Cloud Messaging + local notifications.
///
/// Runs in "disabled" mode (no-ops) when Firebase is not configured
/// (no google-services.json / GoogleService-Info.plist).
class PushService {
  PushService(this._ref);
  final Ref _ref;

  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  bool _localReady = false;
  bool _started = false;
  String? _pendingRoute;
  StreamSubscription<String>? _refreshSub;
  String? _registeredToken;

  /// Routes requested by notification taps.
  Stream<String> get taps => _taps.stream;

  /// Route from a tap that launched the app (consumed once by the router).
  String? takePendingRoute() {
    final r = _pendingRoute;
    _pendingRoute = null;
    return r;
  }

  bool get enabled => firebaseAvailable;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    await _initLocal();
    if (!firebaseAvailable) {
      debugPrint('Push disabled: Firebase not configured.');
      return;
    }
    try {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _emitTap(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingRoute = _routeFor(initial.data);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: true);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> _initLocal() async {
    try {
      const android = AndroidInitializationSettings('ic_notification');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (resp) {
          final payload = resp.payload;
          if (payload == null) return;
          try {
            _emitTap(asMap(jsonDecode(payload)));
          } catch (_) {}
        },
      );
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true && launch?.notificationResponse?.payload != null) {
        try {
          _pendingRoute = _routeFor(asMap(jsonDecode(launch!.notificationResponse!.payload!)));
        } catch (_) {}
      }
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            kNotificationChannelId,
            kNotificationChannelName,
            description: 'Ride offers, trip progress, payments and safety alerts',
            importance: Importance.high,
          ));
      _localReady = true;
    } catch (e) {
      debugPrint('Local notifications init failed: $e');
    }
  }

  String _routeFor(Map<String, dynamic> data) {
    final user = _ref.read(currentUserProvider);
    return routeForNotification(data, driverMode: user?.isDriverMode ?? false);
  }

  void _emitTap(Map<String, dynamic> data) => _taps.add(_routeFor(data));

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    // No banner for messages of the chat that is already open.
    if (asString(m.data['type']) == 'trip.message' && asStringOrNull(m.data['trip_id']) == OpenChat.tripId) return;
    final n = m.notification;
    await showLocal(title: n?.title ?? asString(m.data['title'], 'FemaleRider'), body: n?.body ?? asString(m.data['body']), data: m.data);
  }

  Future<void> showLocal({required String title, String? body, Map<String, dynamic> data = const {}}) async {
    if (!_localReady) return;
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kNotificationChannelId,
            kNotificationChannelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
            color: Color(0xFFC8102E),
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('showLocal failed: $e');
    }
  }

  /// Ask for permission, fetch the FCM token and register it with the API.
  Future<void> registerForSignedInUser() async {
    if (!firebaseAvailable) return;
    final messaging = FirebaseMessaging.instance;
    // Listen for token rotation first so no refresh is missed.
    await _refreshSub?.cancel();
    // ignore: deprecated_member_use
    _refreshSub = messaging.onTokenRefresh.listen((t) => unawaited(_register(t)));

    // Ask for permission without blocking token registration on the user's answer
    // (FCM tokens are issued regardless; permission only controls display).
    unawaited(_requestPermissions());

    // The backend sends via FCM HTTP v1 to registration tokens, so we use the classic
    // token API (deprecated in favour of FID-based register()/onRegistered).
    // On iOS the APNs token can arrive a few seconds after launch, so retry briefly.
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        if (Platform.isIOS && await messaging.getAPNSToken() == null) {
          throw StateError('APNs token not yet available');
        }
        // ignore: deprecated_member_use
        final token = await messaging.getToken();
        if (token != null) {
          await _register(token);
          return;
        }
      } catch (e) {
        debugPrint('FCM token attempt ${attempt + 1} failed: $e');
      }
      await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
      if (_ref.read(sessionProvider) is! SessionSignedIn) return;
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) debugPrint('Push permission denied');
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> _register(String token) async {
    final storage = _ref.read(appStorageProvider);
    await storage.setFcmToken(token);
    if (_ref.read(sessionProvider) is! SessionSignedIn) return;
    if (_registeredToken == token) return; // already registered for this session
    _registeredToken = token;
    try {
      await _ref.read(accountRepositoryProvider).registerDevice(
            token: token,
            platform: Platform.isIOS ? 'ios' : 'android',
            deviceId: await storage.deviceId(),
            deviceName: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.characters100,
            appVersion: Env.current.appVersion,
          );
    } catch (e) {
      debugPrint('POST /devices failed: $e');
      _registeredToken = null;
      return;
    }
    debugPrint('Push: device token registered with the API.');
  }

  /// Logout hook: unregister this device so the account stops receiving pushes here.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    _registeredToken = null;
    final storage = _ref.read(appStorageProvider);
    final token = await storage.fcmToken();
    if (token == null) return;
    try {
      await _ref.read(accountRepositoryProvider).removeDevice(token);
    } catch (_) {}
  }
}

extension on String {
  String get characters100 => length > 100 ? substring(0, 100) : this;
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.read(sessionProvider.notifier).addLogoutHook(service.unregister);
  return service;
});

/// Registers the device whenever a user signs in.
final pushBinderProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  ref.listen<SessionState>(sessionProvider, (prev, next) {
    if (next is SessionSignedIn && prev is! SessionSignedIn) {
      unawaited(push.registerForSignedInUser());
    }
  }, fireImmediately: true);
});
