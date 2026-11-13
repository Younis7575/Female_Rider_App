/// Defensive JSON readers. Laravel may serialise decimals as numbers or strings,
/// so every model goes through these helpers instead of raw casts.
typedef Json = Map<String, dynamic>;

double? asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

double asDouble(Object? v, [double fallback = 0]) => asDoubleOrNull(v) ?? fallback;

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.round();
  if (v is bool) return v ? 1 : 0;
  return null;
}

int asInt(Object? v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

String asString(Object? v, [String fallback = '']) => asStringOrNull(v) ?? fallback;

bool asBool(Object? v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return const ['1', 'true', 'yes', 'on'].contains(v.toLowerCase());
  return fallback;
}

Json asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, value) => MapEntry(k.toString(), value));
  return <String, dynamic>{};
}

Json? asMapOrNull(Object? v) => v is Map ? asMap(v) : null;

List<dynamic> asList(Object? v) => v is List ? v : const [];

List<T> asListOf<T>(Object? v, T Function(Json) parse) =>
    asList(v).whereType<Map>().map((e) => parse(asMap(e))).toList();

List<String> asStringList(Object? v) => asList(v).map((e) => e.toString()).toList();

DateTime? asDate(Object? v) {
  final s = asStringOrNull(v);
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}
