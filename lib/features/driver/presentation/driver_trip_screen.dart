import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/location/app_map.dart';
import '../../../core/location/driver_tracker.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../../core/realtime/live_sync.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/polyline.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../chat/presentation/chat_button.dart';
import '../../safety/presentation/sos.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_models.dart';
import 'widgets/pin_pad.dart';

/// Driver's live trip: pickup navigation, PIN start, completion and cash collection.
class DriverTripScreen extends ConsumerStatefulWidget {
  const DriverTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends ConsumerState<DriverTripScreen> {
  final _map = AppMapController();
  final _pinKey = GlobalKey<PinPadState>();
  LiveSync? _sync;
  Trip? _trip;
  Object? _error;
  bool _busy = false;
  String? _pinError;
  bool _closedHandled = false;
  bool _fitted = false;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(driverTrackerProvider.notifier).attachTrip(widget.tripId);
    });
    _sync = LiveSync(
      service: ref.read(realtimeServiceProvider),
      channels: [RealtimeService.tripChannel(widget.tripId)],
      onEvent: _onEvent,
      refresh: _load,
      pollInterval: const Duration(seconds: 8),
    )..start();
    _load();
  }

  @override
  void dispose() {
    _sync?.dispose();
    super.dispose();
  }

  void _onEvent(RealtimeEvent e) {
    if (e.event == RtEvents.tripUpdated || e.event == RtEvents.tripMessage) _load();
  }

  Future<void> _load() async {
    try {
      final t = await _repo.trip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = t;
        _error = null;
      });
      _afterUpdate(t);
    } catch (e) {
      if (mounted && _trip == null) setState(() => _error = e);
    }
  }

  void _apply(Trip t) {
    setState(() => _trip = t);
    _afterUpdate(t);
  }

  void _afterUpdate(Trip t) {
    if (!_fitted) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _map.fit([t.pickup.point, t.dropoff.point], padding: 90));
    }
    if (!t.isActive && !_closedHandled) {
      _closedHandled = true;
      ref.read(driverTrackerProvider.notifier).detachTrip();
      ref.read(sessionProvider.notifier).setActiveTrip(null);
    }
  }

  Future<void> _act(Future<Trip> Function() call, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final t = await call();
      if (!mounted) return;
      _apply(t);
      if (success != null) showSnack(context, success, success: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startWithPin(String pin) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pinError = null;
    });
    try {
      final t = await _repo.start(widget.tripId, pin);
      if (!mounted) return;
      _apply(t);
      showSnack(context, 'Trip started. Drive safely!', success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final left = e.attemptsLeft;
      setState(() => _pinError = e.code == 'pin_invalid' && left != null ? '${e.message} ($left left)' : e.message);
      _pinKey.currentState?.clear();
      if (e.code == 'invalid_transition') await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      _pinKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Complete this trip?',
      message: 'Only complete the trip once the passenger has safely reached the destination.',
      confirmLabel: 'Complete trip',
      icon: Icons.flag_rounded,
    );
    if (ok) await _act(() => _repo.complete(widget.tripId), success: 'Trip completed');
  }

  Future<void> _cashCollected() async {
    final t = _trip!;
    final ok = await showConfirmDialog(
      context,
      title: 'Cash collected?',
      message: 'Confirm you received ${formatMoney(t.amountDue ?? t.displayFare, currency: t.currency)} in cash from ${t.customer.firstName}.',
      confirmLabel: 'Yes, collected',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.cashCollected(widget.tripId);
      if (mounted) showSnack(context, 'Cash payment recorded', success: true);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reasons = ref.read(appConfigProvider).driverCancelReasons;
    final reason = await showReasonPicker(
      context,
      title: 'Cancel this trip?',
      reasons: reasons,
      warning: 'Frequent cancellations affect your standing. If you feel unsafe, use SOS.',
      confirmLabel: 'Cancel trip',
    );
    if (reason == null) return;
    await _act(() => _repo.cancel(widget.tripId, reason), success: 'Trip cancelled');
  }

  Future<void> _navigate(GeoPoint p) async {
    final uris = <Uri>[
      if (Platform.isAndroid) Uri.parse('google.navigation:q=${p.lat},${p.lng}&mode=d'),
      if (Platform.isIOS) Uri.parse('comgooglemaps://?daddr=${p.lat},${p.lng}&directionsmode=driving'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving'),
    ];
    for (final u in uris) {
      try {
        if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) showSnack(context, 'Could not open navigation app', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.night, foregroundColor: Colors.white, title: const Text('Trip')),
        body: _error != null ? ErrorState(error: _error!, onRetry: _load) : const LoadingView(message: 'Loading trip…'),
      );
    }
    final tracker = ref.watch(driverTrackerProvider);
    final rt = ref.watch(realtimeStatusProvider).value;
    final fix = tracker.lastFix;
    final toPickup = const [TripStatus.assigned, TripStatus.enRoute, TripStatus.arrived].contains(t.status);
    final route = routePoints(t.polyline, t.pickup.point, t.dropoff.point);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(children: [
        Positioned.fill(
          child: AppMap(
            controller: _map,
            initialTarget: t.pickup.point,
            dark: true,
            myLocationEnabled: false,
            route: route,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4, top: 80),
            markers: [
              MapMarker(id: 'pickup', point: t.pickup.point, kind: MapMarkerKind.pickup, title: 'Pickup'),
              MapMarker(id: 'dropoff', point: t.dropoff.point, kind: MapMarkerKind.dropoff, title: 'Drop-off'),
              if (fix != null) MapMarker(id: 'me', point: fix.point, kind: MapMarkerKind.driver, rotation: fix.heading ?? 0),
            ],
          ),
        ),
        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Column(children: [
              Row(children: [
                CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Dashboard', onPressed: () => context.go(Routes.driverHome)),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(AppRadius.pill), boxShadow: AppShadows.floating),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: t.isActive ? AppColors.success : AppColors.subtle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.statusLabel, style: AppText.title.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
                if (t.isActive) ...[
                  const SizedBox(width: AppSpace.sm),
                  SosButton(size: 48, onPressed: () => runSosFlow(context, ref, tripId: t.id)),
                ],
              ]),
              if (rt != null && rt != RealtimeStatus.connected && t.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: const OfflineBanner()),
                ),
            ]),
          ),
        ),
        // Bottom panel
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (t.status == TripStatus.arrived ? 0.82 : 0.66)),
            child: Container(
              decoration: const BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.sheet, boxShadow: AppShadows.floating),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: AppSpace.sm),
                    _CustomerRow(trip: t, onSupport: () => context.push('${Routes.newTicket}?tripId=${t.id}'), onChatReturn: _load),
                    const SizedBox(height: AppSpace.sm),
                    _RouteSummary(trip: t, highlightPickup: toPickup),
                    const SizedBox(height: AppSpace.md),
                    ..._statusPanel(t),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _statusPanel(Trip t) {
    final cfg = ref.read(appConfigProvider);
    switch (t.status) {
      case TripStatus.assigned:
        return [
          AppButton(label: 'Start driving to pickup', icon: Icons.directions_car_rounded, loading: _busy, onPressed: () => _act(() => _repo.markEnRoute(t.id), success: 'Passenger notified you are on the way')),
          const SizedBox(height: AppSpace.xs),
          AppButton.secondary(label: 'Navigate to pickup', icon: Icons.navigation_rounded, onPressed: () => _navigate(t.pickup.point)),
          _cancelLink(),
        ];
      case TripStatus.enRoute:
        return [
          AppButton(label: 'I\'ve arrived', icon: Icons.where_to_vote_rounded, loading: _busy, onPressed: () => _act(() => _repo.markArrived(t.id), success: 'Passenger notified of your arrival')),
          const SizedBox(height: AppSpace.xs),
          AppButton.secondary(label: 'Navigate to pickup', icon: Icons.navigation_rounded, onPressed: () => _navigate(t.pickup.point)),
          _cancelLink(),
        ];
      case TripStatus.arrived:
        return [
          Text('Enter trip PIN', style: AppText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Ask ${t.customer.firstName} for her ${cfg.pinLength}-digit PIN once she is in the vehicle.', style: AppText.bodySm, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.md),
          PinPad(key: _pinKey, length: cfg.pinLength, busy: _busy, error: _pinError, onCompleted: _startWithPin),
          _cancelLink(),
        ];
      case TripStatus.inProgress:
        return [
          InfoBanner(
            tone: StatusTone.info,
            icon: Icons.route_rounded,
            message: 'Heading to ${t.dropoff.address ?? 'the destination'} · ${formatDistance(t.distanceM)} · ${formatDuration(t.durationS)}',
          ),
          const SizedBox(height: AppSpace.sm),
          AppButton.secondary(label: 'Navigate to drop-off', icon: Icons.navigation_rounded, onPressed: () => _navigate(t.dropoff.point)),
          const SizedBox(height: AppSpace.xs),
          AppButton(label: 'Complete trip', icon: Icons.flag_rounded, loading: _busy, onPressed: _complete),
        ];
      case TripStatus.completed:
        final paid = t.isCashPaid;
        final due = t.amountDue ?? t.displayFare;
        return [
          _FareBreakdown(trip: t),
          const SizedBox(height: AppSpace.md),
          if (t.paymentMethod == 'cash')
            paid
                ? const InfoBanner(tone: StatusTone.success, icon: Icons.check_circle_rounded, message: 'Cash payment recorded. Thank you!')
                : AppButton(
                    label: 'Cash collected · ${formatMoney(due, currency: t.currency)}',
                    icon: Icons.payments_rounded,
                    loading: _busy,
                    onPressed: due > 0 ? _cashCollected : null,
                  ),
          const SizedBox(height: AppSpace.xs),
          if (t.myRating == null)
            AppButton.secondary(label: 'Rate ${t.customer.firstName}', icon: Icons.star_outline_rounded, onPressed: () => context.push(Routes.driverRate(t.id)))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Text('You rated this trip ${t.myRating}★', style: AppText.bodySm, textAlign: TextAlign.center),
            ),
          const SizedBox(height: AppSpace.xs),
          AppButton(variant: AppButtonVariant.dark, label: 'Back to dashboard', onPressed: () => context.go(Routes.driverHome)),
        ];
      default:
        if (t.isCancelled) {
          return [
            InfoBanner(
              tone: StatusTone.danger,
              icon: Icons.cancel_outlined,
              title: t.cancelledBy == 'driver' ? 'You cancelled this trip' : 'Trip cancelled',
              message: t.cancelReason ?? 'This trip is no longer active.',
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(variant: AppButtonVariant.dark, label: 'Back to dashboard', onPressed: () => context.go(Routes.driverHome)),
          ];
        }
        return [
          InfoBanner(
            tone: StatusTone.warning,
            icon: Icons.pause_circle_outline_rounded,
            title: t.statusLabel,
            message: 'Our safety team is reviewing this trip. Please follow their instructions or contact support.',
          ),
          const SizedBox(height: AppSpace.sm),
          AppButton.secondary(label: 'Contact support', onPressed: () => context.push('${Routes.newTicket}?tripId=${t.id}')),
        ];
    }
  }

  Widget _cancelLink() => Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Cancel trip'),
        ),
      );
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.trip, required this.onSupport, required this.onChatReturn});
  final Trip trip;
  final VoidCallback onSupport;
  final VoidCallback onChatReturn;

  @override
  Widget build(BuildContext context) {
    final c = trip.customer;
    return Row(children: [
      AppAvatar(url: c.photoUrl, name: c.firstName, size: 48),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.firstName, style: AppText.h3),
          Row(children: [
            RatingBadge(rating: c.rating),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${(trip.vehicleCategory ?? '').replaceFirst('FemaleRider ', '')} · ${humanize(trip.paymentMethod)}',
                style: AppText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatMoney(trip.displayFare, currency: trip.currency), style: AppText.h3),
        Text('Agreed fare', style: AppText.caption),
      ]),
      if (trip.chatEnabled || trip.chatUnread > 0) ...[
        const SizedBox(width: 4),
        TripChatIconButton(tripId: trip.id, unread: trip.chatUnread, onReturn: onChatReturn),
      ],
      IconButton(tooltip: 'Support', onPressed: onSupport, icon: const Icon(Icons.support_agent_rounded)),
    ]);
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.trip, required this.highlightPickup});
  final Trip trip;
  final bool highlightPickup;

  @override
  Widget build(BuildContext context) {
    final note = trip.pickupNote;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _line(Icons.radio_button_checked_rounded, AppColors.ink, 'Pickup', trip.pickup.address ?? 'Pickup point', highlightPickup),
        const SizedBox(height: AppSpace.xs),
        _line(Icons.location_on_rounded, AppColors.crimson, 'Drop-off', trip.dropoff.address ?? 'Destination', !highlightPickup),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xs),
          Row(children: [
            const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(child: Text('Note: $note', style: AppText.bodySm.copyWith(color: AppColors.inkSoft))),
          ]),
        ],
      ]),
    );
  }

  Widget _line(IconData icon, Color color, String label, String text, bool strong) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: AppText.overline),
            Text(text, style: strong ? AppText.title : AppText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);
}

