import 'package:material_ui/material_ui.dart';

import '../../../../core/network/json.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/trip_models.dart';

/// Number plate styled badge.
class PlateBadge extends StatelessWidget {
  const PlateBadge(this.plate, {super.key});
  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: 1.4),
      ),
      child: Text(plate.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: AppColors.ink)),
    );
  }
}

/// Origin → destination block with connector line.
class RouteSummary extends StatelessWidget {
  const RouteSummary({super.key, required this.from, required this.to, this.dense = false});
  final String from;
  final String to;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = dense ? AppText.bodySm.copyWith(color: AppColors.inkSoft) : AppText.title;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 2.5))),
          Container(width: 2, height: dense ? 18 : 24, color: AppColors.line),
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.rectangle)),
        ]),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(from.isEmpty ? 'Pickup' : from, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: dense ? 10 : 16),
          Text(to.isEmpty ? 'Drop-off' : to, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

/// Vertical status timeline for a trip.
class TripTimelineView extends StatelessWidget {
  const TripTimelineView({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final t = trip.timeline;
    final steps = <(String, DateTime?)>[
      ('Driver assigned', t.assignedAt),
      ('Driver on the way', t.enRouteAt),
      ('Driver arrived', t.arrivedAt),
      ('Trip started', t.startedAt),
      if (trip.isCancelled) ('Trip cancelled', t.cancelledAt) else ('Trip completed', t.completedAt),
    ];
    // A later step being done implies the earlier ones are (en route is optional).
    var lastDone = -1;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].$2 != null) lastDone = i;
    }
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        _TimelineRow(
          label: steps[i].$1,
          time: steps[i].$2,
          done: i <= lastDone,
          current: i == lastDone + 1 && trip.isActive,
          last: i == steps.length - 1,
          danger: trip.isCancelled && i == steps.length - 1,
        ),
    ]);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.time, required this.done, required this.current, required this.last, required this.danger});
  final String label;
  final DateTime? time;
  final bool done;
  final bool current;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : (done ? AppColors.crimson : (current ? AppColors.roseAccent : AppColors.line));
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : Colors.white,
                border: Border.all(color: color, width: 2.5),
              ),
              child: done ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
            ),
            if (!last) Expanded(child: Container(width: 2, color: done ? color : AppColors.line)),
          ]),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: AppText.title.copyWith(
                      color: done || current ? (danger ? AppColors.danger : AppColors.ink) : AppColors.subtle,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                    )),
              ),
              if (time != null) Text(formatTime(time), style: AppText.caption),
              if (current && time == null) Text('Now', style: AppText.caption.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Fare breakdown rows from a `fare_breakdown` map.
List<Widget> fareBreakdownRows(Json breakdown, {required String currency, bool driverView = false}) {
  final rows = <Widget>[];
  void money(String key, String label, {bool negative = false, bool bold = false}) {
    final v = asDoubleOrNull(breakdown[key]);
    if (v == null) return;
    if (v == 0 && (negative || key == 'waiting_charge' || key == 'booking_fee')) return;
    rows.add(KeyValueRow(
      label,
      '${negative ? '− ' : ''}${formatMoney(v, currency: currency)}',
      bold: bold,
      valueColor: negative ? AppColors.success : null,
    ));
  }

  money('base_fare', 'Base fare');
  money('distance_charge', 'Distance${breakdown['distance_km'] != null ? ' (${asDouble(breakdown['distance_km']).toStringAsFixed(1)} km)' : ''}');
  money('time_charge', 'Time${breakdown['duration_min'] != null ? ' (${asDouble(breakdown['duration_min']).round()} min)' : ''}');
  money('booking_fee', 'Booking fee');
  money('agreed_fare', 'Agreed fare');
  final waitMin = asIntOrNull(breakdown['waiting_minutes']);
  money('waiting_charge', 'Waiting${waitMin != null && waitMin > 0 ? ' ($waitMin min)' : ''}');
  money('total_fare', 'Total fare');
  money('discount', 'Discount', negative: true);
  if (driverView) {
    final rate = asDoubleOrNull(breakdown['commission_rate']);
    money('commission', 'Commission${rate != null ? ' (${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}%)' : ''}', negative: true);
    money('driver_earning', 'Your earning', bold: true);
  } else {
    money('amount_due', 'Amount due', bold: true);
  }
  return rows;
}

/// Icon for a vehicle category slug/icon value.
IconData vehicleIcon(String? iconOrSlug) {
  switch (iconOrSlug) {
    case 'bike':
      return Icons.two_wheeler_rounded;
    case 'rickshaw':
      return Icons.electric_rickshaw_rounded;
    case 'car_premium':
    case 'comfort':
      return Icons.local_taxi_rounded;
    default:
      return Icons.directions_car_filled_rounded;
  }
}

/// Compact list card for a trip (history).
class TripListCard extends StatelessWidget {
  const TripListCard({super.key, required this.trip, required this.onTap});
  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final driverView = trip.isDriverView;
    final amount = driverView && trip.driverEarning != null && trip.isCompleted ? trip.driverEarning! : (trip.isCancelled ? trip.cancellationFee : trip.displayFare);
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(vehicleIcon(trip.vehicleCategorySlug ?? (trip.vehicleCategory?.toLowerCase().contains('bike') == true ? 'bike' : (trip.vehicleCategory?.toLowerCase().contains('rickshaw') == true ? 'rickshaw' : 'car'))),
              size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(formatDateTime(trip.createdAt), style: AppText.caption)),
          StatusChip(label: trip.statusLabel, tone: StatusChip.toneFor(trip.status), dense: true),
        ]),
        const SizedBox(height: AppSpace.sm),
        RouteSummary(from: trip.pickup.address ?? '', to: trip.dropoff.address ?? '', dense: true),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Text(driverView ? trip.customer.firstName : trip.driver.firstName, style: AppText.label),
          if (trip.vehicle?.plateNumber != null) ...[
            Text('  ·  ', style: AppText.caption),
            Text(trip.vehicle!.plateNumber!, style: AppText.caption),
          ],
          const Spacer(),
          Text(formatMoney(amount, currency: trip.currency), style: AppText.h3),
        ]),
      ]),
    );
  }
}

/// Customer cancel-dialog warning from the server's `cancellation_policy`
/// ("Cancellation fee PKR X applies" / "Free cancellation until HH:MM"), falling back to
/// `/config.trip.customer_free_cancel_seconds` when the policy is absent.
String? cancellationWarning(Trip t, {required int freeCancelSeconds, DateTime? now}) {
  final at = now ?? DateTime.now();
  final policy = t.cancellationPolicy;
  if (policy != null) {
    final applies = policy.feeAppliesNow || (policy.fee > 0 && policy.freeUntil != null && at.isAfter(policy.freeUntil!));
    if (applies) return policy.fee > 0 ? 'Cancellation fee ${formatMoney(policy.fee, currency: t.currency)} applies.' : null;
    if (policy.freeUntil != null) {
      final after = policy.fee > 0 ? ' A fee of ${formatMoney(policy.fee, currency: t.currency)} applies after that.' : '';
      return 'Free cancellation until ${formatTime(policy.freeUntil)}.$after';
    }
    return null;
  }
  final assigned = t.timeline.assignedAt;
  if (assigned == null) return null;
  final freeUntil = assigned.add(Duration(seconds: freeCancelSeconds));
  if (t.status == TripStatus.arrived || at.isAfter(freeUntil)) return 'A cancellation fee may apply.';
  return 'Free cancellation until ${formatTime(freeUntil)}.';
}
