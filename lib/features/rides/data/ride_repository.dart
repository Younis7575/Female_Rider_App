import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../trips/domain/trip_models.dart';
import '../domain/ride_models.dart';

/// Customer-side places, estimates, ride requests and negotiation.
class RideRepository {
  RideRepository(this._api);
  final ApiClient _api;

  // ---- Places ------------------------------------------------------------
  Future<List<Place>> searchPlaces(String q, {double? lat, double? lng}) async =>
      asListOf((await _api.get('/places/search', query: {'q': q, 'lat': lat, 'lng': lng})).data, Place.fromJson);

  Future<String?> reverseGeocode(double lat, double lng) async =>
      asStringOrNull((await _api.get('/places/reverse', query: {'lat': lat, 'lng': lng})).dataMap['address']);

  Future<List<Place>> recentPlaces() async => asListOf((await _api.get('/places/recent')).data, Place.fromJson);

  Future<List<SavedPlace>> savedPlaces() async => asListOf((await _api.get('/saved-places')).data, SavedPlace.fromJson);

  Future<SavedPlace> savePlace({required String label, required Place place, String? name}) async {
    final env = await _api.post('/saved-places', data: {
      'label': label,
      'name': name ?? place.name,
      'address': place.address.isNotEmpty ? place.address : place.name,
      'lat': place.lat,
      'lng': place.lng,
    });
    return SavedPlace.fromJson(env.dataMap);
  }

  Future<void> deleteSavedPlace(int id) => _api.delete('/saved-places/$id');

  /// `{serviceable, zone?, city?, message?}`
  Future<(bool, String?)> checkServiceArea(double lat, double lng) async {
    final d = (await _api.post('/service-area/check', data: {'lat': lat, 'lng': lng})).dataMap;
    return (asBool(d['serviceable']), asStringOrNull(d['message']) ?? asStringOrNull(d['zone']));
  }

  // ---- Pricing -----------------------------------------------------------
  Future<FareEstimate> estimate(Place pickup, Place dropoff) async {
    final env = await _api.post('/fare/estimate', data: {
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'dropoff_lat': dropoff.lat,
      'dropoff_lng': dropoff.lng,
    });
    return FareEstimate.fromJson(env.dataMap);
  }

  Future<List<Coupon>> coupons() async => asListOf((await _api.get('/coupons')).data, Coupon.fromJson);

  Future<CouponValidation> validateCoupon({required String code, required double fare, int? categoryId}) async {
    final env = await _api.post('/coupons/validate', data: {'code': code, 'fare': fare, 'vehicle_category_id': ?categoryId});
    return CouponValidation.fromJson(env.dataMap);
  }

  // ---- Ride requests ---------------------------------------------------
  Future<RideRequest> createRide(CreateRideInput input, {required String idempotencyKey}) async =>
      RideRequest.fromJson((await _api.post('/rides', data: input.toJson(), idempotencyKey: idempotencyKey)).dataMap);

  Future<RideRequest?> activeRide() async {
    final env = await _api.get('/rides/active');
    return env.data is Map ? RideRequest.fromJson(env.dataMap) : null;
  }

  Future<RideRequest> ride(String id) async => RideRequest.fromJson((await _api.get('/rides/$id')).dataMap);

  Future<Paged<RideRequest>> rides({int page = 1}) async {
    final env = await _api.get('/rides', query: {'page': page});
    return Paged(items: asListOf(env.data, RideRequest.fromJson), pagination: env.pagination);
  }

  Future<List<RideOffer>> offers(String rideId) async =>
      asListOf((await _api.get('/rides/$rideId/offers')).data, RideOffer.fromJson);

  Future<RideRequest> cancelRide(String rideId, {String? reason}) async =>
      RideRequest.fromJson((await _api.post('/rides/$rideId/cancel', data: {'reason': ?reason})).dataMap);

  Future<RideRequest> updateFare(String rideId, double fare) async =>
      RideRequest.fromJson((await _api.post('/rides/$rideId/fare', data: {'proposed_fare': fare})).dataMap);

  /// Accepting assigns the driver and returns the new trip.
  Future<Trip> acceptOffer(int offerId) async =>
      Trip.fromJson((await _api.post('/offers/$offerId/accept', idempotent: true)).dataMap);

  Future<RideOffer> rejectOffer(int offerId) async =>
      RideOffer.fromJson((await _api.post('/offers/$offerId/reject')).dataMap);

  Future<RideOffer> counterOffer(int offerId, double amount) async =>
      RideOffer.fromJson((await _api.post('/offers/$offerId/counter', data: {'amount': amount})).dataMap);
}

final rideRepositoryProvider = Provider<RideRepository>((ref) => RideRepository(ref.watch(apiClientProvider)));
