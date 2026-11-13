import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';

/// Statement for a month key `YYYY-MM`.
final statementProvider = FutureProvider.autoDispose.family<DriverStatement, String>((ref, month) {
  return ref.watch(driverRepositoryProvider).statement(month: month);
});

String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

/// Monthly statements (`GET /driver/statements?month=YYYY-MM`) with a month picker.
class StatementsScreen extends ConsumerStatefulWidget {
  const StatementsScreen({super.key});

  @override
  ConsumerState<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends ConsumerState<StatementsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrent {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months = List.generate(24, (i) => DateTime(now.year, now.month - i));
    final picked = await showAppSheet<DateTime>(
      context,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm), child: Text('Choose a month', style: AppText.h3)),
          Expanded(
            child: ListView(children: [
              for (final m in months)
                ListTile(
                  title: Text(DateFormat('MMMM y').format(m)),
                  trailing: m.year == _month.year && m.month == _month.month ? const Icon(Icons.check_rounded, color: AppColors.crimson) : null,
                  onTap: () => Navigator.of(ctx).pop(m),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final key = _monthKey(_month);
    final statement = ref.watch(statementProvider(key));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Statements', style: AppText.h3.copyWith(color: Colors.white)),
      ),
      body: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.xs),
          child: Row(children: [
            IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
            Expanded(
              child: TextButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(DateFormat('MMMM y').format(_month), style: AppText.title),
              ),
            ),
            IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right_rounded), onPressed: _isCurrent ? null : () => _shift(1)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.crimson,
            onRefresh: () async {
              ref.invalidate(statementProvider(key));
              await ref.read(statementProvider(key).future);
            },
            child: AsyncView<DriverStatement>(
              value: statement,
              onRetry: () => ref.invalidate(statementProvider(key)),
              loading: ListView(padding: const EdgeInsets.all(AppSpace.md), children: const [Skeleton(height: 320, radius: 20)]),
              data: (s) => _StatementBody(statement: s, month: _month, inProgress: _isCurrent),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatementBody extends StatelessWidget {
  const _StatementBody({required this.statement, required this.month, required this.inProgress});
  final DriverStatement statement;
  final DateTime month;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final s = statement.summary;
    String m(num v) => formatMoney(v, currency: statement.currency);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.summarize_rounded, color: AppColors.crimson),
              const SizedBox(width: AppSpace.xs),
              Expanded(child: Text('Statement · ${DateFormat('MMMM y').format(month)}', style: AppText.h3)),
              if (inProgress) const StatusChip(label: 'In progress', tone: StatusTone.warning, dense: true),
            ]),
            if (statement.from != null && statement.to != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${formatDate(statement.from)} – ${formatDate(statement.to)}', style: AppText.caption),
              ),
            const SizedBox(height: AppSpace.sm),
            KeyValueRow('Opening balance', m(s.openingBalance)),
            KeyValueRow('Completed trips', '${s.completedTrips}'),
            KeyValueRow('Cancelled by you', '${s.cancelledTrips}'),
            KeyValueRow('Gross fares', m(s.grossFares)),
            KeyValueRow('Commission', '− ${m(s.commission)}'),
            KeyValueRow('Cash collected from passengers', m(s.cashCollected)),
            KeyValueRow('Payouts paid', m(s.payoutsPaid)),
            const Divider(height: 16),
            KeyValueRow('Net earnings', m(s.netEarnings), bold: true, valueColor: AppColors.success),
            KeyValueRow(inProgress ? 'Current balance' : 'Closing balance', m(s.closingBalance), bold: true),
          ]),
        ),
        SectionHeader('Trips (${statement.trips.length})', padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
        if (statement.trips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Text('No completed trips this month.', style: AppText.bodySm, textAlign: TextAlign.center),
          )
        else
          for (final t in statement.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: AppCard(
                onTap: () => context.push(Routes.tripDetail(t.id)),
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(formatDateTime(t.completedAt), style: AppText.caption),
                      const SizedBox(height: 2),
                      Text(t.to ?? 'Trip', style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (t.from != null) Text('from ${t.from}', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(m(t.earning), style: AppText.title.copyWith(color: AppColors.success)),
                    Text('Fare ${m(t.fare)} · ${humanize(t.paymentMethod ?? 'cash')}', style: AppText.caption),
                  ]),
                ]),
              ),
            ),
        SectionHeader('Payouts (${statement.payouts.length})', padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
        if (statement.payouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Text('No payouts paid this month.', style: AppText.bodySm, textAlign: TextAlign.center),
          )
        else
          for (final p in statement.payouts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(children: [
                  const Icon(Icons.payments_outlined, color: AppColors.inkSoft),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(formatDateTime(p.paidAt), style: AppText.title),
                      if (p.reference != null) Text('Ref ${p.reference}', style: AppText.caption),
                    ]),
                  ),
                  Text(m(p.amount), style: AppText.title),
                ]),
              ),
            ),
      ],
    );
  }
}
