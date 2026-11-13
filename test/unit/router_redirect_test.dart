import 'package:femalerider/core/notifications/push_service.dart';
import 'package:femalerider/core/router/redirect.dart';
import 'package:femalerider/core/router/routes.dart';
import 'package:femalerider/features/auth/domain/user.dart';
import 'package:femalerider/features/auth/presentation/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

SessionSignedIn signedIn({
  String mode = 'customer',
  bool driverMode = false,
  String eligibility = 'approved',
  bool profileCompleted = true,
  String? activeTrip,
  String? activeRide,
}) =>
    SessionSignedIn(MeResult(
      user: AppUser.fromJson(userJson(mode: mode, driverMode: driverMode, eligibility: eligibility, profileCompleted: profileCompleted, driverStatus: driverMode ? 'approved' : 'not_submitted')),
      activeTripId: activeTrip,
      activeRideId: activeRide,
    ));

void main() {
  group('computeRedirect', () {
    test('unknown session always shows splash', () {
      expect(computeRedirect(const SessionUnknown(), Routes.home), Routes.splash);
      expect(computeRedirect(const SessionUnknown(), Routes.splash), isNull);
    });

    test('signed out: onboarding first, then login; auth + legal routes allowed', () {
      expect(computeRedirect(const SessionSignedOut(), Routes.splash), Routes.onboarding);
      expect(computeRedirect(const SessionSignedOut(onboardingSeen: true), Routes.home), Routes.login);
      expect(computeRedirect(const SessionSignedOut(onboardingSeen: true), Routes.otp), isNull);
      expect(computeRedirect(const SessionSignedOut(), Routes.legal('terms')), isNull);
      expect(computeRedirect(const SessionSignedOut(onboardingSeen: true), Routes.driverHome), Routes.login);
    });

    test('signed in leaves splash/login for the right home', () {
      expect(computeRedirect(signedIn(), Routes.splash), Routes.home);
      expect(computeRedirect(signedIn(), Routes.login), Routes.home);
      expect(computeRedirect(signedIn(mode: 'driver', driverMode: true), Routes.splash), Routes.driverHome);
      expect(computeRedirect(signedIn(activeTrip: 't1'), Routes.splash), Routes.trip('t1'));
      expect(computeRedirect(signedIn(activeRide: 'r1'), Routes.otp), Routes.matching('r1'));
      expect(computeRedirect(signedIn(mode: 'driver', driverMode: true, activeTrip: 't9'), Routes.splash), Routes.driverTrip('t9'));
    });

    test('incomplete profile is forced to profile setup', () {
      final s = signedIn(profileCompleted: false);
      expect(computeRedirect(s, Routes.home), Routes.profileSetup);
      expect(computeRedirect(s, Routes.profileSetup), isNull);
      expect(computeRedirect(s, Routes.splash), Routes.profileSetup);
    });

    test('eligibility gate keeps unapproved customers in account areas', () {
      final s = signedIn(eligibility: 'under_review');
      expect(computeRedirect(s, Routes.splash), Routes.accountStatus);
      expect(computeRedirect(s, Routes.home), Routes.accountStatus);
      expect(computeRedirect(s, Routes.matching('r1')), Routes.accountStatus);
      expect(computeRedirect(s, Routes.verification), isNull);
      expect(computeRedirect(s, Routes.settings), isNull);
      expect(computeRedirect(s, Routes.support), isNull);
      expect(computeRedirect(s, Routes.ticket('T-1')), isNull);
      expect(computeRedirect(s, Routes.driverApply), Routes.accountStatus);
    });

    test('mode guards', () {
      // Customer cannot open driver-only screens.
      expect(computeRedirect(signedIn(), Routes.driverHome), Routes.home);
      expect(computeRedirect(signedIn(), Routes.driverRequests), Routes.home);
      // ...but can open the driver application.
      expect(computeRedirect(signedIn(), Routes.driverApply), isNull);
      expect(computeRedirect(signedIn(), Routes.driverApplicationStatus), isNull);
      // Driver mode hides customer-only screens.
      final d = signedIn(mode: 'driver', driverMode: true);
      expect(computeRedirect(d, Routes.home), Routes.driverHome);
      expect(computeRedirect(d, Routes.trip('t1')), Routes.driverHome);
      expect(computeRedirect(d, Routes.driverTrip('t1')), isNull);
      expect(computeRedirect(d, Routes.history(as: 'driver').split('?').first), isNull);
      // Shared screens available in both.
      expect(computeRedirect(d, Routes.notifications), isNull);
      expect(computeRedirect(signedIn(), Routes.notifications), isNull);
    });

    test('driver mode without approval falls back to customer rules', () {
      // active_mode=driver but capability revoked (e.g. suspended).
      final s = signedIn(mode: 'driver', driverMode: false);
      expect(computeRedirect(s, Routes.driverHome), Routes.home);
      expect(homeFor(s.me), Routes.home);
    });
  });

  group('routeForNotification', () {
    test('maps backend screens to routes', () {
      expect(routeForNotification({'screen': 'trip', 'trip_id': 't1'}), Routes.trip('t1'));
      expect(routeForNotification({'screen': 'trip', 'trip_id': 't1'}, driverMode: true), Routes.driverTrip('t1'));
      expect(routeForNotification({'screen': 'driver_trip', 'trip_id': 't2'}), Routes.driverTrip('t2'));
      expect(routeForNotification({'screen': 'trip_receipt', 'trip_id': 't3'}), Routes.receipt('t3'));
      expect(routeForNotification({'screen': 'ride_offers', 'ride_id': 'r1'}), Routes.matching('r1'));
      expect(routeForNotification({'screen': 'driver_requests', 'ride_id': 'r1'}), Routes.driverRequests);
      expect(routeForNotification({'screen': 'verification'}), Routes.verification);
      expect(routeForNotification({'screen': 'home'}, driverMode: true), Routes.driverHome);
      expect(routeForNotification({'screen': 'unknown'}), Routes.notifications);
      expect(routeForNotification({}), Routes.notifications);
    });
  });
}
