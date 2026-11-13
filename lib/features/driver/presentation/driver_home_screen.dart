import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/app_map.dart';
import '../../../core/location/driver_tracker.dart';
import '../../../core/network/json.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/presentation/app_drawer.dart';
import '../../account/presentation/mode_switcher.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/driver_models.dart';
import 'driver_providers.dart';
import 'requests_controller.dart';
import 'widgets/online_toggle.dart';

/// Driver dashboard: availability, live position, earnings snapshot and alerts.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _map = AppMapController();
  StreamSubscription<RealtimeEvent>? _rtSub;
  bool _synced = false;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _rtSub = ref.read(realtimeServiceProvider).sessionEvents.listen(_onEvent);
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent e) {
    if (!mounted) return;
    switch (e.event) {
      case RtEvents.rideRequested:
      case RtEvents.rideClosed:
      case RtEvents.rideCancelled:
      case RtEvents.rideExpired:
        if (ref.read(driverTrackerProvider).online) ref.invalidate(driverRequestsProvider);
      case RtEvents.offerAccepted:
        final tripId = asStringOrNull(e.data['trip_id']);
        if (tripId != null) {
          ref.read(sessionProvider.notifier).setActiveTrip(tripId);
          ref.read(driverTrackerProvider.notifier).attachTrip(tripId);
          context.go(Routes.driverTrip(tripId));
        }
      case RtEvents.tripUpdated:
        ref.invalidate(driverDashboardProvider);
    }
  }

  void _sync(DriverDashboard d) {
    if (_synced) return;
    _synced = true;
    final me = ref.read(sessionProvider.notifier).me;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(driverTrackerProvider.notifier).syncFromServer(online: d.isOnline, activeTripId: me?.activeTripId);
    });
  }

  Future<void> _refresh() async {
    _synced = false;
    ref.invalidate(driverDashboardProvider);
    await ref.read(sessionProvider.notifier).refreshMe();
    try {
      await ref.read(driverDashboardProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(driverDashboardProvider);
    final tracker = ref.watch(driverTrackerProvider);
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);
    final activeTripId = session is SessionSignedIn ? session.me.activeTripId : null;
    final rt = ref.watch(realtimeStatusProvider).value;

    ref.listen<DriverTrackerState>(driverTrackerProvider, (prev, next) {
      final fix = next.lastFix;
      if (fix != null && !_centered) {
        _centered = true;
        _map.moveTo(fix.point);
      }
      if (prev?.online == false && next.online) ref.invalidate(driverDashboardProvider);
    });

    dash.whenData(_sync);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                driver: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Menu',
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    const ModeBadge(onDark: true),
                    const Spacer(),
                    const NotificationBell(onDark: true),
                  ]),
                  const SizedBox(height: AppSpace.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('DRIVER MODE', style: AppText.overline.copyWith(color: AppColors.roseAccent)),
                      const SizedBox(height: 4),
                      Text(greeting(user?.name), style: AppText.h2.copyWith(color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.md),
                  const DriverOnlineToggle(),
                ]),
              ),
            ),
            if (rt != null && rt != RealtimeStatus.connected && tracker.online)
              const SliverToBoxAdapter(child: OfflineBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xxl),
              sliver: SliverList.list(children: [
                if (activeTripId != null) ...[
                  _ActiveTripBanner(onTap: () => context.go(Routes.driverTrip(activeTripId))),
                  const SizedBox(height: AppSpace.sm),
                ],
                _MapCard(controller: _map, tracker: tracker),
                const SizedBox(height: AppSpace.sm),
                if (tracker.online) ...[
                  const _RequestsPreview(),
                  const SizedBox(height: AppSpace.sm),
                ],
                AsyncView<DriverDashboard>(
                  value: dash,
                  onRetry: () => ref.invalidate(driverDashboardProvider),
                  loading: const _DashboardSkeleton(),
                  data: (d) => _DashboardBody(d: d),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripBanner extends StatelessWidget {
  const _ActiveTripBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.crimson,
      border: false,
      shadow: true,
      child: Row(children: [
        const Icon(Icons.navigation_rounded, color: Colors.white),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Trip in progress', style: AppText.title.copyWith(color: Colors.white)),
            Text('Tap to continue your active trip', style: AppText.bodySm.copyWith(color: Colors.white70)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.white),
      ]),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.controller, required this.tracker});
  final AppMapController controller;
  final DriverTrackerState tracker;

  @override
  Widget build(BuildContext context) {
    final fix = tracker.lastFix;
    return ClipRRect(
      borderRadius: AppRadius.card,
      child: SizedBox(
        height: 210,
        child: Stack(children: [
          Positioned.fill(
            child: AppMap(
              controller: controller,
              dark: true,
              initialTarget: fix?.point ?? kDefaultMapCenter,
              zoom: 15,
              myLocationEnabled: false,
              markers: [if (fix != null) MapMarker(id: 'me', point: fix.point, kind: MapMarkerKind.driver, rotation: fix.heading ?? 0)],
              placeholderLabel: fix == null ? 'Waiting for your location' : 'Your position: ${fix.lat.toStringAsFixed(4)}, ${fix.lng.toStringAsFixed(4)}',
            ),
          ),
          Positioned(
            left: AppSpace.sm,
            bottom: AppSpace.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.night.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: tracker.tracking ? AppColors.success : AppColors.subtle),
                ),
                const SizedBox(width: 6),
                Text(
                  tracker.tracking
                      ? (tracker.lastSentAt != null ? 'Sharing location · ${formatTime(tracker.lastSentAt)}' : 'Sharing location')
                      : 'Location sharing paused',
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ]),
            ),
          ),
          if (fix != null)
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              child: CircleIconButton(icon: Icons.my_location_rounded, size: 40, tooltip: 'Recenter', onPressed: () => controller.moveTo(fix.point)),
            ),
        ]),
      ),
    );
  }
}

