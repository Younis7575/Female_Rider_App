import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/session_controller.dart';
import 'routes.dart';

/// Landing route for a signed-in user (resumes an active trip/ride).
String homeFor(MeResult me) {
  final u = me.user;
  if (!u.profileCompleted || (u.name ?? '').trim().isEmpty) return Routes.profileSetup;
  if (u.isDriverMode && u.canUseDriverMode) {
    return me.activeTripId != null ? Routes.driverTrip(me.activeTripId!) : Routes.driverHome;
  }
  if (!u.eligibility.isApproved || !u.canUseCustomerMode) return Routes.accountStatus;
  if (me.activeTripId != null) return Routes.trip(me.activeTripId!);
  if (me.activeRideId != null) return Routes.matching(me.activeRideId!);
  return Routes.home;
}

/// Pure redirect logic (unit-tested). Returns null to stay, or a new location.
String? computeRedirect(SessionState session, String path) {
  switch (session) {
    case SessionUnknown():
      return path == Routes.splash ? null : Routes.splash;

    case SessionSignedOut(:final onboardingSeen):
      if (path == Routes.login || path == Routes.otp || path == Routes.onboarding || path.startsWith('/legal/')) return null;
      return onboardingSeen ? Routes.login : Routes.onboarding;

    case SessionSignedIn(:final me):
      final u = me.user;
      // Leaving splash/auth once signed in.
      if (Routes.publicPaths.contains(path)) return homeFor(me);

      // Profile must be completed first.
      final needsProfile = !u.profileCompleted || (u.name ?? '').trim().isEmpty;
      if (needsProfile) {
        if (path == Routes.profileSetup || path.startsWith('/legal')) return null;
        return Routes.profileSetup;
      }

      final driverMode = u.isDriverMode && u.canUseDriverMode;

      // Driver-only screens require driver mode.
      if (Routes.isDriverOnly(path) && !driverMode) {
        return u.eligibility.isApproved ? Routes.home : Routes.accountStatus;
      }

      // Customer-only screens are hidden in driver mode.
      if (driverMode && Routes.isCustomerOnly(path)) return Routes.driverHome;

      // Customer mode before eligibility approval: only account/verification areas.
      if (!driverMode && (!u.eligibility.isApproved || !u.canUseCustomerMode)) {
        final allowed = Routes.preEligibilityPrefixes.any((p) => path == p || path.startsWith('$p/'));
        if (!allowed) return Routes.accountStatus;
      }

      // Driver onboarding requires approved eligibility (server rule: eligibility_required).
      if (path.startsWith(Routes.driverApply) && !u.eligibility.isApproved) return Routes.accountStatus;

      return null;
  }
}
