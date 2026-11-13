import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/notifications/push_service.dart';
import 'core/realtime/realtime_service.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'features/auth/presentation/session_controller.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class FemaleRiderApp extends ConsumerStatefulWidget {
  const FemaleRiderApp({super.key});

  @override
  ConsumerState<FemaleRiderApp> createState() => _FemaleRiderAppState();
}

class _FemaleRiderAppState extends ConsumerState<FemaleRiderApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _tapSub;
  StreamSubscription<RealtimeEvent>? _rtSub;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);
    unawaited(push.init());
    _tapSub = push.taps.listen(_openRoute);
    _rtSub = ref.read(realtimeServiceProvider).sessionEvents.listen(_onSessionEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _rtSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      ref.read(realtimeServiceProvider).reconnectNow();
      unawaited(ref.read(sessionProvider.notifier).refreshMe());
    }
  }

  void _openRoute(String route) {
    if (ref.read(sessionProvider) is! SessionSignedIn) return;
    ref.read(routerProvider).push(route);
  }

  /// App-wide reactions to user/driver channel events (screens handle their own channels).
  void _onSessionEvent(RealtimeEvent e) {
    final session = ref.read(sessionProvider.notifier);
    final push = ref.read(pushServiceProvider);
    switch (e.event) {
      case RtEvents.notificationCreated:
        final me = session.me;
        if (me != null) session.setUnread(me.unreadNotifications + 1);
        final n = e.data['notification'] is Map ? Map<String, dynamic>.from(e.data['notification'] as Map) : e.data;
        final type = n['type']?.toString() ?? '';
        final title = n['title']?.toString() ?? 'FemaleRider';
        if (_lifecycle != AppLifecycleState.resumed) {
          push.showLocal(title: title, body: n['body']?.toString(), data: Map<String, dynamic>.from(n['data'] as Map? ?? const {}));
        }
        // Account/driver status changes alter what the user may access: re-fetch /me so the
        // router guards move her to the right place (e.g. verification approved → customer home).
        if (type == 'account.verification' || type == 'account.status' || type == 'driver.status') {
          unawaited(session.refreshMe());
          if (_lifecycle == AppLifecycleState.resumed) {
            scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(title)));
          }
        }
      case RtEvents.rideRequested:
        final ride = e.data['ride'];
        final fare = ride is Map ? ride['proposed_fare'] : null;
        final currency = ride is Map ? (ride['currency']?.toString() ?? 'PKR') : 'PKR';
        final location = ref.read(routerProvider).state.uri.path;
        if (location != Routes.driverRequests && location != Routes.driverHome) {
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text('New ride request${fare != null ? ' · ${formatMoney(num.tryParse(fare.toString()), currency: currency)}' : ''}'),
            action: SnackBarAction(label: 'VIEW', textColor: AppColors.rose, onPressed: () => _openRoute(Routes.driverRequests)),
          ));
        }
      case RtEvents.rideAccepted:
      case RtEvents.offerAccepted:
        final tripId = e.data['trip_id']?.toString();
        if (tripId != null) session.setActiveTrip(tripId);
      case RtEvents.tripUpdated:
        final status = e.data['status']?.toString() ?? '';
        if (status == 'completed' || status.startsWith('cancelled')) {
          unawaited(session.refreshMe());
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeBinderProvider);
    ref.watch(pushBinderProvider);
    final router = ref.watch(routerProvider);
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next is SessionSignedIn && prev is! SessionSignedIn) {
        final pending = ref.read(pushServiceProvider).takePendingRoute();
        if (pending != null) Future.microtask(() => router.push(pending));
      }
    });
    return MaterialApp.router(
      title: 'FemaleRider',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      builder: (context, child) {
        // Respect user text scaling but cap it to keep dense map UIs usable.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
