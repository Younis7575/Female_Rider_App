import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/driver_models.dart';

/// Incoming ride request card with negotiation actions.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onCounter,
    required this.onDecline,
    required this.onWithdraw,
    required this.onAcceptCounter,
    required this.onRejectCounter,
    required this.onCounterCounter,
    this.onExpired,
  });

  final DriverRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onCounter;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;
  final VoidCallback onAcceptCounter;
  final VoidCallback onRejectCounter;
  final VoidCallback onCounterCounter;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    final r = request;
    String money(num v) => formatMoney(v, currency: r.currency);
    final counter = r.hasCustomerCounter;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: counter ? AppColors.crimson : AppColors.line, width: counter ? 1.6 : 1),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header: customer + countdown
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 0),
          child: Row(children: [
            AppAvatar(name: r.customerFirstName, size: 40),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.customerFirstName, style: AppText.title),
                Row(children: [
                  RatingBadge(rating: r.customerRating),
                  const SizedBox(width: 8),
                  Flexible(child: Text('${r.customerRides} rides · ${r.vehicleCategory ?? ''}', style: AppText.caption, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
            CountdownText(
              deadline: r.expiresAt,
              onExpired: onExpired,
              builder: (_, left) => StatusChip(
                label: formatCountdown(left),
                icon: Icons.timer_outlined,
                tone: left.inSeconds < 30 ? StatusTone.danger : StatusTone.neutral,
                dense: true,
              ),
            ),
          ]),
        ),
        // Route
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 4),
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 2.5))),
              Container(width: 2, height: 30, color: AppColors.line),
              Container(width: 10, height: 10, color: AppColors.crimson),
            ]),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.pickup.address ?? 'Pickup point', style: AppText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  'Pickup ${formatDistance(r.pickupDistanceM)} away · ${formatDuration(r.pickupEtaS)}',
                  style: AppText.caption.copyWith(color: AppColors.crimson),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(r.dropoffArea ?? 'Destination area', style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Trip ${formatDistance(r.distanceM)} · ${formatDuration(r.durationS)} · ${humanize(r.paymentMethod)}', style: AppText.caption),
              ]),
            ),
            const SizedBox(width: AppSpace.xs),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('OFFERED', style: AppText.overline),
              Text(money(r.proposedFare), style: AppText.h2.copyWith(color: AppColors.ink)),
            ]),
          ]),
        ),
        if (r.pickupNote != null && r.pickupNote!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
            child: Row(children: [
              const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(r.pickupNote!, style: AppText.bodySm)),
            ]),
          ),
        const Divider(),
        Padding(padding: const EdgeInsets.all(AppSpace.sm), child: _actions(context, money)),
      ]),
    );
  }

  Widget _actions(BuildContext context, String Function(num) money) {
    final r = request;
    final offer = r.myOffer;
    if (r.hasCustomerCounter && offer != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(color: AppColors.roseSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded, color: AppColors.crimson),
            const SizedBox(width: AppSpace.xs),
            Expanded(child: Text('${r.customerFirstName} wants to go for ${money(offer.amount)}', style: AppText.title.copyWith(color: AppColors.crimson))),
            CountdownText(deadline: offer.expiresAt, builder: (_, left) => Text(formatCountdown(left), style: AppText.label)),
          ]),
        ),
        const SizedBox(height: AppSpace.sm),
        AppButton(key: ValueKey('req-accept-counter-${r.id}'), label: 'Accept ${money(offer.amount)}', loading: busy, onPressed: onAcceptCounter),
        const SizedBox(height: AppSpace.xs),
        Row(children: [
          Expanded(child: AppButton.secondary(label: 'Reject', height: 46, onPressed: busy ? null : onRejectCounter)),
          const SizedBox(width: AppSpace.xs),
          Expanded(child: AppButton.secondary(label: 'Bid higher', height: 46, icon: Icons.trending_up_rounded, onPressed: busy ? null : onCounterCounter)),
        ]),
      ]);
    }
    if (r.hasPendingOffer && offer != null) {
      return Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Offer sent · ${money(offer.amount)}', style: AppText.title),
            CountdownText(
              deadline: offer.expiresAt,
              builder: (_, left) => Text('Waiting for customer · expires in ${formatCountdown(left)}', style: AppText.caption),
            ),
          ]),
        ),
        TextButton(onPressed: busy ? null : onWithdraw, child: const Text('Withdraw')),
      ]);
    }
    final lastStatus = offer?.status;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (lastStatus == 'rejected' || lastStatus == 'expired' || lastStatus == 'withdrawn')
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.xs),
          child: Text(
            lastStatus == 'rejected' ? 'Customer declined your last offer. You can try again.' : 'Your last offer ${lastStatus == 'expired' ? 'expired' : 'was withdrawn'}.',
            style: AppText.caption.copyWith(color: AppColors.warning),
            textAlign: TextAlign.center,
          ),
        ),
      AppButton(key: ValueKey('req-accept-${r.id}'), label: 'Accept ${money(r.proposedFare)}', loading: busy, onPressed: onAccept),
      const SizedBox(height: AppSpace.xs),
      Row(children: [
        Expanded(child: AppButton.secondary(key: ValueKey('req-decline-${r.id}'), label: 'Decline', height: 46, onPressed: busy ? null : onDecline)),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: AppButton.secondary(key: ValueKey('req-counter-${r.id}'), label: 'Bid higher', icon: Icons.trending_up_rounded, height: 46, onPressed: busy ? null : onCounter)),
      ]),
    ]);
  }
}
