import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rides/data/ride_repository.dart';
import '../../rides/domain/ride_models.dart';

final savedPlacesProvider = FutureProvider.autoDispose<List<SavedPlace>>((ref) {
  return ref.watch(rideRepositoryProvider).savedPlaces();
});

final recentPlacesProvider = FutureProvider.autoDispose<List<Place>>((ref) {
  return ref.watch(rideRepositoryProvider).recentPlaces();
});

final couponsProvider = FutureProvider.autoDispose<List<Coupon>>((ref) {
  return ref.watch(rideRepositoryProvider).coupons();
});
