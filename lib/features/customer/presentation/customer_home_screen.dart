import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/app_map.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/polyline.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/presentation/app_drawer.dart';
import '../../auth/presentation/session_controller.dart';
import '../../rides/data/ride_repository.dart';
import '../../rides/domain/ride_models.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/presentation/widgets/trip_widgets.dart';
import 'customer_providers.dart';
import 'place_search_page.dart';

enum _Stage { idle, pinPickup, estimate }

/// Customer home: map, pickup/destination selection, fare estimate and ride request.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _map = AppMapController();
  final _note = TextEditingController();
  final _couponCtrl = TextEditingController();

  _Stage _stage = _Stage.idle;
  Place? _pickup;
  Place? _dropoff;
  bool _locating = true;
  bool _geocoding = false;
  bool _mapMoving = false;
  GeoPoint? _myLocation;

  FareEstimate? _estimate;
  bool _estimating = false;
  Object? _estimateError;
  int? _categoryId;
  double _fare = 0;

  CouponValidation? _coupon;
  bool _validatingCoupon = false;
  bool _showExtras = false;

  bool _requesting = false;
  String? _requestKey;
  int _geoSeq = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _note.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  // ---- Location / pickup -------------------------------------------------

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    final fix = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null) {
      showSnack(context, 'Location unavailable. Search for your pickup point instead.');
      return;
    }
    _myLocation = fix.point;
    await _map.moveTo(fix.point);
    // The map may still be initialising; retry the camera move shortly after.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _stage == _Stage.idle) _map.moveTo(_pickup?.point ?? fix.point);
    });
    if (_pickup == null) await _setPickupFrom(fix.point, fallbackName: 'Current location');
  }

  Future<void> _setPickupFrom(GeoPoint p, {String fallbackName = 'Pinned location'}) async {
    final seq = ++_geoSeq;
    setState(() {
      _geocoding = true;
      _pickup = Place(name: fallbackName, address: '', lat: p.lat, lng: p.lng);
    });
    String? address;
    try {
      address = await ref.read(rideRepositoryProvider).reverseGeocode(p.lat, p.lng);
    } catch (_) {}
    if (!mounted || seq != _geoSeq) return;
    final name = (address == null || address.isEmpty) ? fallbackName : address.split(',').first;
    setState(() {
      _geocoding = false;
      _pickup = Place(name: name, address: address ?? '', lat: p.lat, lng: p.lng);
    });
    if (_dropoff != null && _stage == _Stage.estimate) _fetchEstimate();
  }

  Future<void> _choosePickup() async {
    final mapsOk = ref.read(mapsConfiguredProvider).value ?? false;
    final r = await openPlaceSearch(context, mode: PlaceSearchMode.pickup, lat: _myLocation?.lat, lng: _myLocation?.lng, allowSetOnMap: mapsOk);
    if (r == null || !mounted) return;
    if (r.useCurrentLocation) {
      final fix = await ref.read(locationServiceProvider).current();
      if (fix == null) {
        if (mounted) showSnack(context, 'We could not get your location. Check location permissions.', error: true);
        return;
      }
      _myLocation = fix.point;
      await _map.moveTo(fix.point);
      await _setPickupFrom(fix.point, fallbackName: 'Current location');
    } else if (r.setOnMap) {
      setState(() => _stage = _Stage.pinPickup);
      if (_pickup != null) await _map.moveTo(_pickup!.point, zoom: 17);
    } else if (r.place != null) {
      setState(() => _pickup = r.place);
      await _map.moveTo(r.place!.point);
      if (_dropoff != null) _goEstimate();
    }
  }

  Future<void> _chooseDestination({String? initial}) async {
    final r = await openPlaceSearch(context, mode: PlaceSearchMode.destination, lat: _pickup?.lat ?? _myLocation?.lat, lng: _pickup?.lng ?? _myLocation?.lng, initialQuery: initial);
    if (r?.place == null || !mounted) return;
    setState(() => _dropoff = r!.place);
    _goEstimate();
  }

  void _onCameraIdle(GeoPoint center) {
    if (_stage != _Stage.pinPickup) return;
    setState(() => _mapMoving = false);
    _setPickupFrom(center);
  }

  // ---- Estimate ------------------------------------------------------------

  void _goEstimate() {
    if (_pickup == null) {
      showSnack(context, 'Set your pickup point first.');
      return;
    }
    if (_dropoff == null) return;
    setState(() => _stage = _Stage.estimate);
    _fetchEstimate();
  }

  Future<void> _fetchEstimate() async {
    final p = _pickup, d = _dropoff;
    if (p == null || d == null) return;
    setState(() {
      _estimating = true;
      _estimateError = null;
      _requestKey = null;
    });
    try {
      final est = await ref.read(rideRepositoryProvider).estimate(p, d);
      if (!mounted) return;
      final keep = est.options.where((o) => o.category.id == _categoryId).firstOrNull;
      final opt = keep ?? (est.options.isNotEmpty ? est.options.first : null);
      setState(() {
        _estimate = est;
        _estimating = false;
        _categoryId = opt?.category.id;
        _fare = opt == null ? 0 : clampFare(opt.suggestedFare, opt.minFare, opt.maxFare);
        _coupon = null;
      });
      await _map.fit(routePoints(est.polyline, p.point, d.point), padding: 70);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estimating = false;
        _estimateError = e;
      });
    }
  }

  FareOption? get _option => _estimate?.options.where((o) => o.category.id == _categoryId).firstOrNull;

  void _selectCategory(FareOption o) {
    setState(() {
      _categoryId = o.category.id;
      _fare = clampFare(o.suggestedFare, o.minFare, o.maxFare);
      _coupon = null;
      _requestKey = null;
    });
  }

  void _clearDestination() {
    setState(() {
      _dropoff = null;
      _estimate = null;
      _estimateError = null;
      _coupon = null;
      _stage = _Stage.idle;
      _requestKey = null;
    });
    if (_pickup != null) _map.moveTo(_pickup!.point);
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty || _option == null) return;
    setState(() => _validatingCoupon = true);
    try {
      final v = await ref.read(rideRepositoryProvider).validateCoupon(code: code, fare: _fare, categoryId: _categoryId);
      if (!mounted) return;
      setState(() {
        _coupon = v;
        _requestKey = null;
      });
      showSnack(context, 'Coupon applied: ${formatMoney(v.discount, currency: _option!.currency)} off', success: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  // ---- Request -------------------------------------------------------------

  Future<void> _request() async {
    final opt = _option;
    if (opt == null || _pickup == null || _dropoff == null || _requesting) return;
    _requestKey ??= generateUuidV4();
    setState(() => _requesting = true);
    try {
      final ride = await ref.read(rideRepositoryProvider).createRide(
            CreateRideInput(
              categoryId: opt.category.id,
              pickup: _pickup!,
              dropoff: _dropoff!,
              proposedFare: _fare,
              pickupNote: _note.text,
              couponCode: _coupon?.code,
            ),
            idempotencyKey: _requestKey!,
          );
      if (!mounted) return;
      _requestKey = null;
      ref.read(sessionProvider.notifier).setActiveRide(ride.id);
      context.go(Routes.matching(ride.id));
    } on ApiException catch (e) {
      if (!e.isNetwork) _requestKey = null; // keep the key only for a retry of the same attempt
      if (!mounted) return;
      await _handleRequestError(e);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _handleRequestError(ApiException e) async {
    switch (e.code) {
      case 'fare_out_of_bounds':
        final b = e.fareBounds;
        if (b != null) setState(() => _fare = clampFare(_fare, b.min, b.max));
        showSnack(context, e.message, error: true);
      case 'active_trip_exists':
        final go = await showConfirmDialog(context, title: 'You have an active trip', message: e.message, confirmLabel: 'Open trip');
        if (go && mounted) {
          final trip = await runGuarded(context, () => ref.read(tripRepositoryProvider).activeTrip());
          if (trip != null && mounted) {
            ref.read(sessionProvider.notifier).setActiveTrip(trip.id);
            context.go(Routes.trip(trip.id));
          }
        }
      case 'open_request_exists':
        final go = await showConfirmDialog(context, title: 'Request already open', message: e.message, confirmLabel: 'View request');
        if (go && mounted) {
          final ride = await runGuarded(context, () => ref.read(rideRepositoryProvider).activeRide());
          if (ride != null && mounted) {
            ref.read(sessionProvider.notifier).setActiveRide(ride.id);
            context.go(Routes.matching(ride.id));
          }
        }
      case 'wrong_mode':
      case 'customer_not_eligible':
        showSnack(context, e.message, error: true);
        unawaited(ref.read(sessionProvider.notifier).refreshMe());
      default:
        showSnack(context, e.message, error: true);
    }
  }

  // ---- UI ------------------------------------------------------------------

  List<MapMarker> get _markers => [
        if (_pickup != null && _stage != _Stage.pinPickup) MapMarker(id: 'pickup', point: _pickup!.point, kind: MapMarkerKind.pickup, title: 'Pickup'),
        if (_dropoff != null && _stage == _Stage.estimate) MapMarker(id: 'dropoff', point: _dropoff!.point, kind: MapMarkerKind.dropoff, title: 'Drop-off'),
      ];

  List<GeoPoint> get _route =>
      _stage == _Stage.estimate && _pickup != null && _dropoff != null ? routePoints(_estimate?.polyline, _pickup!.point, _dropoff!.point) : const [];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sheetFraction = switch (_stage) {
      _Stage.idle => 0.42,
      _Stage.pinPickup => 0.26,
      _Stage.estimate => 0.62,
    };
    final mapBottomPad = size.height * sheetFraction;

    return PopScope(
      canPop: _stage == _Stage.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stage == _Stage.pinPickup) {
          setState(() => _stage = _dropoff != null ? _Stage.estimate : _Stage.idle);
        } else {
          _clearDestination();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        body: Stack(children: [
          Positioned.fill(
            child: AppMap(
              initialTarget: _pickup?.point ?? kDefaultMapCenter,
              controller: _map,
              markers: _markers,
              route: _route,
              padding: EdgeInsets.only(bottom: mapBottomPad, top: 90),
              onCameraMoveStarted: () {
                if (_stage == _Stage.pinPickup) setState(() => _mapMoving = true);
              },
              onCameraIdle: _onCameraIdle,
            ),
          ),
          if (_stage == _Stage.pinPickup)
            Positioned(
              left: 0,
              right: 0,
              top: 90 + (size.height - mapBottomPad - 90) / 2 - 76,
              child: Center(child: CenterPin(label: _geocoding ? 'Finding address…' : 'Pickup here', lifted: _mapMoving)),
            ),
          _topBar(),
          if (_stage != _Stage.pinPickup)
            Positioned(
              right: AppSpace.md,
              bottom: mapBottomPad + AppSpace.sm,
              child: CircleIconButton(
                icon: Icons.my_location_rounded,
                tooltip: 'My location',
                onPressed: () async {
                  final fix = await ref.read(locationServiceProvider).current();
                  if (fix != null) {
                    _myLocation = fix.point;
                    await _map.moveTo(fix.point);
                  }
                },
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_stage),
                child: switch (_stage) {
                  _Stage.idle => _idlePanel(size.height * 0.85),
                  _Stage.pinPickup => _pinPanel(),
                  _Stage.estimate => _estimatePanel(size.height * 0.72),
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, 0),
          child: Row(children: [
            _stage == _Stage.idle
                ? CircleIconButton(icon: Icons.menu_rounded, tooltip: 'Menu', onPressed: () => _scaffoldKey.currentState?.openDrawer())
                : CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () {
                      if (_stage == _Stage.pinPickup) {
                        setState(() => _stage = _dropoff != null ? _Stage.estimate : _Stage.idle);
                      } else {
                        _clearDestination();
                      }
                    },
                  ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill), boxShadow: AppShadows.card),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text('FemaleRider', style: AppText.title.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ),
            const Spacer(),
            Container(
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: AppShadows.card),
              child: const NotificationBell(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sheet({required Widget child, double? maxHeight}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
      decoration: const BoxDecoration(borderRadius: AppRadius.sheet, boxShadow: AppShadows.floating),
      // Material (not a coloured DecoratedBox) so ListTile ink/splashes render correctly.
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.sheet,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(top: false, child: child),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _idlePanel(double maxHeight) {
    final session = ref.watch(sessionProvider);
    final me = session is SessionSignedIn ? session.me : null;
    final saved = ref.watch(savedPlacesProvider);
    final recent = ref.watch(recentPlacesProvider);
    return _sheet(
      maxHeight: maxHeight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          if (me?.activeTripId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: InfoBanner(
                tone: StatusTone.brand,
                icon: Icons.directions_car_filled_rounded,
                title: 'You have an active trip',
                message: 'Your driver is assigned. Open the trip to see live progress and your PIN.',
                action: 'Resume trip',
                onAction: () => context.go(Routes.trip(me!.activeTripId!)),
              ),
            )
          else if (me?.activeRideId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: InfoBanner(
                tone: StatusTone.warning,
                icon: Icons.radar_rounded,
                title: 'Your ride request is open',
                message: 'Drivers are reviewing your request. Check incoming offers.',
                action: 'View offers',
                onAction: () => context.go(Routes.matching(me!.activeRideId!)),
              ),
            ),
          Text(greeting(me?.user.name), style: AppText.h2),
          const SizedBox(height: AppSpace.sm),
          _pickupRow(),
          const SizedBox(height: AppSpace.xs),
          Material(
            color: AppColors.field,
            borderRadius: AppRadius.input,
            child: InkWell(
              key: const ValueKey('where-to'),
              borderRadius: AppRadius.input,
              onTap: () => _chooseDestination(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 16),
                child: Row(children: [
                  const Icon(Icons.search_rounded, color: AppColors.crimson),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text('Where to?', style: AppText.h3.copyWith(color: AppColors.inkSoft))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text('Now', style: AppText.label),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          saved.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpace.xs),
                      itemBuilder: (_, i) {
                        final s = list[i];
                        return ActionChip(
                          avatar: Icon(s.label == 'home' ? Icons.home_rounded : (s.label == 'work' ? Icons.work_rounded : Icons.bookmark_rounded), size: 18, color: AppColors.crimson),
                          label: Text(s.label == 'other' ? s.name : (s.label == 'home' ? 'Home' : 'Work')),
                          onPressed: () {
                            setState(() => _dropoff = s.place);
                            _goEstimate();
                          },
                        );
                      },
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          recent.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: AppSpace.sm), child: Skeleton(height: 44)),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => Column(children: [
              for (final p in list.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle),
                    child: const Icon(Icons.history_rounded, color: AppColors.inkSoft, size: 20),
                  ),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    setState(() => _dropoff = p);
                    _goEstimate();
                  },
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Expanded(child: Text('Verified women drivers · Trip PIN · In-app SOS', style: AppText.caption)),
          ]),
        ]),
      ),
    );
  }

  Widget _pickupRow() {
    return InkWell(
      borderRadius: AppRadius.input,
      onTap: _choosePickup,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 3))),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PICKUP', style: AppText.overline),
              const SizedBox(height: 2),
              _locating && _pickup == null
                  ? const Skeleton(width: 180, height: 14)
                  : Text(
                      _pickup == null ? 'Set pickup location' : (_pickup!.address.isNotEmpty ? _pickup!.address : _pickup!.name),
                      style: AppText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ]),
          ),
          if (_geocoding) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.edit_location_alt_outlined, color: AppColors.muted, size: 20),
        ]),
      ),
    );
  }

  Widget _pinPanel() {
    return _sheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _handle(),
          Text('Set your pickup spot', style: AppText.h3),
          const SizedBox(height: 4),
          Text('Drag the map to place the pin exactly where your driver should meet you.', style: AppText.bodySm),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            const Icon(Icons.place_rounded, color: AppColors.crimson),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: _geocoding
                  ? const Skeleton(height: 14)
                  : Text(_pickup?.address.isNotEmpty == true ? _pickup!.address : (_pickup?.name ?? 'Move the map'), style: AppText.title, maxLines: 2),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: 'Confirm pickup',
            onPressed: _geocoding || _pickup == null
                ? null
                : () {
                    if (_dropoff != null) {
                      _goEstimate();
                    } else {
                      setState(() => _stage = _Stage.idle);
                    }
                  },
          ),
        ]),
      ),
    );
  }

  Widget _estimatePanel(double maxHeight) {
    final est = _estimate;
    final opt = _option;
    return _sheet(
      maxHeight: maxHeight,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () => _chooseDestination(initial: _dropoff?.name),
                child: RouteSummary(from: _pickup?.address.isNotEmpty == true ? _pickup!.address : (_pickup?.name ?? ''), to: _dropoff?.address.isNotEmpty == true ? _dropoff!.address : (_dropoff?.name ?? '')),
              ),
              if (est != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text('${formatDistance(est.distanceM)} · about ${formatDuration(est.durationS)}${est.city != null ? ' · ${est.city}' : ''}', style: AppText.caption),
              ],
              const SizedBox(height: AppSpace.md),
              if (_estimating && est != null)
                const Padding(padding: EdgeInsets.only(bottom: AppSpace.xs), child: LinearProgressIndicator(minHeight: 2)),
              if (_estimating && est == null)
                const Column(children: [Skeleton(height: 72, radius: 16), SizedBox(height: 8), Skeleton(height: 72, radius: 16)])
              else if (_estimateError != null)
                InfoBanner(
                  tone: StatusTone.danger,
                  icon: Icons.wrong_location_outlined,
                  title: (_estimateError is ApiException && (_estimateError as ApiException).code == 'outside_service_area') ? 'Outside service area' : 'Could not get fares',
                  message: errorMessage(_estimateError!),
                  action: 'Try again',
                  onAction: _fetchEstimate,
                )
              else if (est != null) ...[
                if (est.options.isEmpty)
                  const InfoBanner(tone: StatusTone.warning, message: 'No vehicle types are available for this route right now.')
                else
                  for (final o in est.options) _CategoryCard(option: o, selected: o.category.id == _categoryId, durationS: est.durationS, onTap: () => _selectCategory(o)),
                if (opt != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text('YOUR OFFER', style: AppText.overline),
                  const SizedBox(height: AppSpace.xs),
                  FareStepper(
                    min: opt.minFare,
                    max: opt.maxFare,
                    value: _fare,
                    suggested: opt.suggestedFare,
                    currency: opt.currency,
                    onChanged: (v) => setState(() {
                      _fare = v;
                      _requestKey = null;
                    }),
                  ),
                  if (opt.surgeMultiplier > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xs),
                      child: InfoBanner(tone: StatusTone.warning, icon: Icons.trending_up_rounded, message: 'High demand right now (×${opt.surgeMultiplier.toStringAsFixed(1)}). Fares are a little higher than usual.'),
                    ),
                  const SizedBox(height: AppSpace.sm),
                  _extras(opt),
                ],
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.sm),
          child: AppButton(
            key: const ValueKey('request-ride'),
            label: opt == null ? 'Request ride' : 'Request ${opt.category.name.replaceFirst('FemaleRider ', '')} · ${formatMoney(_fare, currency: opt.currency)}',
            loading: _requesting,
            onPressed: opt == null || _estimating ? null : _request,
          ),
        ),
      ]),
    );
  }

  Widget _extras(FareOption opt) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: _ExtraTile(
            icon: Icons.payments_outlined,
            title: 'Cash',
            subtitle: 'Pay your driver',
            onTap: () => showSnack(context, 'Cash is the only payment method available right now.'),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _ExtraTile(
            icon: Icons.local_offer_outlined,
            title: _coupon != null ? _coupon!.code : 'Coupon',
            subtitle: _coupon != null ? '−${formatMoney(_coupon!.discount, currency: opt.currency)} est.' : 'Add code',
            highlight: _coupon != null,
            onTap: () => setState(() => _showExtras = !_showExtras),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _ExtraTile(
            icon: Icons.sticky_note_2_outlined,
            title: 'Note',
            subtitle: _note.text.trim().isEmpty ? 'For driver' : 'Added',
            highlight: _note.text.trim().isNotEmpty,
            onTap: () => setState(() => _showExtras = !_showExtras),
          ),
        ),
      ]),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: !_showExtras
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _couponCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Coupon code',
                          prefixIcon: const Icon(Icons.local_offer_outlined),
                          suffixIcon: _coupon != null
                              ? IconButton(
                                  tooltip: 'Remove coupon',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() {
                                    _coupon = null;
                                    _couponCtrl.clear();
                                    _requestKey = null;
                                  }),
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _applyCoupon(),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    AppButton(label: 'Apply', expand: false, height: 52, loading: _validatingCoupon, variant: AppButtonVariant.dark, onPressed: _applyCoupon),
                  ]),
                  if (_coupon?.description != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerLeft, child: Text(_coupon!.description!, style: AppText.caption))),
                  const SizedBox(height: AppSpace.sm),
                  TextField(
                    controller: _note,
                    maxLength: 255,
                    maxLines: 2,
                    minLines: 1,
                    onChanged: (_) => setState(() => _requestKey = null),
                    decoration: const InputDecoration(hintText: 'Pickup note (e.g. gate 2, blue door)', prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                  ),
                ]),
              ),
      ),
    ]);
  }
}

class _ExtraTile extends StatelessWidget {
  const _ExtraTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.highlight = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.roseSoft : AppColors.field,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 18, color: highlight ? AppColors.crimson : AppColors.inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.label.copyWith(color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.option, required this.selected, required this.durationS, required this.onTap});
  final FareOption option;
  final bool selected;
  final int durationS;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = option.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.roseSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.crimson : AppColors.line, width: selected ? 1.8 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: selected ? AppColors.surface : AppColors.field, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(vehicleIcon(c.icon ?? c.slug), color: selected ? AppColors.crimson : AppColors.inkSoft, size: 28),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(c.name.replaceFirst('FemaleRider ', ''), style: AppText.title, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      const Icon(Icons.person_rounded, size: 14, color: AppColors.muted),
                      Text('${c.capacity}', style: AppText.caption),
                    ]),
                    const SizedBox(height: 2),
                    Text(c.description ?? formatDuration(durationS), style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(formatMoney(option.suggestedFare, currency: option.currency), style: AppText.h3),
                  Text('${formatMoney(option.minFare, showCurrency: false)}–${formatMoney(option.maxFare, showCurrency: false)}', style: AppText.caption),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
