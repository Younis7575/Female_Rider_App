import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/driver_tracker.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/realtime/live_sync.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../trips/domain/trip_models.dart';
import '../data/driver_repository.dart';
import '../domain/driver_models.dart';
import 'requests_controller.dart';
import 'widgets/online_toggle.dart';
import 'widgets/request_card.dart';

/// Incoming ride requests and inDrive-style negotiation for drivers.
class DriverRequestsScreen extends ConsumerStatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  ConsumerState<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends ConsumerState<DriverRequestsScreen> {
  StreamSubscription<RealtimeEvent>? _rtSub;
  LiveSync? _sync;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    final rt = ref.read(realtimeServiceProvider);
    _rtSub = rt.sessionEvents.listen(_onEvent);
    _sync = LiveSync(
      service: rt,
      channels: const [],
      onEvent: (_) {},
      refresh: () => ref.read(driverRequestsProvider.notifier).refresh(),
      pollInterval: const Duration(seconds: 5),
    )..start();
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _sync?.dispose();
    super.dispose();
  }

  void _onEvent(RealtimeEvent e) {
    if (!mounted) return;
    final tripId = ref.read(driverRequestsProvider.notifier).applyEvent(e);
    if (tripId != null) _openTrip(tripId);
  }

  void _openTrip(String tripId) {
    ref.read(sessionProvider.notifier).setActiveTrip(tripId);
    ref.read(driverTrackerProvider.notifier).attachTrip(tripId);
    if (mounted) context.go(Routes.driverTrip(tripId));
  }

  DriverRepository get _repo => ref.read(driverRepositoryProvider);
  DriverRequestsController get _ctrl => ref.read(driverRequestsProvider.notifier);

  Future<void> _run(DriverRequest r, Future<void> Function() action) async {
    if (_busy.contains(r.id)) return;
    setState(() => _busy.add(r.id));
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'ride_closed':
        case 'already_assigned':
        case 'not_dispatched':
          _ctrl.remove(r.id);
          showSnack(context, e.message);
        case 'driver_offline':
          showSnack(context, e.message, error: true);
          await ref.read(driverTrackerProvider.notifier).goOnline().then((_) {}, onError: (_) {});
        case 'offer_pending':
        case 'offer_not_pending':
          showSnack(context, e.message);
          await _ctrl.refresh();
        default:
          showSnack(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  void _accept(DriverRequest r) => _run(r, () async {
        final offer = await _repo.makeOffer(r.id);
        _ctrl.patchOffer(offer);
        if (mounted) showSnack(context, 'Offer sent to ${r.customerFirstName}', success: true);
      });

  Future<void> _counter(DriverRequest r) async {
    final amount = await showFareSheet(
      context,
      title: 'Your bid',
      subtitle: '${r.customerFirstName} offered ${_fmt(r, r.proposedFare)}. Bid the same price or higher.',
      min: r.proposedFare,
      max: r.maxFare,
      initial: (r.proposedFare + 50).clamp(r.proposedFare, r.maxFare).toDouble(),
      suggested: r.suggestedFare,
      currency: r.currency,
    );
    if (amount == null) return;
    await _run(r, () async {
      final offer = await _repo.makeOffer(r.id, amount: amount);
      _ctrl.patchOffer(offer);
    });
  }

  void _decline(DriverRequest r) => _run(r, () async {
        await _repo.decline(r.id);
        _ctrl.remove(r.id);
      });

  void _withdraw(DriverRequest r) => _run(r, () async {
        final offer = await _repo.withdraw(r.myOffer!.id);
        _ctrl.patchOffer(offer);
      });

  Future<void> _respond(DriverRequest r, String action) async {
    double? amount;
    if (action == 'counter') {
      amount = await showFareSheet(
        context,
        title: 'Bid again',
        subtitle: '${r.customerFirstName} wants to go for ${_fmt(r, r.myOffer!.amount)}. Bid that price or higher.',
        min: r.myOffer!.amount,
        max: r.maxFare,
        initial: (r.myOffer!.amount + 25).clamp(r.myOffer!.amount, r.maxFare).toDouble(),
        suggested: r.suggestedFare,
        currency: r.currency,
      );
      if (amount == null) return;
    }
    await _run(r, () async {
      final res = await _repo.respondToCounter(r.myOffer!.id, action: action, amount: amount);
      final Trip? trip = res.trip;
      if (trip != null) {
        _ctrl.remove(r.id);
        _openTrip(trip.id);
        return;
      }
      if (res.offer != null) _ctrl.patchOffer(res.offer!);
      if (action == 'reject') await _ctrl.refresh();
      if (mounted && res.message != null) showSnack(context, res.message!);
    });
  }

  String _fmt(DriverRequest r, double v) => formatMoney(v, currency: r.currency);

  @override
  Widget build(BuildContext context) {
    final tracker = ref.watch(driverTrackerProvider);
    final reqs = ref.watch(driverRequestsProvider);
    final rt = ref.watch(realtimeStatusProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Ride requests', style: AppText.h3.copyWith(color: Colors.white)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: () => _ctrl.refresh(), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(children: [
        Container(
          color: AppColors.night,
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
          child: const DriverOnlineToggle(),
        ),
        if (rt != null && rt != RealtimeStatus.connected && tracker.online) const OfflineBanner(),
        Expanded(
          child: !tracker.online
              ? const EmptyState(
                  icon: Icons.power_settings_new_rounded,
                  title: 'You\'re offline',
                  message: 'Go online using the switch above to start receiving ride requests from nearby passengers.',
                )
              : RefreshIndicator(
                  color: AppColors.crimson,
                  onRefresh: () => _ctrl.refresh(),
                  child: AsyncView<List<DriverRequest>>(
                    value: reqs,
                    onRetry: () => ref.invalidate(driverRequestsProvider),
                    data: (list) {
                      if (list.isEmpty) {
                        return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                          SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.radar_rounded,
                            title: 'Waiting for requests',
                            message: 'Stay in a busy area. New requests near you will appear here instantly.',
                          ),
                        ]);
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpace.md),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
                        itemBuilder: (_, i) {
                          final r = list[i];
                          return RequestCard(
                            key: ValueKey(r.id),
                            request: r,
                            busy: _busy.contains(r.id),
                            onAccept: () => _accept(r),
                            onCounter: () => _counter(r),
                            onDecline: () => _decline(r),
                            onWithdraw: () => _withdraw(r),
                            onAcceptCounter: () => _respond(r, 'accept'),
                            onRejectCounter: () => _respond(r, 'reject'),
                            onCounterCounter: () => _respond(r, 'counter'),
                            onExpired: () => _ctrl.remove(r.id),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
