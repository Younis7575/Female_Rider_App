/// Route paths. Keep every path in one place so deep links / push taps stay consistent.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/login/otp';
  static const profileSetup = '/profile-setup';
  static const accountStatus = '/account-status';
  static const verification = '/verification';

  // Customer
  static const home = '/home';
  static String matching(String rideId) => '/ride/$rideId';
  static String trip(String tripId) => '/trip/$tripId';
  static String receipt(String tripId) => '/trip/$tripId/receipt';
  static String rateTrip(String tripId) => '/trip/$tripId/rate';
  static const savedPlaces = '/saved-places';
  static const coupons = '/coupons';
  static const payments = '/payments';
  static String refund(String tripId) => '/refund/$tripId';

  // Shared
  static String history({String as = 'customer'}) => '/trips?as=$as';
  static const historyBase = '/trips';
  static String tripDetail(String tripId) => '/trips/$tripId';
  static String tripChat(String tripId) => '/chat/$tripId';
  static const notifications = '/notifications';
  static const support = '/support';
  static const newTicket = '/support/new';
  static String ticket(String reference) => '/support/ticket/$reference';
  static const faqs = '/faqs';
  static String safetyReport({String? tripId}) => tripId == null ? '/safety/report' : '/safety/report?tripId=$tripId';
  static const safetyReportBase = '/safety/report';
  static String legal(String slug) => '/legal/$slug';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const sessions = '/sessions';
  static const deleteAccount = '/account/delete';

  // Driver (approved, driver mode)
  static const driverHome = '/driver';
  static const driverRequests = '/driver/requests';
  static String driverTrip(String tripId) => '/driver/trip/$tripId';
  static String driverRate(String tripId) => '/driver/trip/$tripId/rate';
  static const driverEarnings = '/driver/earnings';
  static const driverLedger = '/driver/ledger';
  static const driverPayouts = '/driver/payouts';
  static const driverStatements = '/driver/statements';

  // Driver onboarding (any mode)
  static const driverDocuments = '/driver-documents';
  static const driverApply = '/driver-apply';
  static const driverApplyPersonal = '/driver-apply/personal';
  static const driverApplyVehicle = '/driver-apply/vehicle';
  static const driverApplyDocuments = '/driver-apply/documents';
  static const driverApplyPayout = '/driver-apply/payout';
  static const driverApplyReview = '/driver-apply/review';
  static const driverApplicationStatus = '/driver-apply/status';

  /// Reachable without signing in.
  static const publicPaths = {splash, onboarding, login, otp};

  /// Reachable while signed in even before eligibility approval.
  static const preEligibilityPrefixes = [
    accountStatus,
    verification,
    profileSetup,
    profile,
    settings,
    sessions,
    deleteAccount,
    support,
    faqs,
    '/legal',
    notifications,
  ];

  /// Only meaningful in driver mode.
  static bool isDriverOnly(String path) => path == driverHome || path.startsWith('$driverHome/');

  /// Only meaningful in customer mode.
  static bool isCustomerOnly(String path) =>
      path == home || path.startsWith('/ride/') || path.startsWith('/trip/') || path == savedPlaces;
}
