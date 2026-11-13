import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/widgets/paged_list.dart';
import '../data/payment_repository.dart';

/// Payment history and refund requests.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(paymentRepositoryProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          bottom: const TabBar(tabs: [Tab(text: 'Payments'), Tab(text: 'Refunds')]),
        ),
        body: TabBarView(children: [
          PagedListView<Payment>(
            fetch: (page) => repo.payments(page: page),
            header: const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.sm),
              child: InfoBanner(
                icon: Icons.payments_outlined,
                message: 'Cash is currently the only payment method. Pay your driver the amount shown at the end of your trip.',
              ),
            ),
            empty: const EmptyState(icon: Icons.receipt_long_outlined, title: 'No payments yet', message: 'Payments for your completed trips will appear here.'),
            itemBuilder: (ctx, p, _) => _PaymentTile(payment: p, onTap: p.tripId == null ? null : () => context.push(Routes.tripDetail(p.tripId!))),
          ),
          PagedListView<Refund>(
            fetch: (page) => repo.refunds(page: page),
            empty: const EmptyState(
              icon: Icons.currency_exchange_rounded,
              title: 'No refund requests',
              message: 'To request a refund, open a completed trip from your ride history.',
            ),
            itemBuilder: (ctx, r, _) => _RefundTile(refund: r, onTap: r.tripId == null ? null : () => context.push(Routes.tripDetail(r.tripId!))),
          ),
        ]),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, this.onTap});
  final Payment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.roseSoft, shape: BoxShape.circle),
            child: Icon(p.method == 'cash' ? Icons.payments_rounded : Icons.credit_card_rounded, color: AppColors.crimson, size: 20),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(humanize(p.purpose ?? 'Trip fare'), style: AppText.title),
              Text('${humanize(p.method ?? 'cash')} · ${formatDateTime(p.paidAt ?? p.createdAt)}', style: AppText.caption),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMoney(p.amount, currency: p.currency), style: AppText.h3),
            const SizedBox(height: 2),
            StatusChip(label: humanize(p.status), tone: StatusChip.toneFor(p.status), dense: true),
          ]),
        ]),
        if (p.from != null || p.to != null) ...[
          const SizedBox(height: AppSpace.sm),
          const Divider(),
          const SizedBox(height: AppSpace.sm),
          _RouteLine(icon: Icons.radio_button_checked_rounded, color: AppColors.ink, text: p.from ?? '—'),
          const SizedBox(height: 4),
          _RouteLine(icon: Icons.location_on_rounded, color: AppColors.crimson, text: p.to ?? '—'),
        ],
        if (p.refundedAmount > 0) ...[
          const SizedBox(height: AppSpace.xs),
          Text('Refunded ${formatMoney(p.refundedAmount, currency: p.currency)}', style: AppText.caption.copyWith(color: AppColors.success)),
        ],
      ]),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: AppSpace.xs),
      Expanded(child: Text(text, style: AppText.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _RefundTile extends StatelessWidget {
  const _RefundTile({required this.refund, this.onTap});
  final Refund refund;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatMoney(refund.amount), style: AppText.h3),
            const SizedBox(height: 2),
            if (refund.reason != null) Text(refund.reason!, style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(formatDateTime(refund.createdAt), style: AppText.caption),
          ]),
        ),
        StatusChip(label: humanize(refund.status), tone: StatusChip.toneFor(refund.status), dense: true),
      ]),
    );
  }
}
