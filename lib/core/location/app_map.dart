import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../theme/app_theme.dart';
import '../utils/polyline.dart';
import 'location_service.dart';

const _platform = MethodChannel('com.gopangitsolution.femalerider/platform');

/// Which map engine renders [AppMap].
enum MapEngine { openStreetMap, google }

/// Whether a Google Maps API key is configured natively (Android manifest / iOS Info.plist).
final googleMapsKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  try {
    return await _platform.invokeMethod<bool>('isMapsConfigured') ?? false;
  } catch (_) {
    return false;
  }
});

/// Google Maps only when `--dart-define=GOOGLE_MAPS_ENABLED=true` AND a native key exists
/// (so a missing key can never crash iOS); otherwise OpenStreetMap via flutter_map.
final mapEngineProvider = FutureProvider<MapEngine>((ref) async {
  if (!Env.googleMapsEnabled) return MapEngine.openStreetMap;
  final hasKey = await ref.watch(googleMapsKeyConfiguredProvider.future);
  return hasKey ? MapEngine.google : MapEngine.openStreetMap;
});

/// True when an interactive map is available (always, thanks to the OSM fallback).
/// Kept for screens that enable "drag the map to set pickup".
final mapsConfiguredProvider = FutureProvider<bool>((ref) async {
  await ref.watch(mapEngineProvider.future);
  return true;
});

enum MapMarkerKind { pickup, dropoff, driver, me }

class MapMarker {
  const MapMarker({required this.id, required this.point, required this.kind, this.title, this.rotation = 0});
  final String id;
  final GeoPoint point;
  final MapMarkerKind kind;
  final String? title;
  final double rotation;
}

/// Engine-agnostic camera handle. Commands issued before the map is ready are queued.
class AppMapController {
  gm.GoogleMapController? _google;
  fm.MapController? _osm;
  bool _osmReady = false;
  Future<void> Function()? _pending;

  /// Insets of UI chrome over the map (from [AppMap.padding]); fitted bounds avoid them.
  EdgeInsets _chrome = EdgeInsets.zero;

  bool get isReady => _google != null || _osmReady;

  void _attachGoogle(gm.GoogleMapController c) {
    _google = c;
    _flush();
  }

  void _attachOsm(fm.MapController c) {
    _osm = c;
    _osmReady = true;
    _flush();
  }

  void _detach() {
    _google = null;
    _osm = null;
    _osmReady = false;
  }

  void _flush() {
    final p = _pending;
    _pending = null;
    if (p != null) unawaited(p());
  }

  Future<void> moveTo(GeoPoint p, {double zoom = 15.5}) async {
    if (!isReady) {
      _pending = () => moveTo(p, zoom: zoom);
      return;
    }
    if (_google != null) {
      await _google!.animateCamera(gm.CameraUpdate.newLatLngZoom(gm.LatLng(p.lat, p.lng), zoom));
    } else {
      _osm?.move(ll.LatLng(p.lat, p.lng), zoom);
    }
  }

  Future<void> fit(List<GeoPoint> points, {double padding = 80}) async {
    if (points.isEmpty) return;
    if (!isReady) {
      _pending = () => fit(points, padding: padding);
      return;
    }
    if (points.length == 1) return moveTo(points.first);
    var minLat = points.first.lat, maxLat = points.first.lat, minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    if ((maxLat - minLat).abs() < 1e-5 && (maxLng - minLng).abs() < 1e-5) return moveTo(points.first);
    try {
      if (_google != null) {
        await _google!.animateCamera(gm.CameraUpdate.newLatLngBounds(
          gm.LatLngBounds(southwest: gm.LatLng(minLat, minLng), northeast: gm.LatLng(maxLat, maxLng)),
          padding,
        ));
      } else {
        _osm?.fitCamera(fm.CameraFit.bounds(
          bounds: fm.LatLngBounds(ll.LatLng(minLat, minLng), ll.LatLng(maxLat, maxLng)),
          padding: EdgeInsets.all(padding) + _chrome,
          maxZoom: 17,
        ));
      }
    } catch (_) {}
  }
}

