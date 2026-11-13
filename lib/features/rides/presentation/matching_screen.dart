import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../../core/realtime/live_sync.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../trips/presentation/widgets/trip_widgets.dart';
import '../data/ride_repository.dart';
import '../domain/ride_models.dart';
import 'widgets/offer_card.dart';
import 'widgets/radar.dart';

/// Searching / negotiation screen for an open ride request.
class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  late String _rideId = widget.rideId;
  RideRequest? _ride;
  List<RideOffer> _offers = const [];
  Object? _error;
  bool _loading = true;
  int? _busyOfferId;
  bool _cancelling = false;
  bool _retrying = false;
  bool _raising = false;
  bool _left = false;
  LiveSync? _sync;

  RideRepository get _repo => ref.read(rideRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  void _startSync() {
    _sync?.dispose();
    _sync = LiveSync(
      service: ref.read(realtimeServiceProvider),
      channels: [RealtimeService.rideChannel(_rideId)],
      onEvent: _onEvent,
      refresh: _refresh,
      pollInterval: const Duration(seconds: 5),
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
      final results = await Future.wait([_repo.ride(_rideId), _repo.offers(_rideId)]);
      if (!mounted) return;
      final ride = results[0] as RideRequest;
      final offers = results[1] as List<RideOffer>;
      setState(() {
        _ride = ride;
        _offers = _sortOffers(offers);
        _error = null;
        _loading = false;
      });
      _reactToStatus(ride);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refreshOffers() async {
    try {
      final offers = await _repo.offers(_rideId);
      if (mounted) setState(() => _offers = _sortOffers(offers));
    } catch (_) {}
  }

  List<RideOffer> _sortOffers(List<RideOffer> list) {
    final live = list.where((o) => o.status == 'pending').toList()
      ..sort((a, b) {
        // Driver offers first (actionable), then cheapest.
        if (a.byDriver != b.byDriver) return a.byDriver ? -1 : 1;
        return a.amount.compareTo(b.amount);
      });
    return live;
  }

  void _reactToStatus(RideRequest ride) {
    if (ride.isAccepted && ride.tripId != null) {
      _goToTrip(ride.tripId!);
    } else if (ride.status == 'cancelled_by_customer') {
      ref.read(sessionProvider.notifier).setActiveRide(null);
    } else if (!ride.isOpen) {
      ref.read(sessionProvider.notifier).setActiveRide(null);
    }
  }

  void _goToTrip(String tripId) {
    if (_left || !mounted) return;
    _left = true;
    ref.read(sessionProvider.notifier).setActiveTrip(tripId);
    context.go(Routes.trip(tripId));
  }

  void _onEvent(RealtimeEvent e) {
    if (!mounted) return;
    switch (e.event) {
      case RtEvents.rideMatching:
        final n = asIntOrNull(e.data['drivers_notified']);
        final r = asDoubleOrNull(e.data['radius_km']);
        if (_ride != null) setState(() => _ride = _ride!.copyWith(driversNotified: n, searchRadiusKm: r));
      case RtEvents.offerCreated:
      case RtEvents.offerCountered:
        final o = e.data['offer'];
        if (o is Map) {
          final offer = RideOffer.fromJson(asMap(o));
          setState(() {
            _offers = _sortOffers([..._offers.where((x) => x.id != offer.id && !(x.driver?.id == offer.driver?.id && offer.byDriver)), offer]);
            if (_ride != null && _ride!.status == 'searching') _ride = _ride!.copyWith(status: 'offers_available');
          });
        }
        _refreshOffers();
      case RtEvents.offerRejected:
      case RtEvents.offerWithdrawn:
      case RtEvents.offerExpired:
        final id = asIntOrNull(e.data['offer_id']) ?? asIntOrNull(asMap(e.data['offer'])['id']);
        if (id != null) setState(() => _offers = _offers.where((o) => o.id != id).toList());
        _refreshOffers();
      case RtEvents.rideAccepted:
        final tripId = asStringOrNull(e.data['trip_id']);
        if (tripId != null) _goToTrip(tripId);
      case RtEvents.rideCancelled:
      case RtEvents.rideExpired:
      case RtEvents.rideClosed:
        _refresh();
    }
  }

  // ---- Actions -------------------------------------------------------------

  Future<void> _accept(RideOffer o) async {
    setState(() => _busyOfferId = o.id);
    try {
      final trip = await _repo.acceptOffer(o.id);
      if (!mounted) return;
      _goToTrip(trip.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _decline(RideOffer o) async {
    setState(() => _busyOfferId = o.id);
    try {
      await _repo.rejectOffer(o.id);
      if (mounted) setState(() => _offers = _offers.where((x) => x.id != o.id).toList());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      await _refreshOffers();
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _counter(RideOffer o) async {
    final ride = _ride;
    if (ride == null) return;
    final amount = await showFareSheet(
      context,
      title: 'Re-bid to ${o.driver?.firstName ?? 'this driver'}',
      subtitle: '${o.driver?.firstName ?? 'The driver'} asked for ${formatMoney(o.amount, currency: ride.currency)}. Offer her a lower price — only she will see it.',
      min: ride.minFare,
      max: (o.amount - 5).clamp(ride.minFare, ride.maxFare).toDouble(),
      initial: (((ride.proposedFare + o.amount) / 2 / 5).round() * 5).clamp(ride.minFare, (o.amount - 5).clamp(ride.minFare, ride.maxFare)).toDouble(),
      suggested: ride.suggestedFare,
      currency: ride.currency,
      confirmLabel: 'Send counter',
    );
    if (amount == null || !mounted) return;
    setState(() => _busyOfferId = o.id);
    try {
      await _repo.counterOffer(o.id, amount);
      if (mounted) showSnack(context, 'Counter-offer sent', success: true);
      await _refreshOffers();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      await _refreshOffers();
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _raiseFare() async {
    final ride = _ride;
    if (ride == null) return;
    final amount = await showFareSheet(
      context,
      title: 'Raise your fare',
      subtitle: 'A higher offer gets noticed by more drivers.',
      min: ride.minFare,
      max: ride.maxFare,
      initial: (ride.proposedFare + 20).clamp(ride.minFare, ride.maxFare).toDouble(),
      suggested: ride.suggestedFare,
      currency: ride.currency,
      confirmLabel: 'Update fare',
    );
    if (amount == null || !mounted) return;
    setState(() => _raising = true);
    try {
      final updated = await _repo.updateFare(_rideId, amount);
      if (mounted) {
        setState(() => _ride = updated.copyWith(driversNotified: updated.driversNotified ?? _ride?.driversNotified));
        showSnack(context, 'Fare updated to ${formatMoney(amount, currency: updated.currency)}', success: true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      await _refresh();
    } finally {
      if (mounted) setState(() => _raising = false);
    }
  }

  Future<void> _cancel() async {
    final reasons = ref.read(appConfigProvider).customerCancelReasons;
    final reason = await showReasonPicker(context, title: 'Cancel ride request?', reasons: reasons, confirmLabel: 'Cancel request');
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _repo.cancelRide(_rideId, reason: reason);
      if (!mounted) return;
      ref.read(sessionProvider.notifier).setActiveRide(null);
      _left = true;
      showSnack(context, 'Ride request cancelled');
      context.go(Routes.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
      await _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Re-creates the request with the same parameters (optionally a new fare).
  Future<void> _retry({bool raise = false}) async {
    final ride = _ride;
    if (ride == null || ride.categoryId == null) return;
    var fare = ride.proposedFare;
    if (raise) {
      final v = await showFareSheet(
        context,
        title: 'Raise fare & retry',
        min: ride.minFare,
        max: ride.maxFare,
        initial: (ride.proposedFare + 30).clamp(ride.minFare, ride.maxFare).toDouble(),
        suggested: ride.suggestedFare,
        currency: ride.currency,
        confirmLabel: 'Search again',
      );
      if (v == null) return;
      fare = v;
    }
    if (!mounted) return;
    setState(() => _retrying = true);
    try {
      final created = await _repo.createRide(
        CreateRideInput(
          categoryId: ride.categoryId!,
          pickup: Place(name: ride.pickup.address ?? 'Pickup', address: ride.pickup.address ?? '', lat: ride.pickup.lat, lng: ride.pickup.lng),
          dropoff: Place(name: ride.dropoff.address ?? 'Drop-off', address: ride.dropoff.address ?? '', lat: ride.dropoff.lat, lng: ride.dropoff.lng),
          proposedFare: fare,
          pickupNote: ride.pickupNote,
          paymentMethod: ride.paymentMethod,
        ),
        idempotencyKey: generateUuidV4(),
      );
      if (!mounted) return;
      ref.read(sessionProvider.notifier).setActiveRide(created.id);
      setState(() {
        _rideId = created.id;
        _ride = created;
        _offers = const [];
        _loading = false;
      });
      _startSync();
      // Keep the URL in sync with the new request.
      context.go(Routes.matching(created.id));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  // ---- UI ------------------------------------------------------------------

  /// "N drivers bidding": every driver with a live bid or a live re-bid from the customer.
  String _offersHeadline() {
    final drivers = _offers.map((o) => o.driver?.id ?? 'offer-${o.id}').toSet().length;
    return '$drivers driver${drivers == 1 ? '' : 's'} bidding';
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(realtimeStatusProvider).value;
    final ride = _ride;
    Widget body;
    if (_loading && ride == null) {
      body = const LoadingView(message: 'Loading your request…');
    } else if (ride == null) {
      body = ErrorState(error: _error ?? 'error', onRetry: _refresh);
    } else if (ride.isAccepted) {
      body = const LoadingView(message: 'Driver assigned! Opening your trip…');
    } else if (ride.status == 'cancelled_by_customer') {
      body = EmptyState(
        icon: Icons.cancel_outlined,
        title: 'Request cancelled',
        message: ride.cancelReason,
        actionLabel: 'Back to home',
        onAction: () => context.go(Routes.home),
      );
    } else if (!ride.isOpen) {
      body = _expired(ride);
    } else {
      body = _searching(ride);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), tooltip: 'Minimise', onPressed: () => context.go(Routes.home)),
          title: Text(ride != null && !ride.isOpen && !ride.isAccepted ? 'Request ended' : 'Finding your driver'),
          actions: [
            if (ride != null && ride.isOpen)
              TextButton(
                onPressed: _cancelling ? null : _cancel,
                child: _cancelling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cancel', style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
        body: Column(children: [
          if (status != null && status != RealtimeStatus.connected && ride != null && ride.isOpen) const OfflineBanner(),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey('${ride?.status}-${_offers.isEmpty}'), child: body))),
        ]),
      ),
    );
  }

  Widget _fareCard(RideRequest ride) {
    return AppCard(
      child: Column(children: [
        RouteSummary(from: ride.pickup.address ?? '', to: ride.dropoff.address ?? '', dense: true),
        const Divider(height: 24),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR OFFER', style: AppText.overline),
            const SizedBox(height: 2),
            Text(formatMoney(ride.proposedFare, currency: ride.currency), style: AppText.h2),
            Text('${ride.categoryName?.replaceFirst('FemaleRider ', '') ?? ''} · Cash', style: AppText.caption),
          ]),
          const Spacer(),
          AppButton(
            label: 'Raise fare',
            icon: Icons.trending_up_rounded,
            expand: false,
            height: 44,
            loading: _raising,
            onPressed: ride.proposedFare >= ride.maxFare ? null : _raiseFare,
          ),
        ]),
      ]),
    );
  }

  Widget _searching(RideRequest ride) {
    final hasOffers = _offers.isNotEmpty;
    final notified = ride.driversNotified ?? 0;
    final header = Column(children: [
      SearchRadar(size: hasOffers ? 110 : 230),
      const SizedBox(height: AppSpace.md),
      Text(
        hasOffers ? _offersHeadline() : 'Looking for drivers near you',
        style: AppText.h2,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        notified > 0 ? '$notified driver${notified == 1 ? '' : 's'} notified${ride.searchRadiusKm != null ? ' within ${ride.searchRadiusKm!.toStringAsFixed(0)} km' : ''}' : 'Notifying nearby drivers…',
        style: AppText.bodySm,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpace.xs),
      CountdownText(
        deadline: ride.expiresAt,
        onExpired: () => Future.delayed(const Duration(seconds: 2), _refresh),
        builder: (_, left) => StatusChip(icon: Icons.timer_outlined, label: 'Request expires in ${formatCountdown(left)}', tone: left.inSeconds < 30 ? StatusTone.danger : StatusTone.neutral),
      ),
    ]);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          header,
          const SizedBox(height: AppSpace.lg),
          if (hasOffers) ...[
            Text('Choose a driver', style: AppText.h3),
            const SizedBox(height: AppSpace.xs),
            for (final o in _offers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: OfferCard(
                  key: ValueKey('offer-${o.id}'),
                  offer: o,
                  currency: ride.currency,
                  busy: _busyOfferId == o.id,
                  onAccept: _busyOfferId == null ? () => _accept(o) : null,
                  onDecline: _busyOfferId == null ? () => _decline(o) : null,
                  onCounter: _busyOfferId == null ? () => _counter(o) : null,
                ),
              ),
            const SizedBox(height: AppSpace.sm),
          ],
          _fareCard(ride),
          const SizedBox(height: AppSpace.md),
          const InfoBanner(
            icon: Icons.shield_outlined,
            tone: StatusTone.brand,
            message: 'All drivers are verified women. You will get a 4-digit PIN to share only once you are in the car.',
          ),
        ],
      ),
    );
  }

  Widget _expired(RideRequest ride) {
    final noDriver = ride.status == 'no_driver_found';
    return ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
      const SizedBox(height: AppSpace.xl),
      const SearchRadar(size: 160, active: false, child: Icon(Icons.search_off_rounded, color: Colors.white, size: 30)),
      const SizedBox(height: AppSpace.lg),
      Text(noDriver ? 'No drivers available' : 'Your request expired', style: AppText.h2, textAlign: TextAlign.center),
      const SizedBox(height: AppSpace.xs),
      Text(
        noDriver ? 'We could not find a driver nearby right now. Try raising your fare or search again in a moment.' : 'No offer was accepted in time. You can search again with the same details.',
        style: AppText.body,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpace.lg),
      _fareCardStatic(ride),
      const SizedBox(height: AppSpace.lg),
      AppButton(label: 'Raise fare & retry', icon: Icons.trending_up_rounded, loading: _retrying, onPressed: ride.categoryId == null || _retrying ? null : () => _retry(raise: true)),
      const SizedBox(height: AppSpace.sm),
      AppButton.secondary(label: 'Try again', onPressed: ride.categoryId == null || _retrying ? null : () => _retry()),
      const SizedBox(height: AppSpace.sm),
      TextButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
    ]);
  }

  Widget _fareCardStatic(RideRequest ride) => AppCard(
        child: Column(children: [
          RouteSummary(from: ride.pickup.address ?? '', to: ride.dropoff.address ?? '', dense: true),
          const Divider(height: 24),
          KeyValueRow('Your offer', formatMoney(ride.proposedFare, currency: ride.currency), bold: true),
          KeyValueRow('Allowed range', '${formatMoney(ride.minFare, currency: ride.currency)} – ${formatMoney(ride.maxFare, currency: ride.currency)}'),
        ]),
      );
}
