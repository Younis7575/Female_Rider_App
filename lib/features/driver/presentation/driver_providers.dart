import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/driver_repository.dart';
import '../domain/driver_models.dart';

/// `GET /driver/dashboard`.
final driverDashboardProvider = FutureProvider.autoDispose<DriverDashboard>((ref) {
  return ref.watch(driverRepositoryProvider).dashboard();
});

/// Selected bottom-bar tab in driver mode: 0 = Requests, 1 = Home, 2 = Wallet.
class DriverTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int i) => state = i;
}

final driverTabProvider = NotifierProvider<DriverTabController, int>(DriverTabController.new);
