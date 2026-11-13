import 'dart:async';

import 'package:femalerider/core/location/driver_tracker.dart';
import 'package:femalerider/core/location/location_service.dart';
import 'package:femalerider/core/network/api_envelope.dart';
import 'package:femalerider/features/account/data/account_repository.dart';
import 'package:femalerider/features/account/presentation/app_drawer.dart';
import 'package:femalerider/features/auth/domain/user.dart';
import 'package:femalerider/features/auth/presentation/session_controller.dart';
import 'package:femalerider/features/driver/data/driver_repository.dart';
import 'package:femalerider/features/driver/presentation/widgets/online_toggle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

void main() {
  group('Mode switch (drawer only)', () {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    Widget host() => Scaffold(key: scaffoldKey, drawer: const AppDrawer(), body: const Center(child: Text('HOME')));

    Future<void> openDrawer(WidgetTester tester) async {
      scaffoldKey.currentState!.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('home body has no switcher; drawer offers "Drive with FemaleRider" and switches an approved driver', (tester) async {
      final account = FakeAccountRepository();
      final session = TestSessionController(SessionSignedIn(MeResult(user: testUser(driverMode: true, driverStatus: 'approved'))));
      await pumpWithRouter(tester, child: host(), overrides: [
        accountRepositoryProvider.overrideWithValue(account),
        sessionProvider.overrideWith(() => session),
      ]);
      expect(find.byKey(const ValueKey('mode-switch-tile')), findsNothing);
      await openDrawer(tester);
      expect(find.text('Drive with FemaleRider'), findsOneWidget);
      expect(find.text('Go to your driver dashboard'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mode-switch-tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(account.modeCalls, ['driver']);
      expect(session.me!.user.isDriverMode, isTrue);
      expect(find.text('ROUTE:/driver'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('non-driver is sent to the driver application without calling /me/mode', (tester) async {
      final account = FakeAccountRepository();
      await pumpWithRouter(tester, child: host(), overrides: [
        accountRepositoryProvider.overrideWithValue(account),
        sessionProvider.overrideWith(() => TestSessionController(SessionSignedIn(MeResult(user: testUser())))),
      ]);
      await openDrawer(tester);
      expect(find.text('Earn on your schedule — apply to drive'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode-switch-tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(account.modeCalls, isEmpty);
      expect(find.text('ROUTE:/driver-apply'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('server refusal is shown in a snackbar (e.g. active trip)', (tester) async {
      final account = FakeAccountRepository()
        ..modeError = const ApiException(message: 'You cannot switch modes during an active trip.', code: 'active_trip_exists', statusCode: 409);
      await pumpWithRouter(tester, child: host(), overrides: [
        accountRepositoryProvider.overrideWithValue(account),
        sessionProvider.overrideWith(() => TestSessionController(SessionSignedIn(MeResult(user: testUser(driverMode: true, driverStatus: 'approved'))))),
      ]);
      await openDrawer(tester);
      await tester.tap(find.byKey(const ValueKey('mode-switch-tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(account.modeCalls, ['driver']);
      expect(find.text('You cannot switch modes during an active trip.'), findsOneWidget);
      expect(find.text('ROUTE:/driver'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('online driver is asked to go offline before switching to customer', (tester) async {
      final account = FakeAccountRepository();
      final driverRepo = FakeDriverRepository();
      final json = userJson(mode: 'driver', driverMode: true, driverStatus: 'approved');
      json['driver'] = {'status': 'approved', 'is_online': true, 'reason': null};
      final session = TestSessionController(SessionSignedIn(MeResult(user: AppUser.fromJson(json))));
      await pumpWithRouter(tester, child: host(), overrides: [
        accountRepositoryProvider.overrideWithValue(account),
        driverRepositoryProvider.overrideWithValue(driverRepo),
        sessionProvider.overrideWith(() => session),
      ]);
      await openDrawer(tester);
      expect(find.text('Switch to Customer mode'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode-switch-tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Go offline first?'), findsOneWidget);
      expect(account.modeCalls, isEmpty);

      await tester.tap(find.text('Go offline & switch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driverRepo.offlineCalls, 1);
      expect(account.modeCalls, ['customer']);
      expect(find.text('ROUTE:/home'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('DriverOnlineToggle', () {
    List<Override> overrides(FakeDriverRepository repo, {LocationAccess access = LocationAccess.granted}) => [
          driverRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(FakeLocationService(access: access)),
          sessionProvider.overrideWith(() => TestSessionController(SessionSignedIn(MeResult(user: testUser(mode: 'driver', driverMode: true, driverStatus: 'approved'))))),
        ];

    testWidgets('offline -> busy -> online -> offline', (tester) async {
      final repo = FakeDriverRepository()..onlineGate = Completer<int>();
      await pumpPlain(tester, const DriverOnlineToggle(), overrides: overrides(repo));
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Go online to receive ride requests'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('online-toggle')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // busy while POST /driver/online is pending

      repo.onlineGate!.complete(10);
      await tester.pump();
      await tester.pump();
      expect(find.text("You're online"), findsOneWidget);
      expect(find.text('Looking for ride requests near you'), findsOneWidget);
      expect(repo.onlineCalls, 1);

      // Location loop sends the first ping with sequence 1.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(repo.sequences, isNotEmpty);
      expect(repo.sequences.first, 1);

      await tester.tap(find.byKey(const ValueKey('online-toggle')));
      await tester.pump();
      await tester.pump();
      expect(repo.offlineCalls, 1);
      expect(find.text("You're offline"), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('compliance error from the server is shown and stays offline', (tester) async {
      final repo = FakeDriverRepository()
        ..onlineError = const ApiException(
          message: 'Document cnic front is not approved.',
          code: 'driver_not_compliant',
          statusCode: 403,
          details: {
            'issues': ['Document cnic front is not approved.', 'Vehicle is not approved.'],
          },
        );
      await pumpPlain(tester, const DriverOnlineToggle(), overrides: overrides(repo));
      await tester.tap(find.byKey(const ValueKey('online-toggle')));
      await tester.pumpAndSettle();
      expect(find.text("You can't go online yet"), findsOneWidget);
      expect(find.text('Vehicle is not approved.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('missing location permission blocks going online without calling the API', (tester) async {
      final repo = FakeDriverRepository();
      await pumpPlain(tester, const DriverOnlineToggle(), overrides: overrides(repo, access: LocationAccess.denied));
      await tester.tap(find.byKey(const ValueKey('online-toggle')));
      await tester.pumpAndSettle();
      expect(repo.onlineCalls, 0);
      expect(find.textContaining('Location permission is required'), findsOneWidget);
      await disposeTree(tester);
    });

    test('tracker state copyWith keeps fields', () {
      const s = DriverTrackerState(online: true, intervalS: 4, sequence: 3);
      final n = s.copyWith(sequence: 4);
      expect(n.online, isTrue);
      expect(n.intervalS, 4);
      expect(n.sequence, 4);
      expect(ProviderContainer, isNotNull);
    });
  });
}
