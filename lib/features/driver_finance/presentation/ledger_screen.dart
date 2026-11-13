import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/domain/driver_models.dart';
import 'finance_providers.dart';

/// Driver payable ledger: every credit (trip earnings) and debit (commission, payouts).
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Ledger', style: AppText.h3.copyWith(color: Colors.white)),
      ),
      body: AsyncView<LedgerPageState>(
        value: ledger,
        onRetry: () => ref.invalidate(ledgerProvider),
        data: (s) => RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.refresh(ledgerProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) ref.read(ledgerProvider.notifier).loadMore();
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.md),
              itemCount: s.items.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return _BalanceHeader(balance: s.balance, currency: s.items.isNotEmpty ? s.items.first.currency : 'PKR');
                if (i == s.items.length + 1) {
                  if (s.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No ledger entries yet', message: 'Earnings and payouts will appear here after your first trip.'),
                    );
                  }
                  return s.loadingMore
                      ? const Padding(padding: EdgeInsets.all(AppSpace.md), child: Center(child: CircularProgressIndicator()))
                      : const SizedBox(height: AppSpace.xl);
                }
                return Padding(padding: const EdgeInsets.only(bottom: AppSpace.xs), child: LedgerTile(entry: s.items[i - 1]));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance, required this.currency});
  final double balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(gradient: AppColors.driverGradient, borderRadius: AppRadius.card),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CURRENT BALANCE', style: AppText.overline.copyWith(color: Colors.white60)),
            const SizedBox(height: 4),
            Text(formatMoney(balance, currency: currency), style: AppText.money.copyWith(color: Colors.white)),
          ]),
        ),
        TextButton(
          onPressed: () => context.push(Routes.driverPayouts),
          style: TextButton.styleFrom(foregroundColor: AppColors.roseAccent),
          child: const Text('Payouts'),
        ),
      ]),
    );
  }
}

/// One ledger row (also used by statements).
class LedgerTile extends StatelessWidget {
  const LedgerTile({super.key, required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final color = e.isCredit ? AppColors.success : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      onTap: e.tripId != null ? () => context.push(Routes.tripDetail(e.tripId!)) : null,
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: e.isCredit ? AppColors.successSoft : AppColors.dangerSoft, shape: BoxShape.circle),
          child: Icon(e.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 18),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(humanize(e.type), style: AppText.title),
            if (e.description != null && e.description!.isNotEmpty) Text(e.description!, style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(formatDateTime(e.createdAt), style: AppText.caption),
          ]),
        ),
        Text('${e.isCredit ? '+' : '−'} ${formatMoney(e.amount, currency: e.currency)}', style: AppText.title.copyWith(color: color)),
      ]),
    );
  }
}
