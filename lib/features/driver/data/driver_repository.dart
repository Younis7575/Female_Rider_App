import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../rides/domain/ride_models.dart';
import '../../trips/domain/trip_models.dart';
import '../domain/driver_models.dart';

class LocationPingResult {
  const LocationPingResult({required this.accepted, this.nextIntervalS, this.activeTripId, this.reason});
  final bool accepted;
  final int? nextIntervalS;
  final String? activeTripId;
  final String? reason;
}

/// Result of responding to a customer's counter: either a trip (accepted) or a new offer.
class CounterResponse {
  const CounterResponse({this.trip, this.offer, this.message});
  final Trip? trip;
  final RideOffer? offer;
  final String? message;
}

/// Driver onboarding, availability, requests/negotiation and finance.
class DriverRepository {
  DriverRepository(this._api);
  final ApiClient _api;

  // ---- Onboarding --------------------------------------------------------
  Future<DriverProfile> profile() async => DriverProfile.fromJson((await _api.get('/driver/profile')).dataMap);

  Future<DriverProfile> updateProfile({
    required String fullName,
    String? cnicNumber,
    required String dateOfBirth,
    String? licenseNumber,
    required String licenseExpiry,
    required String address,
    required String emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    // CNIC, licence number and emergency phone may be omitted once stored (server keeps them).
    String? opt(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final env = await _api.put('/driver/profile', data: {
      'full_name': fullName,
      'cnic_number': ?opt(cnicNumber),
      'date_of_birth': dateOfBirth,
      'license_number': ?opt(licenseNumber),
      'license_expiry': licenseExpiry,
      'address': address,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': ?opt(emergencyContactPhone),
    });
    return DriverProfile.fromJson(env.dataMap);
  }

  Future<Vehicle> updateVehicle({
    required int categoryId,
    required String make,
    required String model,
    required String color,
    required int year,
    required String plateNumber,
    String? registrationExpiry,
    String? insuranceExpiry,
  }) async {
    final env = await _api.put('/driver/vehicle', data: {
      'vehicle_category_id': categoryId,
      'make': make,
      'model': model,
      'color': color,
      'year': year,
      'plate_number': plateNumber,
      if (registrationExpiry != null && registrationExpiry.isNotEmpty) 'registration_expiry': registrationExpiry,
      if (insuranceExpiry != null && insuranceExpiry.isNotEmpty) 'insurance_expiry': insuranceExpiry,
    });
    return Vehicle.fromJson(env.dataMap);
  }

  Future<List<DriverDocument>> documents() async => asListOf((await _api.get('/driver/documents')).data, DriverDocument.fromJson);

  Future<DriverDocument> uploadDocument({required String type, required String path, String? expiryDate, void Function(int, int)? onProgress}) async {
    final env = await _api.multipart('/driver/documents',
        fields: {'type': type, 'expiry_date': expiryDate}, files: {'file': UploadFile(path: path)}, onProgress: onProgress);
    return DriverDocument.fromJson(env.dataMap);
  }

  Future<DriverProfile> updatePayoutAccount({required String method, required String title, required String number}) async {
    final env = await _api.put('/driver/payout-account', data: {
      'payout_method': method,
      'payout_account_title': title,
      'payout_account_number': number,
    });
    return DriverProfile.fromJson(env.dataMap);
  }

  Future<(DriverProfile, String?)> submit() async {
    final env = await _api.post('/driver/submit', data: {'accept_agreement': 1});
    return (DriverProfile.fromJson(env.dataMap), env.message);
  }

  // ---- Availability ------------------------------------------------------
  /// Returns the suggested location interval in seconds.
  Future<int> goOnline(double lat, double lng) async {
    final env = await _api.post('/driver/online', data: {'lat': lat, 'lng': lng});
    return asInt(env.dataMap['location_interval_s'], 10);
  }

  Future<void> goOffline() => _api.post('/driver/offline');

  Future<LocationPingResult> sendLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    required int sequence,
    required DateTime recordedAt,
  }) async {
    final env = await _api.post('/driver/location', data: {
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading.clamp(0, 360),
      if (speed != null) 'speed': speed.clamp(0, 100),
      if (accuracy != null) 'accuracy': accuracy.clamp(0, 5000),
      'sequence': sequence,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    });
    final d = env.dataMap;
    return LocationPingResult(
      accepted: asBool(d['accepted']),
      nextIntervalS: asIntOrNull(d['next_interval_s']),
      activeTripId: asStringOrNull(d['active_trip_id']),
      reason: asStringOrNull(d['reason']),
    );
  }

  // ---- Requests & negotiation -----------------------------------------
  Future<List<DriverRequest>> requests() async => asListOf((await _api.get('/driver/requests')).data, DriverRequest.fromJson);

  /// Offer at the customer's proposed fare (amount == null) or a counter amount.
  Future<RideOffer> makeOffer(String rideId, {double? amount}) async =>
      RideOffer.fromJson((await _api.post('/driver/requests/$rideId/offer', data: {'amount': ?amount})).dataMap);

  Future<void> decline(String rideId) => _api.post('/driver/requests/$rideId/decline');

  Future<RideOffer> withdraw(int offerId) async => RideOffer.fromJson((await _api.post('/offers/$offerId/withdraw')).dataMap);

  /// action: accept | reject | counter
  Future<CounterResponse> respondToCounter(int offerId, {required String action, double? amount}) async {
    final env = await _api.post('/offers/$offerId/respond', data: {'action': action, 'amount': ?amount}, idempotent: true);
    final d = env.dataMap;
    return CounterResponse(
      trip: d['trip'] is Map ? Trip.fromJson(asMap(d['trip'])) : null,
      offer: d['offer'] is Map ? RideOffer.fromJson(asMap(d['offer'])) : null,
      message: env.message,
    );
  }

  // ---- Finance -----------------------------------------------------------
  Future<DriverDashboard> dashboard() async => DriverDashboard.fromJson((await _api.get('/driver/dashboard')).dataMap);

  /// Monthly statement; [month] as `YYYY-MM` (defaults to the current month server-side).
  Future<DriverStatement> statement({String? month}) async =>
      DriverStatement.fromJson((await _api.get('/driver/statements', query: {'month': month})).dataMap);

  Future<EarningsReport> earnings(String period) async =>
      EarningsReport.fromJson((await _api.get('/driver/earnings', query: {'period': period})).dataMap);

  Future<(Paged<LedgerEntry>, double balance)> ledger({int page = 1}) async {
    final env = await _api.get('/driver/ledger', query: {'page': page});
    return (Paged(items: asListOf(env.data, LedgerEntry.fromJson), pagination: env.pagination), asDouble(env.meta?['balance']));
  }

  Future<(Paged<Payout>, double available, double minPayout)> payouts({int page = 1}) async {
    final env = await _api.get('/driver/payouts', query: {'page': page});
    return (
      Paged(items: asListOf(env.data, Payout.fromJson), pagination: env.pagination),
      asDouble(env.meta?['available_for_payout']),
      asDouble(env.meta?['min_payout'], 500),
    );
  }

  Future<(Payout, String?)> requestPayout(double amount) async {
    final env = await _api.post('/driver/payouts', data: {'amount': amount}, idempotent: true);
    return (Payout.fromJson(env.dataMap), env.message);
  }
}

final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository(ref.watch(apiClientProvider)));
