import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';

/// `GET /driver/earnings?period=` (today | week | month).
final earningsProvider = FutureProvider.autoDispose.family<EarningsReport, String>((ref, period) {
  return ref.watch(driverRepositoryProvider).earnings(period);
});

class LedgerPageState {
  const LedgerPageState({this.items = const [], this.balance = 0, this.page = 0, this.hasMore = true, this.loadingMore = false});
  final List<LedgerEntry> items;
  final double balance;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  LedgerPageState copyWith({List<LedgerEntry>? items, double? balance, int? page, bool? hasMore, bool? loadingMore}) => LedgerPageState(
        items: items ?? this.items,
        balance: balance ?? this.balance,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Paged driver ledger (`GET /driver/ledger`).
class LedgerController extends AsyncNotifier<LedgerPageState> {
  @override
  Future<LedgerPageState> build() async {
    final (page, balance) = await ref.read(driverRepositoryProvider).ledger(page: 1);
    return LedgerPageState(items: page.items, balance: balance, page: 1, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final (page, balance) = await ref.read(driverRepositoryProvider).ledger(page: s.page + 1);
      state = AsyncData(s.copyWith(items: [...s.items, ...page.items], balance: balance, page: s.page + 1, hasMore: page.hasMore, loadingMore: false));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }
}

final ledgerProvider = AsyncNotifierProvider.autoDispose<LedgerController, LedgerPageState>(LedgerController.new);

class PayoutsState {
  const PayoutsState({this.items = const [], this.available = 0, this.minPayout = 500, this.page = 1, this.hasMore = false, this.loadingMore = false});
  final List<Payout> items;
  final double available;
  final double minPayout;
  final int page;
  final bool hasMore;
  final bool loadingMore;
}

/// `GET /driver/payouts` (+ meta available_for_payout / min_payout).
class PayoutsController extends AsyncNotifier<PayoutsState> {
  @override
  Future<PayoutsState> build() async {
    final (page, available, min) = await ref.read(driverRepositoryProvider).payouts(page: 1);
    return PayoutsState(items: page.items, available: available, minPayout: min, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(PayoutsState(items: s.items, available: s.available, minPayout: s.minPayout, page: s.page, hasMore: s.hasMore, loadingMore: true));
    try {
      final (page, available, min) = await ref.read(driverRepositoryProvider).payouts(page: s.page + 1);
      state = AsyncData(PayoutsState(items: [...s.items, ...page.items], available: available, minPayout: min, page: s.page + 1, hasMore: page.hasMore));
    } catch (_) {
      state = AsyncData(s);
    }
  }
}

final payoutsProvider = AsyncNotifierProvider.autoDispose<PayoutsController, PayoutsState>(PayoutsController.new);
