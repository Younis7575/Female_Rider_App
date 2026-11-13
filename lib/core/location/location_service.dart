import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/polyline.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

class LocationFix {
  const LocationFix({required this.lat, required this.lng, this.heading, this.speed, this.accuracy, required this.timestamp});
  final double lat;
  final double lng;
  final double? heading;

  /// metres / second
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  GeoPoint get point => GeoPoint(lat, lng);

  factory LocationFix.fromPosition(Position p) => LocationFix(
        lat: p.latitude,
        lng: p.longitude,
        heading: p.heading >= 0 && p.heading <= 360 ? p.heading : null,
        speed: p.speed >= 0 ? p.speed : null,
        accuracy: p.accuracy,
        timestamp: p.timestamp,
      );
}

/// Wraps geolocator so features (and tests) depend on a small interface.
class LocationService {
  Future<LocationAccess> ensurePermission({bool background = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return LocationAccess.deniedForever;
      if (perm == LocationPermission.denied) return LocationAccess.denied;
      if (background && perm == LocationPermission.whileInUse && Platform.isIOS) {
        // iOS: ask to upgrade to "Always" for background driver tracking (best effort).
        await Geolocator.requestPermission();
      }
      return LocationAccess.granted;
    } catch (e) {
      debugPrint('Location permission error: $e');
      return LocationAccess.denied;
    }
  }

  Future<LocationFix?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : LocationFix.fromPosition(p);
    } catch (_) {
      return null;
    }
  }

  Future<LocationFix?> current({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final access = await ensurePermission();
      if (access != LocationAccess.granted) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      return LocationFix.fromPosition(p);
    } catch (e) {
      debugPrint('getCurrentPosition failed: $e');
      return lastKnown();
    }
  }

  /// Continuous stream. With [background] on Android a foreground-service notification
  /// keeps updates flowing while the app is backgrounded (driver mode).
  Stream<LocationFix> stream({bool background = false, int distanceFilterM = 10}) {
    LocationSettings settings;
    try {
      if (Platform.isAndroid) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'FemaleRider driver mode',
                  notificationText: 'Sharing your location while you are online.',
                  notificationIcon: AndroidResource(name: 'ic_notification', defType: 'drawable'),
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        );
      } else if (Platform.isIOS) {
        settings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterM,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: !background,
          allowBackgroundLocationUpdates: background,
          showBackgroundLocationIndicator: background,
        );
      } else {
        settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterM);
      }
    } catch (_) {
      settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterM);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(LocationFix.fromPosition);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// One-shot current location (refreshable).
final currentLocationProvider = FutureProvider.autoDispose<LocationFix?>((ref) async {
  return ref.watch(locationServiceProvider).current();
});
