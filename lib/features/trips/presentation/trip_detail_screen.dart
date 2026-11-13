import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/app_map.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/polyline.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/trip_models.dart';
import 'trip_providers.dart';
import 'widgets/trip_widgets.dart';

/// Historical trip details (customer or driver view, based on `viewer_role`).
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: AsyncView<Trip>(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        data: (t) => RefreshIndicator(
          onRefresh: () => ref.refresh(tripDetailProvider(tripId).future),
          child: _body(context, t),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Trip t) {
    final driverView = t.isDriverView;
    final other = driverView ? t.customer : t.driver;
    final completedAt = t.timeline.completedAt;
    final canRate = t.isCompleted && t.myRating == null && completedAt != null && DateTime.now().difference(completedAt).inDays < 7;
    final route = routePoints(t.polyline, t.pickup.point, t.dropoff.point);
    return ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
      ClipRRect(
        borderRadius: AppRadius.card,
        child: SizedBox(
          height: 180,
          child: IgnorePointer(
            child: AppMap(
              initialTarget: GeoPoint((t.pickup.lat + t.dropoff.lat) / 2, (t.pickup.lng + t.dropoff.lng) / 2),
              zoom: 12,
              myLocationEnabled: false,
              markers: [
                MapMarker(id: 'p', point: t.pickup.point, kind: MapMarkerKind.pickup),
                MapMarker(id: 'd', point: t.dropoff.point, kind: MapMarkerKind.dropoff),
              ],
              route: route,
              placeholderLabel: 'Route map',
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(formatDateTime(t.createdAt), style: AppText.label)),
            StatusChip(label: t.statusLabel, tone: StatusChip.toneFor(t.status), dense: true),
          ]),
          const SizedBox(height: AppSpace.sm),
          RouteSummary(from: t.pickup.address ?? '', to: t.dropoff.address ?? ''),
          const SizedBox(height: AppSpace.sm),
          Text(
            [formatDistance(t.distanceM), formatDuration(t.durationS), if (t.vehicleCategory != null) t.vehicleCategory!.replaceFirst('FemaleRider ', '')].join(' · '),
            style: AppText.caption,
          ),
          if (t.isCancelled && t.cancelReason != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text('Cancelled by ${t.cancelledBy ?? 'unknown'}: ${t.cancelReason}', style: AppText.bodySm.copyWith(color: AppColors.danger)),
          ],
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Row(children: [
          AppAvatar(url: other.photoUrl, name: other.firstName, size: 48),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(driverView ? 'Passenger' : 'Driver', style: AppText.caption),
              Text(other.firstName, style: AppText.h3),
              if (!driverView && t.vehicle != null) Text(t.vehicle!.title, style: AppText.bodySm),
            ]),
          ),
          if (!driverView && t.vehicle?.plateNumber != null) PlateBadge(t.vehicle!.plateNumber!),
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FARE', style: AppText.overline),
          const SizedBox(height: AppSpace.xs),
          if (t.fareBreakdown.isNotEmpty)
            ...fareBreakdownRows(t.fareBreakdown, currency: t.currency, driverView: driverView)
          else ...[
            KeyValueRow('Agreed fare', formatMoney(t.agreedFare, currency: t.currency)),
            if (t.cancellationFee > 0) KeyValueRow('Cancellation fee', formatMoney(t.cancellationFee, currency: t.currency), bold: true),
          ],
          const Divider(height: 20),
          KeyValueRow('Payment', '${humanize(t.paymentMethod)} · ${humanize(t.paymentStatus ?? 'pending')}'),
          if (t.myRating != null) KeyValueRow('Your rating', '${t.myRating} ★'),
        ]),
      ),
      if (t.timeline.assignedAt != null) ...[
        const SizedBox(height: AppSpace.md),
        AppCard(child: TripTimelineView(trip: t)),
      ],
      const SizedBox(height: AppSpace.lg),
      if (t.isCompleted && !driverView) ...[
        AppButton(label: 'View receipt', icon: Icons.receipt_long_rounded, onPressed: () => context.push(Routes.receipt(t.id))),
        const SizedBox(height: AppSpace.sm),
      ],
      if (canRate) ...[
        AppButton.secondary(
          label: driverView ? 'Rate passenger' : 'Rate driver',
          icon: Icons.star_outline_rounded,
          onPressed: () => context.push(driverView ? Routes.driverRate(t.id) : Routes.rateTrip(t.id)),
        ),
        const SizedBox(height: AppSpace.sm),
      ],
      if (t.isActive)
        AppButton(label: 'Open live trip', onPressed: () => context.go(driverView ? Routes.driverTrip(t.id) : Routes.trip(t.id)))
      else ...[
        Row(children: [
          Expanded(child: AppButton.secondary(label: 'Get help', height: 48, icon: Icons.support_agent_rounded, onPressed: () => context.push('${Routes.newTicket}?tripId=${t.id}'))),
          const SizedBox(width: AppSpace.xs),
          Expanded(child: AppButton.secondary(label: 'Safety report', height: 48, icon: Icons.shield_outlined, onPressed: () => context.push(Routes.safetyReport(tripId: t.id)))),
        ]),
        if (t.isCompleted && !driverView) ...[
          const SizedBox(height: AppSpace.sm),
          TextButton(onPressed: () => context.push(Routes.refund(t.id)), child: const Text('Request a refund')),
        ],
      ],
    ]);
  }
}
