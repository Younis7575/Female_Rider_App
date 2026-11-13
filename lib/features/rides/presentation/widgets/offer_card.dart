import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/ride_models.dart';

/// A driver's offer (or my pending counter) on a ride request.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.currency,
    this.onAccept,
    this.onDecline,
    this.onCounter,
    this.busy = false,
  });

  final RideOffer offer;
  final String currency;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCounter;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final d = offer.driver;
    final v = offer.vehicle;
    final waiting = offer.byCustomer;
    return AppCard(
      shadow: true,
      border: false,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppAvatar(url: d?.photoUrl, name: d?.firstName, size: 52),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d?.firstName ?? 'Driver', style: AppText.h3),
              const SizedBox(height: 2),
              Row(children: [
                RatingBadge(rating: d?.rating),
                const SizedBox(width: 8),
                Text('${d?.completedTrips ?? 0} trips', style: AppText.caption),
              ]),
              if (v != null && (v.title.isNotEmpty || v.plateNumber != null)) ...[
                const SizedBox(height: 4),
                Text(
                  [if (v.title.isNotEmpty) v.title, ?v.plateNumber].join(' · '),
                  style: AppText.bodySm.copyWith(color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMoney(offer.amount, currency: currency), style: AppText.h2.copyWith(color: AppColors.crimson)),
            const SizedBox(height: 2),
            if (offer.etaS != null || offer.distanceToPickupM != null)
              Text(
                [if (offer.etaS != null) formatDuration(offer.etaS), if (offer.distanceToPickupM != null) formatDistance(offer.distanceToPickupM)].join(' · '),
                style: AppText.caption,
              ),
          ]),
        ]),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Icon(waiting ? Icons.hourglass_top_rounded : Icons.timer_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          Expanded(
            child: CountdownText(
              deadline: offer.expiresAt,
              builder: (_, left) => Text(
                waiting ? 'Your counter-offer · expires in ${formatCountdown(left)}' : 'Offer expires in ${formatCountdown(left)}',
                style: AppText.caption.copyWith(color: left.inSeconds <= 10 ? AppColors.danger : AppColors.muted),
              ),
            ),
          ),
        ]),
        if (offer.expiresAt != null) ...[
          const SizedBox(height: 6),
          _ExpiryBar(expiresAt: offer.expiresAt!, createdAt: offer.createdAt),
        ],
        const SizedBox(height: AppSpace.sm),
        if (waiting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: AppSpace.xs),
              Text('Waiting for driver…', style: AppText.label),
            ]),
          )
        else
          Row(children: [
            Expanded(
              child: AppButton.secondary(
                key: ValueKey('offer-decline-${offer.id}'),
                label: 'Decline',
                height: 46,
                onPressed: busy ? null : onDecline,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: AppButton.secondary(
                key: ValueKey('offer-counter-${offer.id}'),
                label: 'Re-bid',
                height: 46,
                onPressed: busy ? null : onCounter,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              flex: 2,
              child: AppButton(
                key: ValueKey('offer-accept-${offer.id}'),
                label: 'Accept',
                height: 46,
                loading: busy,
                onPressed: busy ? null : onAccept,
              ),
            ),
          ]),
      ]),
    );
  }
}

class _ExpiryBar extends StatelessWidget {
  const _ExpiryBar({required this.expiresAt, this.createdAt});
  final DateTime expiresAt;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    return CountdownText(
      deadline: expiresAt,
      builder: (_, left) {
        final total = createdAt != null ? expiresAt.difference(createdAt!).inMilliseconds : 45000;
        final frac = total <= 0 ? 0.0 : (left.inMilliseconds / total).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            backgroundColor: AppColors.field,
            color: frac < 0.25 ? AppColors.danger : AppColors.crimson,
          ),
        );
      },
    );
  }
}
