import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/chat/presentation/trip_chat_screen.dart';
import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/profile_setup_screen.dart';
import '../../features/account/presentation/sessions_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/auth/domain/otp_args.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/customer/presentation/coupons_screen.dart';
import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/customer/presentation/saved_places_screen.dart';
import '../../features/driver/presentation/driver_home_screen.dart';
import '../../features/driver/presentation/driver_requests_screen.dart';
import '../../features/driver/presentation/driver_trip_screen.dart';
import '../../features/driver_finance/presentation/earnings_screen.dart';
import '../../features/driver_finance/presentation/ledger_screen.dart';
import '../../features/driver_finance/presentation/payouts_screen.dart';
import '../../features/driver_finance/presentation/statements_screen.dart';
import '../../features/driver_onboarding/presentation/application_status_screen.dart';
import '../../features/driver_onboarding/presentation/apply_documents_screen.dart';
import '../../features/driver_onboarding/presentation/apply_payout_screen.dart';
import '../../features/driver_onboarding/presentation/apply_personal_screen.dart';
import '../../features/driver_onboarding/presentation/apply_review_screen.dart';
import '../../features/driver_onboarding/presentation/apply_vehicle_screen.dart';
import '../../features/driver_onboarding/presentation/driver_apply_screen.dart';
import '../../features/driver_onboarding/presentation/driver_documents_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/payments/presentation/refund_screen.dart';
import '../../features/rides/presentation/matching_screen.dart';
import '../../features/safety/presentation/safety_report_screen.dart';
import '../../features/support/presentation/faq_screen.dart';
import '../../features/support/presentation/legal_screen.dart';
import '../../features/support/presentation/new_ticket_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/support/presentation/ticket_screen.dart';
import '../../features/trips/presentation/customer_trip_screen.dart';
import '../../features/trips/presentation/rate_trip_screen.dart';
import '../../features/trips/presentation/receipt_screen.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_history_screen.dart';
import '../../features/verification/presentation/account_status_screen.dart';
import '../../features/verification/presentation/verification_screen.dart';
import 'redirect.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges Riverpod session changes to go_router's refresh mechanism.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      // Only structural changes affect redirects; avoid churn on unread-count updates.
      if (_key(prev) != _key(next)) notifyListeners();
    });
  }

  static String _key(SessionState? s) => switch (s) {
        SessionSignedIn(:final me) =>
          'in:${me.user.activeMode}:${me.user.canUseDriverMode}:${me.user.canUseCustomerMode}:${me.user.eligibility.status}:${me.user.profileCompleted}:${me.user.name?.isNotEmpty}',
        SessionSignedOut(:final onboardingSeen) => 'out:$onboardingSeen',
        _ => 'unknown',
      };
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);

  String? param(GoRouterState s, String name) => s.pathParameters[name];

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => computeRedirect(ref.read(sessionProvider), state.uri.path),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('This page does not exist: ${state.uri.path}')),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const PhoneScreen()),
      GoRoute(
        path: Routes.otp,
        redirect: (_, s) => s.extra is OtpArgs ? null : Routes.login,
        builder: (_, s) => OtpScreen(args: s.extra! as OtpArgs),
      ),
      GoRoute(path: Routes.profileSetup, builder: (_, _) => const ProfileSetupScreen()),
      GoRoute(path: Routes.accountStatus, builder: (_, _) => const AccountStatusScreen()),
      GoRoute(path: Routes.verification, builder: (_, _) => const VerificationScreen()),

      // Customer
      GoRoute(path: Routes.home, builder: (_, _) => const CustomerHomeScreen()),
      GoRoute(path: '/ride/:rideId', builder: (_, s) => MatchingScreen(rideId: param(s, 'rideId')!)),
      GoRoute(
        path: '/trip/:tripId',
        builder: (_, s) => CustomerTripScreen(tripId: param(s, 'tripId')!),
        routes: [
          GoRoute(path: 'receipt', builder: (_, s) => ReceiptScreen(tripId: param(s, 'tripId')!)),
          GoRoute(path: 'rate', builder: (_, s) => RateTripScreen(tripId: param(s, 'tripId')!)),
        ],
      ),
      GoRoute(path: Routes.savedPlaces, builder: (_, _) => const SavedPlacesScreen()),
      GoRoute(path: Routes.coupons, builder: (_, _) => const CouponsScreen()),
      GoRoute(path: Routes.payments, builder: (_, _) => const PaymentsScreen()),
      GoRoute(path: '/refund/:tripId', builder: (_, s) => RefundScreen(tripId: param(s, 'tripId')!)),

      // Shared
      GoRoute(
        path: Routes.historyBase,
        builder: (_, s) => TripHistoryScreen(as: s.uri.queryParameters['as'] ?? 'customer'),
        routes: [
          GoRoute(path: ':tripId', builder: (_, s) => TripDetailScreen(tripId: param(s, 'tripId')!)),
        ],
      ),
      GoRoute(path: '/chat/:tripId', builder: (_, s) => TripChatScreen(tripId: param(s, 'tripId')!)),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: Routes.support,
        builder: (_, _) => const SupportScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, s) => NewTicketScreen(tripId: s.uri.queryParameters['tripId'])),
          GoRoute(path: 'ticket/:ref', builder: (_, s) => TicketScreen(reference: param(s, 'ref')!)),
        ],
      ),
      GoRoute(path: Routes.faqs, builder: (_, _) => const FaqScreen()),
      GoRoute(path: Routes.safetyReportBase, builder: (_, s) => SafetyReportScreen(tripId: s.uri.queryParameters['tripId'])),
      GoRoute(path: '/legal/:slug', builder: (_, s) => LegalScreen(slug: param(s, 'slug')!)),
      GoRoute(
        path: Routes.profile,
        builder: (_, _) => const ProfileScreen(),
        routes: [GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen())],
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.sessions, builder: (_, _) => const SessionsScreen()),
      GoRoute(path: Routes.deleteAccount, builder: (_, _) => const DeleteAccountScreen()),

      // Driver mode
      GoRoute(
        path: Routes.driverHome,
        builder: (_, _) => const DriverHomeScreen(),
        routes: [
          GoRoute(path: 'requests', builder: (_, _) => const DriverRequestsScreen()),
          GoRoute(
            path: 'trip/:tripId',
            builder: (_, s) => DriverTripScreen(tripId: param(s, 'tripId')!),
            routes: [GoRoute(path: 'rate', builder: (_, s) => RateTripScreen(tripId: param(s, 'tripId')!))],
          ),
          GoRoute(path: 'earnings', builder: (_, _) => const EarningsScreen()),
          GoRoute(path: 'ledger', builder: (_, _) => const LedgerScreen()),
          GoRoute(path: 'payouts', builder: (_, _) => const PayoutsScreen()),
          GoRoute(path: 'statements', builder: (_, _) => const StatementsScreen()),
        ],
      ),

      // Driver onboarding (available from customer mode)
      GoRoute(path: Routes.driverDocuments, builder: (_, _) => const DriverDocumentsScreen()),
      GoRoute(
        path: Routes.driverApply,
        builder: (_, _) => const DriverApplyScreen(),
        routes: [
          GoRoute(path: 'personal', builder: (_, _) => const ApplyPersonalScreen()),
          GoRoute(path: 'vehicle', builder: (_, _) => const ApplyVehicleScreen()),
          GoRoute(path: 'documents', builder: (_, _) => const ApplyDocumentsScreen()),
          GoRoute(path: 'payout', builder: (_, _) => const ApplyPayoutScreen()),
          GoRoute(path: 'review', builder: (_, _) => const ApplyReviewScreen()),
          GoRoute(path: 'status', builder: (_, _) => const DriverApplicationStatusScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