class _FareBreakdown extends StatelessWidget {
  const _FareBreakdown({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final b = trip.fareBreakdown;
    String m(num? v) => formatMoney(v ?? 0, currency: trip.currency);
    final waiting = asDouble(b['waiting_charge']);
    final discount = asDouble(b['discount'], trip.discountAmount);
    final commission = trip.commissionAmount ?? asDoubleOrNull(b['commission']);
    final earning = trip.driverEarning ?? asDoubleOrNull(b['driver_earning']);
    final rate = asDoubleOrNull(b['commission_rate']);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: AppSpace.xs),
          Text('Trip completed', style: AppText.h3),
        ]),
        const SizedBox(height: AppSpace.sm),
        KeyValueRow('Agreed fare', m(asDoubleOrNull(b['agreed_fare']) ?? trip.agreedFare)),
        if (waiting > 0) KeyValueRow('Waiting (${asInt(b['waiting_minutes'])} min)', m(waiting)),
        if (discount > 0) KeyValueRow('Customer discount', '− ${m(discount)}'),
        KeyValueRow('Total fare', m(asDoubleOrNull(b['total_fare']) ?? trip.displayFare)),
        if (commission != null) KeyValueRow('FemaleRider commission${rate != null ? ' (${rate.toStringAsFixed(0)}%)' : ''}', '− ${m(commission)}'),
        const Divider(height: 20),
        if (earning != null) KeyValueRow('Your earning', m(earning), bold: true, valueColor: AppColors.success),
        KeyValueRow('Collect from passenger', m(trip.amountDue ?? asDoubleOrNull(b['amount_due'])), bold: true),
      ]),
    );
  }
}
