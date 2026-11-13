import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';
import 'finance_providers.dart';

/// Payout history and withdrawal requests.
class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  Future<void> _request(BuildContext context, WidgetRef ref, PayoutsState s) async {
    final amount = await showAppSheet<double>(context, builder: (_) => _PayoutSheet(available: s.available, min: s.minPayout));
    if (amount == null || !context.mounted) return;
    try {
      final (_, message) = await ref.read(driverRepositoryProvider).requestPayout(amount);
      if (context.mounted) showSnack(context, message ?? 'Payout requested', success: true);
      ref.invalidate(payoutsProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'payout_account_missing') {
        final go = await showConfirmDialog(context, title: 'Add payout account', message: e.message, confirmLabel: 'Add account');
        if (go && context.mounted) context.push(Routes.driverApplyPayout);
      } else {
        showSnack(context, e.message, error: true);
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(payoutsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Payouts', style: AppText.h3.copyWith(color: Colors.white)),
        actions: [
          IconButton(tooltip: 'Payout account', icon: const Icon(Icons.account_balance_outlined), onPressed: () => context.push(Routes.driverApplyPayout)),
        ],
      ),
      body: AsyncView<PayoutsState>(
        value: payouts,
        onRetry: () => ref.invalidate(payoutsProvider),
        data: (s) => RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.refresh(payoutsProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) ref.read(payoutsProvider.notifier).loadMore();
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(gradient: AppColors.driverGradient, borderRadius: AppRadius.card),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AVAILABLE FOR PAYOUT', style: AppText.overline.copyWith(color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text(formatMoney(s.available), style: AppText.money.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Minimum payout ${formatMoney(s.minPayout)}', style: AppText.caption.copyWith(color: Colors.white60)),
                    const SizedBox(height: AppSpace.md),
                    AppButton(
                      label: 'Request payout',
                      icon: Icons.account_balance_wallet_rounded,
                      onPressed: s.available >= s.minPayout ? () => _request(context, ref, s) : null,
                    ),
                    if (s.available < s.minPayout)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Text('You need at least ${formatMoney(s.minPayout)} available to request a payout.', style: AppText.caption.copyWith(color: Colors.white60)),
                      ),
                  ]),
                ),
                const SectionHeader('History', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
                if (s.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpace.lg),
                    child: EmptyState(icon: Icons.payments_outlined, title: 'No payouts yet', message: 'Requested payouts and their status will appear here.'),
                  )
                else
                  for (final p in s.items) Padding(padding: const EdgeInsets.only(bottom: AppSpace.xs), child: _PayoutTile(p: p)),
                if (s.loadingMore) const Padding(padding: EdgeInsets.all(AppSpace.md), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.p});
  final Payout p;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(formatMoney(p.amount, currency: p.currency), style: AppText.h3)),
          StatusChip(label: humanize(p.status), tone: StatusChip.toneFor(p.status)),
        ]),
        const SizedBox(height: 4),
        Text(
          [humanize(p.method), p.accountTitle, p.accountNumberMasked].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
          style: AppText.bodySm,
        ),
        Text(p.paidAt != null ? 'Paid ${formatDateTime(p.paidAt)}' : 'Requested ${formatDateTime(p.createdAt)}', style: AppText.caption),
        if (p.failureReason != null && p.failureReason!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(p.failureReason!, style: AppText.caption.copyWith(color: AppColors.danger)),
          ),
      ]),
    );
  }
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({required this.available, required this.min});
  final double available;
  final double min;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late final _ctrl = TextEditingController(text: widget.available.floor().toString());
  String? _error;

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null) {
      setState(() => _error = 'Enter an amount');
    } else if (v < widget.min) {
      setState(() => _error = 'Minimum payout is ${formatMoney(widget.min)}');
    } else if (v > widget.available) {
      setState(() => _error = 'You can withdraw up to ${formatMoney(widget.available)}');
    } else {
      Navigator.of(context).pop(v);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Request payout', style: AppText.h2),
          const SizedBox(height: 4),
          Text('Available ${formatMoney(widget.available)} · minimum ${formatMoney(widget.min)}', style: AppText.bodySm),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Amount (PKR)', errorText: _error, prefixIcon: const Icon(Icons.payments_outlined)),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => setState(() => _ctrl.text = widget.available.floor().toString()), child: const Text('Withdraw all')),
          ),
          const SizedBox(height: AppSpace.xs),
          AppButton(label: 'Request payout', onPressed: _submit),
        ]),
      ),
    );
  }
}
