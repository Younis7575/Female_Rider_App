import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../account/domain/account_models.dart';
import '../domain/trip_models.dart';

/// Trips (shared by customer and driver), receipts, ratings and SOS.
class TripRepository {
  TripRepository(this._api);
  final ApiClient _api;

  Future<Paged<Trip>> trips({required String as, int page = 1, String? status}) async {
    final env = await _api.get('/trips', query: {'as': as, 'page': page, 'status': status});
    return Paged(items: asListOf(env.data, Trip.fromJson), pagination: env.pagination);
  }

  Future<Trip?> activeTrip() async {
    final env = await _api.get('/trips/active');
    return env.data is Map ? Trip.fromJson(env.dataMap) : null;
  }

  Future<Trip> trip(String id) async => Trip.fromJson((await _api.get('/trips/$id')).dataMap);

  // ---- Driver transitions --------------------------------------------
  Future<Trip> markEnRoute(String id) async => Trip.fromJson((await _api.post('/trips/$id/en-route')).dataMap);
  Future<Trip> markArrived(String id) async => Trip.fromJson((await _api.post('/trips/$id/arrive')).dataMap);
  Future<Trip> start(String id, String pin) async => Trip.fromJson((await _api.post('/trips/$id/start', data: {'pin': pin})).dataMap);
  Future<Trip> complete(String id) async => Trip.fromJson((await _api.post('/trips/$id/complete', idempotent: true)).dataMap);
  Future<Payment> cashCollected(String id) async =>
      Payment.fromJson((await _api.post('/trips/$id/cash-collected', idempotent: true)).dataMap);

  // ---- Shared ----------------------------------------------------------
  Future<Trip> cancel(String id, String reason) async =>
      Trip.fromJson((await _api.post('/trips/$id/cancel', data: {'reason': reason})).dataMap);

  /// Returns `(url, expiresAt)`.
  Future<(String, DateTime?)> share(String id) async {
    final d = (await _api.post('/trips/$id/share')).dataMap;
    return (asString(d['url']), asDate(d['expires_at']));
  }

  Future<void> revokeShare(String id) => _api.delete('/trips/$id/share');

  Future<Receipt> receipt(String id) async => Receipt.fromJson((await _api.get('/trips/$id/receipt')).dataMap);

  Future<String?> rate(String id, {required int score, List<String> tags = const [], String? comment}) async {
    final env = await _api.post('/trips/$id/rating', data: {
      'score': score,
      'tags': tags,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    return env.message;
  }

  Future<SosResult> sos({String? tripId, double? lat, double? lng, String? note}) async {
    final env = await _api.post('/sos', data: {'trip_id': ?tripId, 'lat': ?lat, 'lng': ?lng, 'note': ?note});
    final d = env.dataMap;
    return SosResult(
      emergencyNumber: asString(d['emergency_number'], '15'),
      supportHours: asStringOrNull(d['support_hours']),
      reference: asStringOrNull(asMap(d['incident'])['reference']),
      message: env.message,
    );
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) => TripRepository(ref.watch(apiClientProvider)));