/// The single map widget used by every screen (customer home, route preview, matching,
/// live trip, driver dashboard, driver trip, trip detail).
///
/// Supports markers, a route polyline, camera fit/move via [AppMapController], the user's
/// location, map taps and camera-idle callbacks (for "drag the map to set pickup").
class AppMap extends ConsumerWidget {
  const AppMap({
    super.key,
    required this.initialTarget,
    this.markers = const [],
    this.route = const [],
    this.controller,
    this.onCameraIdle,
    this.onCameraMoveStarted,
    this.onTap,
    this.myLocationEnabled = true,
    this.interactive = true,
    this.padding = EdgeInsets.zero,
    this.dark = false,
    this.zoom = 15,
    this.placeholderLabel,
  });

  final GeoPoint initialTarget;
  final List<MapMarker> markers;
  final List<GeoPoint> route;
  final AppMapController? controller;
  final ValueChanged<GeoPoint>? onCameraIdle;
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<GeoPoint>? onTap;
  final bool myLocationEnabled;
  final bool interactive;

  /// Insets for UI chrome overlapping the map (keeps fitted routes visible).
  final EdgeInsets padding;
  final bool dark;
  final double zoom;

  /// Unused by the live engines; retained for API compatibility.
  final String? placeholderLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(mapEngineProvider);
    return engine.when(
      data: (e) => e == MapEngine.google ? _GoogleAppMap(config: this) : _OsmAppMap(config: this),
      loading: () => Container(color: dark ? AppColors.nightSoft : const Color(0xFFEDEBEF)),
      error: (_, _) => _OsmAppMap(config: this),
    );
  }
}

// ---------------------------------------------------------------------------
// OpenStreetMap (flutter_map)
// ---------------------------------------------------------------------------