class _RequestsPreview extends ConsumerWidget {
  const _RequestsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(driverRequestsProvider);
    final count = reqs.value?.length ?? 0;
    final counters = reqs.value?.where((r) => r.hasCustomerCounter).length ?? 0;
    return AppCard(
      onTap: () => context.push(Routes.driverRequests),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: AppColors.roseSoft, shape: BoxShape.circle),
          child: reqs.isLoading && !reqs.hasValue
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
              : Center(child: Text('$count', style: AppText.h3.copyWith(color: AppColors.crimson))),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(count == 1 ? '1 ride request nearby' : '$count ride requests nearby', style: AppText.title),
            Text(
              counters > 0 ? '$counters customer counter-offer${counters == 1 ? '' : 's'} waiting' : (count == 0 ? 'New requests appear here instantly' : 'Tap to view and make offers'),
              style: AppText.bodySm.copyWith(color: counters > 0 ? AppColors.crimson : AppColors.muted),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.d});
  final DriverDashboard d;

  @override
  Widget build(BuildContext context) {
    String money(num v) => formatMoney(v, currency: d.currency);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.complianceIssues.isNotEmpty) ...[
        InfoBanner(
          tone: StatusTone.danger,
          icon: Icons.gpp_maybe_rounded,
          title: 'Action needed before you can drive',
          message: d.complianceIssues.join('\n'),
          action: 'Review documents',
          onAction: () => context.push(Routes.driverDocuments),
        ),
        const SizedBox(height: AppSpace.sm),
      ],
      if (d.expiringDocuments.isNotEmpty) ...[
        InfoBanner(
          tone: StatusTone.warning,
          icon: Icons.event_busy_rounded,
          title: 'Documents expiring soon',
          message: d.expiringDocuments.map((e) => '${e.label} · ${formatDate(DateTime.tryParse(e.expiryDate))}').join('\n'),
          action: 'Update documents',
          onAction: () => context.push(Routes.driverDocuments),
        ),
        const SizedBox(height: AppSpace.sm),
      ],
      // Earnings hero
      Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(gradient: AppColors.driverGradient, borderRadius: AppRadius.card, boxShadow: AppShadows.card),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('TODAY\'S EARNINGS', style: AppText.overline.copyWith(color: Colors.white60)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push(Routes.driverEarnings),
              child: Text('Details', style: AppText.label.copyWith(color: AppColors.roseAccent)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(money(d.today.netEarnings), style: AppText.money.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            _MiniStat(label: 'Trips', value: '${d.today.completedTrips}'),
            _MiniStat(label: 'Cancelled', value: '${d.today.cancelledTrips}'),
            _MiniStat(label: 'Online', value: '${d.today.onlineHours.toStringAsFixed(1)} h'),
            _MiniStat(label: 'Cash', value: money(d.today.cashCollected)),
          ]),
        ]),
      ),
      const SizedBox(height: AppSpace.sm),
      Row(children: [
        Expanded(
          child: _StatTile(
            icon: Icons.calendar_view_week_rounded,
            label: 'This week',
            value: money(d.week.netEarnings),
            sub: '${d.week.completedTrips} trips · ${d.week.onlineHours.toStringAsFixed(1)} h',
            onTap: () => context.push(Routes.driverEarnings),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF5A623),
            label: 'Rating',
            value: formatRating(d.rating),
            sub: '${d.totalCompletedTrips} completed trips',
          ),
        ),
      ]),
      const SizedBox(height: AppSpace.sm),
      AppCard(
        onTap: () => context.push(Routes.driverPayouts),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Available for payout', style: AppText.bodySm),
              Text(money(d.availableForPayout), style: AppText.h3),
              Text('Balance ${money(d.balance)}', style: AppText.caption),
            ]),
          ),
          Text('Withdraw', style: AppText.label.copyWith(color: AppColors.crimson)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.crimson),
        ]),
      ),
      const SectionHeader('Quick actions', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
      // Fixed-size tiles (max 120 pt wide) so tablets show more columns instead of giant tiles.
      GridView.extent(
        maxCrossAxisExtent: 120,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpace.xs,
        crossAxisSpacing: AppSpace.xs,
        childAspectRatio: 0.9,
        children: [
          _Quick(icon: Icons.notifications_active_outlined, label: 'Requests', onTap: () => context.push(Routes.driverRequests)),
          _Quick(icon: Icons.bar_chart_rounded, label: 'Earnings', onTap: () => context.push(Routes.driverEarnings)),
          _Quick(icon: Icons.history_rounded, label: 'History', onTap: () => context.push(Routes.history(as: 'driver'))),
          _Quick(icon: Icons.folder_open_rounded, label: 'Documents', onTap: () => context.push(Routes.driverDocuments)),
          _Quick(icon: Icons.receipt_long_outlined, label: 'Ledger', onTap: () => context.push(Routes.driverLedger)),
          _Quick(icon: Icons.summarize_outlined, label: 'Statements', onTap: () => context.push(Routes.driverStatements)),
          _Quick(icon: Icons.support_agent_rounded, label: 'Support', onTap: () => context.push(Routes.support)),
          _Quick(icon: Icons.shield_outlined, label: 'Safety', onTap: () => context.push(Routes.safetyReportBase)),
        ],
      ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppText.title.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: AppText.caption.copyWith(color: Colors.white54)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.sub, this.onTap, this.iconColor});
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.crimson),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption),
        ]),
        const SizedBox(height: AppSpace.xs),
        Text(value, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(sub, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm, horizontal: 4),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.night),
        const SizedBox(height: 6),
        Text(label, style: AppText.caption.copyWith(color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Skeleton(height: 130, radius: 20),
      SizedBox(height: AppSpace.sm),
      Row(children: [
        Expanded(child: Skeleton(height: 96, radius: 20)),
        SizedBox(width: AppSpace.sm),
        Expanded(child: Skeleton(height: 96, radius: 20)),
      ]),
      SizedBox(height: AppSpace.sm),
      Skeleton(height: 76, radius: 20),
    ]);
  }
}
