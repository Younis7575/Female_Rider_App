import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/trip_models.dart';
import 'trip_providers.dart';
import 'widgets/trip_widgets.dart';

/// Trip receipt shown after completion (and from history).
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptProvider(tripId));
    final trip = ref.watch(tripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home)),
      ),
      body: AsyncView<Receipt>(
        value: receipt,
        onRetry: () => ref.invalidate(receiptProvider(tripId)),
        data: (r) => _body(context, r, trip.value),
      ),
    );
  }

  Widget _body(BuildContext context, Receipt r, Trip? trip) {
    final canRate = trip != null && trip.myRating == null && trip.isCompleted;
    final paid = r.paymentStatus == 'paid';
    return ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
      Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: AppRadius.card, boxShadow: AppShadows.brand),
        child: Column(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44),
          const SizedBox(height: AppSpace.xs),
          Text('You\'ve arrived', style: AppText.h2.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpace.sm),
          Text(formatMoney(r.amountPaid, currency: r.currency), style: AppText.display.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            paid ? 'Paid in ${humanize(r.paymentMethod).toLowerCase()}' : 'Please pay your driver in ${humanize(r.paymentMethod).toLowerCase()}',
            style: AppText.bodySm.copyWith(color: Colors.white70),
          ),
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(r.receiptNumber, style: AppText.label),
            const Spacer(),
            StatusChip(label: humanize(r.paymentStatus ?? 'pending'), tone: StatusChip.toneFor(r.paymentStatus ?? 'pending'), dense: true),
          ]),
          const SizedBox(height: 2),
          Text(formatDateTime(r.date), style: AppText.caption),
          const Divider(height: 24),
          RouteSummary(from: r.from ?? '', to: r.to ?? ''),
          const SizedBox(height: AppSpace.sm),
          Text('${r.distanceKm.toStringAsFixed(1)} km · ${r.durationMin} min${r.vehicleCategory != null ? ' · ${r.vehicleCategory!.replaceFirst('FemaleRider ', '')}' : ''}', style: AppText.caption),
          if (r.driverFirstName != null) ...[
            const SizedBox(height: 4),
            Text('Driver: ${r.driverFirstName}${r.vehiclePlate != null ? ' · ${r.vehiclePlate}' : ''}', style: AppText.caption),
          ],
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FARE BREAKDOWN', style: AppText.overline),
          const SizedBox(height: AppSpace.xs),
          ...fareBreakdownRows(r.fareBreakdown, currency: r.currency),
          if (r.fareBreakdown.isEmpty) ...[
            KeyValueRow('Fare', formatMoney(r.total, currency: r.currency)),
            if (r.discount > 0) KeyValueRow('Discount', '− ${formatMoney(r.discount, currency: r.currency)}', valueColor: AppColors.success),
          ],
          const Divider(height: 20),
          KeyValueRow('Total', formatMoney(r.amountPaid, currency: r.currency), bold: true),
        ]),
      ),
      const SizedBox(height: AppSpace.lg),
      if (canRate) ...[
        AppButton(label: 'Rate your driver', icon: Icons.star_rounded, onPressed: () => context.push(Routes.rateTrip(tripId))),
        const SizedBox(height: AppSpace.sm),
      ],
      Row(children: [
        Expanded(child: AppButton.secondary(label: 'Request refund', height: 48, onPressed: () => context.push(Routes.refund(tripId)))),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: AppButton.secondary(label: 'Report issue', height: 48, onPressed: () => context.push('${Routes.newTicket}?tripId=$tripId'))),
      ]),
      const SizedBox(height: AppSpace.sm),
      AppButton(label: 'Done', variant: canRate ? AppButtonVariant.ghost : AppButtonVariant.primary, onPressed: () => context.go(Routes.home)),
    ]);
  }
}
