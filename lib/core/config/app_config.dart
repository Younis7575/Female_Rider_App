import '../network/json.dart';

class Country {
  const Country({required this.code, required this.iso, required this.name, required this.flag});
  final String code;
  final String iso;
  final String name;
  final String flag;

  factory Country.fromJson(Json j) => Country(
        code: asString(j['code']),
        iso: asString(j['iso']),
        name: asString(j['name']),
        flag: asString(j['flag']),
      );

  static const pakistan = Country(code: '+92', iso: 'PK', name: 'Pakistan', flag: '🇵🇰');
}

class VehicleCategory {
  const VehicleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.capacity = 1,
    this.description,
  });

  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int capacity;
  final String? description;

  factory VehicleCategory.fromJson(Json j) => VehicleCategory(
        id: asInt(j['id']),
        name: asString(j['name']),
        slug: asString(j['slug']),
        icon: asStringOrNull(j['icon']),
        capacity: asInt(j['capacity'], 1),
        description: asStringOrNull(j['description']),
      );
}

class RealtimeConfig {
  const RealtimeConfig({required this.key, required this.host, required this.port, required this.scheme, required this.authEndpoint});
  final String key;
  final String host;
  final int port;
  final String scheme;
  final String authEndpoint;

  factory RealtimeConfig.fromJson(Json j) => RealtimeConfig(
        key: asString(j['key']),
        host: asString(j['host']),
        port: asInt(j['port'], 8080),
        scheme: asString(j['scheme'], 'ws'),
        authEndpoint: asString(j['auth_endpoint'], '/api/v1/broadcasting/auth'),
      );
}

class LocationIntervals {
  const LocationIntervals({this.online = 10, this.trip = 4, this.idle = 30, this.maxAccuracyM = 100});
  final int online;
  final int trip;
  final int idle;
  final double maxAccuracyM;

  factory LocationIntervals.fromJson(Json j) => LocationIntervals(
        online: asInt(j['online_interval_seconds'], 10),
        trip: asInt(j['trip_interval_seconds'], 4),
        idle: asInt(j['idle_interval_seconds'], 30),
        maxAccuracyM: asDouble(j['max_accuracy_m'], 100),
      );
}

class SupportInfo {
  const SupportInfo({this.hours = '', this.phone = '', this.email = ''});
  final String hours;
  final String phone;
  final String email;

  factory SupportInfo.fromJson(Json j) =>
      SupportInfo(hours: asString(j['hours']), phone: asString(j['phone']), email: asString(j['email']));
}

/// Parsed `GET /config` bootstrap payload.
class AppConfig {
  const AppConfig({
    this.appName = 'FemaleRider',
    this.minSupportedVersion = '1.0.0',
    this.latestVersion = '1.0.0',
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.currency = 'PKR',
    this.defaultCountryCode = '+92',
    this.countries = const [Country.pakistan],
    this.otpLength = 6,
    this.otpResendSeconds = 60,
    this.vehicleCategories = const [],
    this.customerCancelReasons = const [],
    this.driverCancelReasons = const [],
    this.customerRatingTags = const [],
    this.driverRatingTags = const [],
    this.location = const LocationIntervals(),
    this.pinLength = 4,
    this.customerFreeCancelSeconds = 120,
    this.requestTtlSeconds = 180,
    this.offerTtlSeconds = 45,
    this.support = const SupportInfo(),
    this.realtime,
    this.requiredDocuments = const [],
    this.optionalDocuments = const [],
    this.termsUrl,
    this.privacyUrl,
    this.eligibilityPolicyUrl,
  });

  final String appName;
  final String minSupportedVersion;
  final String latestVersion;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String currency;
  final String defaultCountryCode;
  final List<Country> countries;
  final int otpLength;
  final int otpResendSeconds;
  final List<VehicleCategory> vehicleCategories;
  final List<String> customerCancelReasons;
  final List<String> driverCancelReasons;

  /// Tags a *customer* can give (about the driver).
  final List<String> customerRatingTags;

  /// Tags a *driver* can give (about the customer).
  final List<String> driverRatingTags;
  final LocationIntervals location;
  final int pinLength;
  final int customerFreeCancelSeconds;
  final int requestTtlSeconds;
  final int offerTtlSeconds;
  final SupportInfo support;
  final RealtimeConfig? realtime;
  final List<String> requiredDocuments;
  final List<String> optionalDocuments;
  final String? termsUrl;
  final String? privacyUrl;
  final String? eligibilityPolicyUrl;

  Country get defaultCountry =>
      countries.firstWhere((c) => c.code == defaultCountryCode, orElse: () => countries.isNotEmpty ? countries.first : Country.pakistan);

  VehicleCategory? categoryById(int? id) {
    for (final c in vehicleCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  factory AppConfig.fromJson(Json j) {
    final app = asMap(j['app']);
    final otp = asMap(j['otp']);
    final cancel = asMap(j['cancel_reasons']);
    final tags = asMap(j['rating_tags']);
    final docs = asMap(j['documents']);
    final legal = asMap(j['legal']);
    final dispatch = asMap(j['dispatch']);
    final countries = asListOf(j['countries'], Country.fromJson);
    return AppConfig(
      appName: asString(app['name'], 'FemaleRider'),
      minSupportedVersion: asString(app['min_supported_version'], '1.0.0'),
      latestVersion: asString(app['latest_version'], '1.0.0'),
      maintenanceMode: asBool(app['maintenance_mode']),
      maintenanceMessage: asStringOrNull(app['maintenance_message']),
      currency: asString(j['currency'], 'PKR'),
      defaultCountryCode: asString(j['default_country_code'], '+92'),
      countries: countries.isEmpty ? const [Country.pakistan] : countries,
      otpLength: asInt(otp['length'], 6),
      otpResendSeconds: asInt(otp['resend_seconds'], 60),
      vehicleCategories: asListOf(j['vehicle_categories'], VehicleCategory.fromJson),
      customerCancelReasons: asStringList(cancel['customer']),
      driverCancelReasons: asStringList(cancel['driver']),
      customerRatingTags: asStringList(tags['customer']),
      driverRatingTags: asStringList(tags['driver']),
      location: LocationIntervals.fromJson(asMap(j['location'])),
      pinLength: asInt(asMap(j['trip'])['pin_length'], 4),
      customerFreeCancelSeconds: asInt(asMap(j['trip'])['customer_free_cancel_seconds'], 120),
      requestTtlSeconds: asInt(dispatch['request_ttl_seconds'], 180),
      offerTtlSeconds: asInt(dispatch['offer_ttl_seconds'], 45),
      support: SupportInfo.fromJson(asMap(j['support'])),
      realtime: j['realtime'] is Map ? RealtimeConfig.fromJson(asMap(j['realtime'])) : null,
      requiredDocuments: asStringList(docs['required']),
      optionalDocuments: asStringList(docs['optional']),
      termsUrl: asStringOrNull(legal['terms_url']),
      privacyUrl: asStringOrNull(legal['privacy_url']),
      eligibilityPolicyUrl: asStringOrNull(legal['eligibility_policy_url']),
    );
  }
}

/// Compares dotted versions; returns negative if a < b.
int compareVersions(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}
