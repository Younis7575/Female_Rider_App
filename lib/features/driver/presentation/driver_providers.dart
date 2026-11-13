import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/driver_repository.dart';
import '../domain/driver_models.dart';

/// `GET /driver/dashboard`.
final driverDashboardProvider = FutureProvider.autoDispose<DriverDashboard>((ref) {
  return ref.watch(driverRepositoryProvider).dashboard();
});
