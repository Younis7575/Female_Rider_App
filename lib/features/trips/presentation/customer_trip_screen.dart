import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/location/app_map.dart';
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
import '../data/trip_repository.dart';
import '../domain/trip_models.dart';
import 'widgets/trip_widgets.dart';

/// Live trip for the customer: driver approach, PIN, progress, safety tools.
class CustomerTripScreen extends ConsumerStatefulWidget {
  const CustomerTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<CustomerTripScreen> createState() => _CustomerTripScreenState();
}

class _CustomerTripScreenState extends ConsumerState<CustomerTripScreen> {
  final _map = AppMapController();
  Trip? _trip;
  Object? _error;
  LiveSync? _sync;
  bool _left = false;
  bool _sharing = false;
  bool _cancelling = false;
  bool _fitted = false;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _sync = LiveSync(
      service: ref.read(realtimeServiceProvider),
      channels: [RealtimeService.tripChannel(widget.tripId)],
      onEvent: _onEvent,
      refresh: _refresh,
      pollInterval: const Duration(seconds: 8),
    )..start();
    _refresh();
  }

  @override
  void dispose() {
    _sync?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final t = await _repo.trip(widget.tripId);
      if (!mounted) return;
      setState(() {
        // Keep a fresher socket location if REST has none.
        _trip = t.driverLocation == null && _trip?.driverLocation != null && t.isActive ? t.copyWith(driverLocation: _trip!.driverLocation) : t;
        _error = null;
      });
      _afterUpdate(t);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _afterUpdate(Trip t) {
    if (!_fitted) {
      _fitted = true;
      _fitCamera(t);
    }
    if (t.isCompleted && !_left) {
      _left = true;
      ref.read(sessionProvider.notifier).setActiveTrip(null);
      context.go(Routes.receipt(t.id));
    } else if (t.isCancelled) {
      ref.read(sessionProvider.notifier).setActiveTrip(null);
    }
  }

  void _fitCamera(Trip t) {
    final pts = <GeoPoint>[
      if (t.driverLocation != null && t.status != TripStatus.inProgress) t.driverLocation!.point,
      if (t.status != TripStatus.inProgress) t.pickup.point,
      if (t.status == TripStatus.inProgress) ...[t.pickup.point, t.dropoff.point],
    ];
    Future.delayed(const Duration(milliseconds: 400), () => _map.fit(pts.isEmpty ? [t.pickup.point] : pts, padding: 80));
  }

  void _onEvent(RealtimeEvent e) {
    if (!mounted) return;
    switch (e.event) {
      case RtEvents.tripLocation:
        final t = _trip;
        if (t == null) return;
        final loc = DriverLocation.fromJson(e.data);
        setState(() => _trip = t.copyWith(driverLocation: loc));
      case RtEvents.tripMessage:
        _refresh();
      case RtEvents.tripUpdated:
        final status = asStringOrNull(e.data['status']);
        if (status != null && _trip != null) setState(() => _trip = _trip!.copyWith(status: status, statusLabel: humanize(status)));
        _refresh().then((_) {
          if (_trip != null) _fitCamera(_trip!);
        });
    }
  }

  // ---- Actions -------------------------------------------------------------

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final (url, expires) = await _repo.share(widget.tripId);
      final t = _trip;
      final text = StringBuffer('I\'m on a FemaleRider trip')
        ..write(t != null ? ' with ${t.driver.firstName}${t.vehicle?.plateNumber != null ? ' (${t.vehicle!.plateNumber})' : ''}' : '')
        ..write('. Follow my ride live: $url')
        ..write(expires != null ? '\nLink valid until ${formatTime(expires)}.' : '');
      await SharePlus.instance.share(ShareParams(text: text.toString(), subject: 'Track my FemaleRider trip'));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String? _cancelWarning(Trip t) => cancellationWarning(t, freeCancelSeconds: ref.read(appConfigProvider).customerFreeCancelSeconds);

  Future<void> _cancel() async {
    final t = _trip;
    if (t == null) return;
    final reason = await showReasonPicker(
      context,
      title: 'Cancel this trip?',
      reasons: ref.read(appConfigProvider).customerCancelReasons,
      warning: _cancelWarning(t),
      confirmLabel: 'Cancel trip',
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updated = await _repo.cancel(widget.tripId, reason);
      if (!mounted) return;
      ref.read(sessionProvider.notifier).setActiveTrip(null);
      setState(() => _trip = updated);
      showSnack(
        context,
        updated.cancellationFee > 0 ? 'Trip cancelled. A fee of ${formatMoney(updated.cancellationFee, currency: updated.currency)} applies.' : 'Trip cancelled.',
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      await _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ---- UI ------------------------------------------------------------------

  String _headline(Trip t) {
    final name = t.driver.firstName.isEmpty ? 'Your driver' : t.driver.firstName;
    switch (t.status) {
      case TripStatus.assigned:
        return '$name is getting ready';
      case TripStatus.enRoute:
        return '$name is on the way';
      case TripStatus.arrived:
        return 'Your driver has arrived';
      case TripStatus.inProgress:
        return 'On the way to ${(t.dropoff.address ?? 'your destination').split(',').first}';
      case TripStatus.safetyHold:
        return 'Trip on safety hold';
      case TripStatus.completed:
        return 'You have arrived';
      default:
        return t.isCancelled ? 'Trip cancelled' : t.statusLabel;
    }
  }

  String? _subline(Trip t) {
    final loc = t.driverLocation;
    if (t.status == TripStatus.assigned || t.status == TripStatus.enRoute) {
      int? eta = loc?.etaS;
      if (eta == null && loc != null) eta = (distanceMeters(loc.point, t.pickup.point) / 7).round();
      return eta != null ? 'Arriving in ${formatDuration(eta)}${loc?.distanceM != null ? ' · ${formatDistance(loc!.distanceM)} away' : ''}' : 'Heading to your pickup point';
    }
    if (t.status == TripStatus.arrived) return 'Meet ${t.driver.firstName} at the pickup point and check the plate number.';
    if (t.status == TripStatus.inProgress) return t.durationS != null ? 'About ${formatDuration(t.durationS)} trip · ${formatDistance(t.distanceM)}' : null;
    if (t.status == TripStatus.safetyHold) return 'Our safety team is reviewing this trip. Use SOS if you need urgent help.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    final rt = ref.watch(realtimeStatusProvider).value;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your trip')),
        body: _error != null ? ErrorState(error: _error!, onRetry: _refresh) : const LoadingView(message: 'Loading your trip…'),
      );
    }
    final size = MediaQuery.sizeOf(context);
    final markers = <MapMarker>[
      if (t.status != TripStatus.inProgress) MapMarker(id: 'pickup', point: t.pickup.point, kind: MapMarkerKind.pickup, title: 'Pickup'),
      MapMarker(id: 'dropoff', point: t.dropoff.point, kind: MapMarkerKind.dropoff, title: 'Drop-off'),
      if (t.driverLocation != null && t.isActive)
        MapMarker(id: 'driver', point: t.driverLocation!.point, kind: MapMarkerKind.driver, rotation: t.driverLocation!.heading ?? 0, title: t.driver.firstName),
    ];
    final route = t.status == TripStatus.inProgress ? routePoints(t.polyline, t.pickup.point, t.dropoff.point) : <GeoPoint>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: AppMap(
              initialTarget: t.driverLocation?.point ?? t.pickup.point,
              controller: _map,
              markers: markers,
              route: route,
              padding: EdgeInsets.only(bottom: size.height * 0.45, top: 80),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, 0),
                  child: Row(children: [
                    CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Home', onPressed: () => context.go(Routes.home)),
                    const Spacer(),
                    if (t.isActive) SosButton(onPressed: () => runSosFlow(context, ref, tripId: t.id)),
                  ]),
                ),
                if (rt != null && rt != RealtimeStatus.connected && t.isActive)
                  const Padding(padding: EdgeInsets.only(top: AppSpace.xs), child: OfflineBanner(message: 'Live updates paused — refreshing every few seconds.')),
              ]),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            builder: (context, scroll) => Container(
              decoration: const BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.sheet, boxShadow: AppShadows.floating),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.xl),
                children: t.isCancelled ? _cancelledContent(t) : _activeContent(t),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(margin: const EdgeInsets.only(top: 10, bottom: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
      );

  List<Widget> _cancelledContent(Trip t) => [
        _handle(),
        const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 48),
        const SizedBox(height: AppSpace.sm),
        Text('Trip cancelled', style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          '${t.cancelledBy == 'driver' ? 'Your driver cancelled this trip.' : (t.cancelledBy == 'admin' ? 'This trip was cancelled by FemaleRider support.' : 'You cancelled this trip.')}${t.cancelReason != null ? '\nReason: ${t.cancelReason}' : ''}',
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
        if (t.cancellationFee > 0) ...[
          const SizedBox(height: AppSpace.sm),
          InfoBanner(tone: StatusTone.warning, message: 'Cancellation fee: ${formatMoney(t.cancellationFee, currency: t.currency)}'),
        ],
        const SizedBox(height: AppSpace.lg),
        AppButton(label: 'Book another ride', onPressed: () => context.go(Routes.home)),
        const SizedBox(height: AppSpace.sm),
        AppButton.secondary(label: 'Contact support', onPressed: () => context.push('${Routes.newTicket}?tripId=${t.id}')),
      ];

  List<Widget> _activeContent(Trip t) {
    final sub = _subline(t);
    return [
      _handle(),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_headline(t), style: AppText.h2),
            if (sub != null) ...[const SizedBox(height: 4), Text(sub, style: AppText.bodySm)],
          ]),
        ),
        StatusChip(label: t.statusLabel, tone: StatusChip.toneFor(t.status)),
      ]),
      if (t.pickupPin != null) ...[
        const SizedBox(height: AppSpace.md),
        _PinCard(pin: t.pickupPin!),
      ],
      const SizedBox(height: AppSpace.md),
      _driverCard(t),
      const SizedBox(height: AppSpace.md),
      Row(children: [
        if (t.chatEnabled) ...[
          Expanded(
            child: _ActionTile(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              badge: t.chatUnread,
              onTap: () async {
                await context.push(Routes.tripChat(t.id));
                _refresh();
              },
            ),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
        Expanded(child: _ActionTile(icon: Icons.ios_share_rounded, label: 'Share', loading: _sharing, onTap: _share)),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: _ActionTile(icon: Icons.support_agent_rounded, label: 'Support', onTap: () => context.push('${Routes.newTicket}?tripId=${t.id}'))),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: _ActionTile(icon: Icons.shield_outlined, label: 'Safety', onTap: () => _safetySheet(t))),
      ]),
      const SizedBox(height: AppSpace.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RouteSummary(from: t.pickup.address ?? '', to: t.dropoff.address ?? ''),
          if (t.pickupNote != null && t.pickupNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('Note: ${t.pickupNote}', style: AppText.bodySm),
          ],
          const Divider(height: 24),
          Row(children: [
            const Icon(Icons.payments_outlined, size: 18, color: AppColors.muted),
            const SizedBox(width: 6),
            Text('Cash', style: AppText.label),
            const Spacer(),
            Text(formatMoney(t.amountDue ?? t.agreedFare, currency: t.currency), style: AppText.h3),
          ]),
          if (t.discountAmount > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Includes ${formatMoney(t.discountAmount, currency: t.currency)} discount', style: AppText.caption.copyWith(color: AppColors.success))),
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      Text('TRIP PROGRESS', style: AppText.overline),
      const SizedBox(height: AppSpace.sm),
      TripTimelineView(trip: t),
      if (t.status != TripStatus.inProgress && t.isActive) ...[
        const SizedBox(height: AppSpace.sm),
        AppButton.secondary(label: 'Cancel trip', loading: _cancelling, onPressed: _cancelling ? null : _cancel),
      ],
    ];
  }

  Widget _driverCard(Trip t) {
    final v = t.vehicle;
    return AppCard(
      child: Row(children: [
        AppAvatar(url: t.driver.photoUrl, name: t.driver.firstName, size: 56),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.driver.firstName, style: AppText.h3),
            const SizedBox(height: 2),
            Row(children: [
              RatingBadge(rating: t.driver.rating),
              const SizedBox(width: 8),
              Text('${t.driver.completedTrips ?? 0} trips', style: AppText.caption),
            ]),
            if (v != null) ...[
              const SizedBox(height: 4),
              Text([v.title, if (t.vehicleCategory != null) t.vehicleCategory!.replaceFirst('FemaleRider ', '')].where((e) => e.isNotEmpty).join(' · '),
                  style: AppText.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        if (v?.plateNumber != null) PlateBadge(v!.plateNumber!),
      ]),
    );
  }

  Future<void> _safetySheet(Trip t) async {
    final support = ref.read(appConfigProvider).support;
    await showAppSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Safety toolkit', style: AppText.h2),
          const SizedBox(height: AppSpace.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sos_rounded, color: AppColors.danger),
            title: const Text('Send SOS alert'),
            subtitle: const Text('Alerts our safety team with your live location'),
            onTap: () {
              Navigator.of(ctx).pop();
              runSosFlow(context, ref, tripId: t.id);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share live trip'),
            subtitle: const Text('Send a tracking link to someone you trust'),
            onTap: () {
              Navigator.of(ctx).pop();
              _share();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_gmailerrorred_rounded),
            title: const Text('Report a safety issue'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.push(Routes.safetyReport(tripId: t.id));
            },
          ),
          if (support.phone.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.call_outlined),
              title: Text('Call support · ${support.phone}'),
              subtitle: support.hours.isNotEmpty ? Text(support.hours) : null,
              onTap: () => launchUrl(Uri(scheme: 'tel', path: support.phone.replaceAll(RegExp(r'[^\d+]'), ''))),
            ),
        ]),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin});
  final String pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: AppRadius.card, boxShadow: AppShadows.brand),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR TRIP PIN', style: AppText.overline.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Text('Share this PIN only when you\'re in the car', style: AppText.bodySm.copyWith(color: Colors.white)),
          ]),
        ),
        Semantics(
          label: 'Trip PIN ${pin.split('').join(' ')}',
          child: Row(children: [
            for (final d in pin.split(''))
              Container(
                width: 38,
                height: 48,
                margin: const EdgeInsets.only(left: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.deepRed)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.loading = false, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : UnreadBadge(count: badge, child: Icon(icon, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(label, style: AppText.label),
          ]),
        ),
      ),
    );
  }
}
