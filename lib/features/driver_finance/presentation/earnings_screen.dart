import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/domain/driver_models.dart';
import 'finance_providers.dart';
import 'widgets/earnings_chart.dart';

/// Driver earnings by period with a daily bar chart.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(earningsProvider(_period));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Earnings', style: AppText.h3.copyWith(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(earningsProvider(_period).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.night,
                selectedForegroundColor: Colors.white,
                foregroundColor: AppColors.inkSoft,
              ),
              segments: const [
                ButtonSegment(value: 'today', label: Text('Today')),
                ButtonSegment(value: 'week', label: Text('This week')),
                ButtonSegment(value: 'month', label: Text('This month')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: AppSpace.md),
            AsyncView<EarningsReport>(
              value: report,
              skipLoadingOnRefresh: false,
              onRetry: () => ref.invalidate(earningsProvider(_period)),
              loading: const Column(children: [
                Skeleton(height: 120, radius: 20),
                SizedBox(height: AppSpace.sm),
                Skeleton(height: 220, radius: 20),
              ]),
              data: (r) => _Body(report: r),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});
  final EarningsReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;
    String m(num v) => formatMoney(v, currency: report.currency);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(gradient: AppColors.driverGradient, borderRadius: AppRadius.card),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NET EARNINGS', style: AppText.overline.copyWith(color: Colors.white60)),
          const SizedBox(height: 4),
          Text(m(s.netEarnings), style: AppText.money.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('${s.completedTrips} completed · ${s.cancelledTrips} cancelled', style: AppText.bodySm.copyWith(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: AppSpace.sm),
      Row(children: [
        Expanded(child: _Tile(label: 'Gross fares', value: m(s.grossFares))),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: _Tile(label: 'Commission', value: '− ${m(s.commission)}')),
      ]),
      const SizedBox(height: AppSpace.sm),
      Row(children: [
        Expanded(child: _Tile(label: 'Cash collected', value: m(s.cashCollected))),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: _Tile(label: 'Trips', value: '${s.completedTrips}')),
      ]),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Daily earnings', style: AppText.h3),
          const SizedBox(height: AppSpace.sm),
          EarningsBarChart(daily: report.daily, currency: report.currency, period: report.period),
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      Row(children: [
        Expanded(child: AppButton.secondary(label: 'Ledger', icon: Icons.receipt_long_outlined, onPressed: () => context.push(Routes.driverLedger))),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: AppButton.secondary(label: 'Payouts', icon: Icons.account_balance_outlined, onPressed: () => context.push(Routes.driverPayouts))),
      ]),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 4),
        Text(value, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
