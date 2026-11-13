import 'dart:math' as math;

/// Simple lat/lng pair independent of the maps plugin (keeps domain code testable).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Decodes a Google encoded polyline (precision 5).
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      if (index >= encoded.length) return points;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      if (index >= encoded.length) return points;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    points.add(GeoPoint(lat / 1e5, lng / 1e5));
  }
  return points;
}

/// Route points: decoded polyline when present, otherwise a straight line.
List<GeoPoint> routePoints(String? polyline, GeoPoint from, GeoPoint to) {
  if (polyline != null && polyline.isNotEmpty) {
    final pts = decodePolyline(polyline);
    if (pts.length >= 2) return pts;
  }
  return [from, to];
}

/// Haversine distance in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double d) => d * math.pi / 180;
