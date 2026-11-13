import '../../../core/network/json.dart';

class EligibilityInfo {
  const EligibilityInfo({required this.status, required this.label, this.reason, this.canSubmit = false, this.canAppeal = false});
  final String status;
  final String label;
  final String? reason;
  final bool canSubmit;
  final bool canAppeal;

  bool get isApproved => status == 'approved';
  bool get isPendingReview => const ['submitted', 'under_review', 'appealed'].contains(status);

  factory EligibilityInfo.fromJson(Json j) => EligibilityInfo(
        status: asString(j['status'], 'draft'),
        label: asString(j['label'], 'Draft'),
        reason: asStringOrNull(j['reason']),
        canSubmit: asBool(j['can_submit']),
        canAppeal: asBool(j['can_appeal']),
      );
}

class DriverSummary {
  const DriverSummary({required this.status, this.isOnline = false, this.reason});
  final String status;
  final bool isOnline;
  final String? reason;

  bool get isApproved => status == 'approved';
  bool get hasApplied => status != 'not_submitted';

  factory DriverSummary.fromJson(Json j) => DriverSummary(
        status: asString(j['status'], 'not_submitted'),
        isOnline: asBool(j['is_online']),
        reason: asStringOrNull(j['reason']),
      );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    this.countryCode,
    this.name,
    this.email,
    this.photoUrl,
    this.locale = 'en',
    this.accountStatus = 'active',
    this.activeMode = 'customer',
    this.rating = 0,
    this.ratingCount = 0,
    this.profileCompleted = false,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.notificationPreferences = const {},
    this.privacyPreferences = const {},
    required this.eligibility,
    this.canUseCustomerMode = false,
    this.canUseDriverMode = false,
    required this.driver,
    this.userChannel,
    this.driverChannel,
    this.deletionRequestedAt,
  });

  final String id;
  final String phone;
  final String? countryCode;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String locale;
  final String accountStatus;
  final String activeMode;
  final double rating;
  final int ratingCount;
  final bool profileCompleted;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final Map<String, bool> notificationPreferences;
  final Map<String, bool> privacyPreferences;
  final EligibilityInfo eligibility;
  final bool canUseCustomerMode;
  final bool canUseDriverMode;
  final DriverSummary driver;

  /// Exact private channel names from `realtime_channels` (numeric DB id inside).
  final String? userChannel;
  final String? driverChannel;
  final DateTime? deletionRequestedAt;

  bool get isDriverMode => activeMode == 'driver';
  String get firstName => (name ?? '').trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromJson(Json j) {
    final ec = asMap(j['emergency_contact']);
    final caps = asMap(j['capabilities']);
    final rc = asMap(j['realtime_channels']);
    Map<String, bool> prefs(Object? v) => asMap(v).map((k, val) => MapEntry(k, asBool(val)));
    return AppUser(
      id: asString(j['id']),
      phone: asString(j['phone']),
      countryCode: asStringOrNull(j['country_code']),
      name: asStringOrNull(j['name']),
      email: asStringOrNull(j['email']),
      photoUrl: asStringOrNull(j['photo_url']),
      locale: asString(j['locale'], 'en'),
      accountStatus: asString(j['account_status'], 'active'),
      activeMode: asString(j['active_mode'], 'customer'),
      rating: asDouble(j['rating']),
      ratingCount: asInt(j['rating_count']),
      profileCompleted: asBool(j['profile_completed']),
      emergencyContactName: asStringOrNull(ec['name']),
      emergencyContactPhone: asStringOrNull(ec['phone']),
      notificationPreferences: prefs(j['notification_preferences']),
      privacyPreferences: prefs(j['privacy_preferences']),
      eligibility: EligibilityInfo.fromJson(asMap(j['eligibility'])),
      canUseCustomerMode: asBool(caps['customer_mode']),
      canUseDriverMode: asBool(caps['driver_mode']),
      driver: DriverSummary.fromJson(asMap(j['driver'])),
      userChannel: asStringOrNull(rc['user']),
      driverChannel: asStringOrNull(rc['driver']),
      deletionRequestedAt: asDate(j['deletion_requested_at']),
    );
  }
}

/// `GET /me` payload.
class MeResult {
  const MeResult({required this.user, this.activeTripId, this.activeRideId, this.unreadNotifications = 0});
  final AppUser user;
  final String? activeTripId;
  final String? activeRideId;
  final int unreadNotifications;

  factory MeResult.fromJson(Json j) => MeResult(
        user: AppUser.fromJson(asMap(j['user'])),
        activeTripId: asStringOrNull(j['active_trip_id']),
        activeRideId: asStringOrNull(j['active_ride_id']),
        unreadNotifications: asInt(j['unread_notifications']),
      );

  MeResult copyWith({AppUser? user, String? activeTripId, String? activeRideId, int? unreadNotifications, bool clearTrip = false, bool clearRide = false}) => MeResult(
        user: user ?? this.user,
        activeTripId: clearTrip ? null : (activeTripId ?? this.activeTripId),
        activeRideId: clearRide ? null : (activeRideId ?? this.activeRideId),
        unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      );
}

/// `POST /auth/otp/request` result.
class OtpRequestResult {
  const OtpRequestResult({required this.phone, required this.expiresIn, required this.resendIn, this.debugCode});
  final String phone;
  final int expiresIn;
  final int resendIn;
  final String? debugCode;

  factory OtpRequestResult.fromJson(Json j) => OtpRequestResult(
        phone: asString(j['phone']),
        expiresIn: asInt(j['expires_in'], 300),
        resendIn: asInt(j['resend_in'], 60),
        debugCode: asStringOrNull(j['debug_code']),
      );
}

class AuthResult {
  const AuthResult({required this.token, required this.isNewUser, required this.user});
  final String token;
  final bool isNewUser;
  final AppUser user;

  factory AuthResult.fromJson(Json j) => AuthResult(
        token: asString(j['token']),
        isNewUser: asBool(j['is_new_user']),
        user: AppUser.fromJson(asMap(j['user'])),
      );
}