/// Tile URL template; override with `--dart-define=MAP_TILE_URL=...` (e.g. a commercial OSM
/// tile provider for production volumes, per the OSM tile usage policy).
const _osmTileUrl = String.fromEnvironment('MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
const _userAgentPackage = 'com.gopangitsolution.femalerider';

class _OsmAppMap extends ConsumerStatefulWidget {
  const _OsmAppMap({required this.config});
  final AppMap config;

  @override
  ConsumerState<_OsmAppMap> createState() => _OsmAppMapState();
}

class _OsmAppMapState extends ConsumerState<_OsmAppMap> {
  final _controller = fm.MapController();
  StreamSubscription<LocationFix>? _locSub;
  GeoPoint? _me;
  bool _moving = false;

  AppMap get c => widget.config;

  @override
  void initState() {
    super.initState();
    if (c.myLocationEnabled) _startLocation();
  }

  @override
  void didUpdateWidget(covariant _OsmAppMap old) {
    super.didUpdateWidget(old);
    if (c.myLocationEnabled && _locSub == null) _startLocation();
    if (!c.myLocationEnabled && _locSub != null) {
      _locSub?.cancel();
      _locSub = null;
      _me = null;
    }
  }

  Future<void> _startLocation() async {
    final svc = ref.read(locationServiceProvider);
    try {
      final last = await svc.lastKnown();
      if (mounted && last != null) setState(() => _me = last.point);
      _locSub = svc.stream(distanceFilterM: 15).listen(
        (f) {
          if (mounted) setState(() => _me = f.point);
        },
        onError: (Object _) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _locSub?.cancel();
    c.controller?._detach();
    _controller.dispose();
    super.dispose();
  }

  void _onEvent(fm.MapEvent e) {
    final userMove = e.source != fm.MapEventSource.mapController && e.source != fm.MapEventSource.fitCamera && e.source != fm.MapEventSource.nonRotatedSizeChange;
    if (e is fm.MapEventMoveStart || e is fm.MapEventDoubleTapZoomStart || e is fm.MapEventFlingAnimationStart || e is fm.MapEventRotateStart) {
      if (userMove && !_moving) {
        _moving = true;
        c.onCameraMoveStarted?.call();
      }
      return;
    }
    final ended = e is fm.MapEventMoveEnd ||
        e is fm.MapEventFlingAnimationEnd ||
        e is fm.MapEventFlingAnimationNotStarted ||
        e is fm.MapEventDoubleTapZoomEnd ||
        e is fm.MapEventScrollWheelZoom ||
        e is fm.MapEventRotateEnd;
    if (ended && (_moving || userMove)) {
      if (e is fm.MapEventMoveEnd && e.source == fm.MapEventSource.dragEnd) {
        // A fling may follow; wait for FlingAnimationEnd / NotStarted.
        return;
      }
      _moving = false;
      final center = e.camera.center;
      c.onCameraIdle?.call(GeoPoint(center.latitude, center.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    c.controller?._chrome = c.padding;
    final points = c.route.map((p) => ll.LatLng(p.lat, p.lng)).toList();
    final markers = <fm.Marker>[
      if (_me != null && c.myLocationEnabled)
        fm.Marker(point: ll.LatLng(_me!.lat, _me!.lng), width: 28, height: 28, child: const _MarkerGlyph(kind: MapMarkerKind.me)),
      for (final m in c.markers)
        fm.Marker(
          point: ll.LatLng(m.point.lat, m.point.lng),
          width: m.kind == MapMarkerKind.driver ? 44 : 36,
          height: m.kind == MapMarkerKind.driver ? 44 : 44,
          alignment: m.kind == MapMarkerKind.pickup || m.kind == MapMarkerKind.dropoff ? Alignment.topCenter : Alignment.center,
          child: Tooltip(message: m.title ?? '', child: _MarkerGlyph(kind: m.kind, rotation: m.rotation)),
        ),
    ];
    Widget map = fm.FlutterMap(
      mapController: _controller,
      options: fm.MapOptions(
        initialCenter: ll.LatLng(c.initialTarget.lat, c.initialTarget.lng),
        initialZoom: c.zoom,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: c.dark ? AppColors.nightSoft : const Color(0xFFEDEBEF),
        interactionOptions: fm.InteractionOptions(
          flags: c.interactive ? fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate : fm.InteractiveFlag.none,
        ),
        onMapReady: () => c.controller?._attachOsm(_controller),
        onMapEvent: _onEvent,
        onTap: c.onTap == null ? null : (_, p) => c.onTap!(GeoPoint(p.latitude, p.longitude)),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: _osmTileUrl,
          userAgentPackageName: _userAgentPackage,
          maxNativeZoom: 19,
          tileBuilder: c.dark ? _darkTileBuilder : null,
        ),
        if (points.length >= 2)
          fm.PolylineLayer(polylines: [
            fm.Polyline(points: points, strokeWidth: 6, color: Colors.white, borderStrokeWidth: 0),
            fm.Polyline(points: points, strokeWidth: 4, color: AppColors.crimson),
          ]),
        fm.MarkerLayer(markers: markers),
        // OSM attribution (required by the tile usage policy), kept compact and tappable.
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: c.padding.left + 6, bottom: c.padding.bottom + 6),
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ),
      ],
    );
    return map;
  }
}

/// Dims OSM tiles for the driver (dark) theme.
Widget _darkTileBuilder(BuildContext context, Widget tile, fm.TileImage image) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.55, -0.35, -0.10, 0, 255 * 0.78, //
      -0.35, -0.55, -0.10, 0, 255 * 0.78, //
      -0.35, -0.35, -0.30, 0, 255 * 0.80, //
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

/// Vector marker glyphs (OSM engine).
class _MarkerGlyph extends StatelessWidget {
  const _MarkerGlyph({required this.kind, this.rotation = 0});
  final MapMarkerKind kind;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case MapMarkerKind.pickup:
      case MapMarkerKind.dropoff:
        final color = kind == MapMarkerKind.pickup ? AppColors.ink : AppColors.crimson;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: AppShadows.card),
            child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
          ),
          Container(width: 3, height: 12, color: color),
        ]);
      case MapMarkerKind.driver:
        return Container(
          decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.18), shape: BoxShape.circle),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: AppShadows.brand),
            child: Transform.rotate(
              angle: rotation * math.pi / 180,
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
            ),
          ),
        );
      case MapMarkerKind.me:
        return Container(
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.2), shape: BoxShape.circle),
          padding: const EdgeInsets.all(6),
          child: Container(decoration: BoxDecoration(color: AppColors.info, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5))),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Google Maps (google_maps_flutter) — used when GOOGLE_MAPS_ENABLED=true and a key exists
// ---------------------------------------------------------------------------

class _GoogleAppMap extends StatefulWidget {
  const _GoogleAppMap({required this.config});
  final AppMap config;

  @override
  State<_GoogleAppMap> createState() => _GoogleAppMapState();
}

class _GoogleAppMapState extends State<_GoogleAppMap> {
  gm.LatLng? _center;
  final Map<MapMarkerKind, gm.BitmapDescriptor> _icons = {};

  AppMap get c => widget.config;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void dispose() {
    c.controller?._detach();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    for (final k in MapMarkerKind.values) {
      try {
        _icons[k] = await _MarkerPainter.build(k);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final markers = c.markers
        .map((m) => gm.Marker(
              markerId: gm.MarkerId(m.id),
              position: gm.LatLng(m.point.lat, m.point.lng),
              icon: _icons[m.kind] ?? gm.BitmapDescriptor.defaultMarkerWithHue(m.kind == MapMarkerKind.dropoff ? gm.BitmapDescriptor.hueRed : gm.BitmapDescriptor.hueRose),
              anchor: m.kind == MapMarkerKind.driver || m.kind == MapMarkerKind.me ? const Offset(0.5, 0.5) : const Offset(0.5, 1),
              rotation: m.rotation,
              flat: m.kind == MapMarkerKind.driver,
              infoWindow: m.title != null ? gm.InfoWindow(title: m.title) : gm.InfoWindow.noText,
            ))
        .toSet();
    final polylines = c.route.length >= 2
        ? {
            gm.Polyline(
              polylineId: const gm.PolylineId('route'),
              points: c.route.map((p) => gm.LatLng(p.lat, p.lng)).toList(),
              color: AppColors.crimson,
              width: 5,
              startCap: gm.Cap.roundCap,
              endCap: gm.Cap.roundCap,
              jointType: gm.JointType.round,
            ),
          }
        : <gm.Polyline>{};
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: gm.LatLng(c.initialTarget.lat, c.initialTarget.lng), zoom: c.zoom),
      onMapCreated: (ctrl) => c.controller?._attachGoogle(ctrl),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: c.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: c.interactive,
      zoomGesturesEnabled: c.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      padding: c.padding,
      onTap: c.onTap == null ? null : (p) => c.onTap!(GeoPoint(p.latitude, p.longitude)),
      onCameraMoveStarted: c.onCameraMoveStarted,
      onCameraMove: (pos) => _center = pos.target,
      onCameraIdle: () {
        final center = _center;
        if (center != null) c.onCameraIdle?.call(GeoPoint(center.latitude, center.longitude));
      },
    );
  }
}

/// Draws circular brand markers into bitmaps (Google engine).
class _MarkerPainter {
  static Future<gm.BitmapDescriptor> build(MapMarkerKind kind) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    switch (kind) {
      case MapMarkerKind.pickup:
      case MapMarkerKind.dropoff:
        final color = kind == MapMarkerKind.pickup ? AppColors.ink : AppColors.crimson;
        canvas.drawCircle(center.translate(0, -10), 28, Paint()..color = color);
        canvas.drawCircle(center.translate(0, -10), 11, Paint()..color = Colors.white);
        final path = Path()
          ..moveTo(size / 2 - 12, size / 2 + 12)
          ..lineTo(size / 2, size - 6)
          ..lineTo(size / 2 + 12, size / 2 + 12)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      case MapMarkerKind.driver:
        canvas.drawCircle(center, 34, Paint()..color = const Color(0x33C8102E));
        canvas.drawCircle(center, 24, Paint()..color = AppColors.crimson);
        final arrow = Path()
          ..moveTo(size / 2, size / 2 - 14)
          ..lineTo(size / 2 + 10, size / 2 + 11)
          ..lineTo(size / 2, size / 2 + 5)
          ..lineTo(size / 2 - 10, size / 2 + 11)
          ..close();
        canvas.drawPath(arrow, Paint()..color = Colors.white);
      case MapMarkerKind.me:
        canvas.drawCircle(center, 30, Paint()..color = const Color(0x332563EB));
        canvas.drawCircle(center, 16, Paint()..color = Colors.white);
        canvas.drawCircle(center, 11, Paint()..color = AppColors.info);
    }
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 40, height: 40);
  }
}

/// Fixed centre pin drawn over the map for "drag map to set pickup".
class CenterPin extends StatelessWidget {
  const CenterPin({super.key, this.label, this.lifted = false});
  final String? label;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (label != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.pill), boxShadow: AppShadows.card),
            child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        AnimatedSlide(
          duration: const Duration(milliseconds: 150),
          offset: lifted ? const Offset(0, -0.15) : Offset.zero,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: AppShadows.brand),
          ),
        ),
        Container(width: 3, height: 16, color: AppColors.crimson),
        Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 48),
      ]),
    );
  }
}

/// Default map centre (Karachi) used before we have a GPS fix.
const kDefaultMapCenter = GeoPoint(24.8607, 67.0011);
