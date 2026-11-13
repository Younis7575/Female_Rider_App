import 'package:intl/intl.dart';

/// Formats a fare like `PKR 1,250` (no decimals for whole amounts, 2 otherwise).
String formatMoney(num? amount, {String currency = 'PKR', bool showCurrency = true}) {
  final v = (amount ?? 0).toDouble();
  final whole = (v - v.roundToDouble()).abs() < 0.005;
  final f = NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: whole ? 0 : 2);
  final s = f.format(whole ? v.roundToDouble() : v);
  return showCurrency ? '$currency $s' : s;
}

/// Rounds a fare to the nearest [step] (backend rounds proposals to 5).
double roundFare(double v, {int step = 5}) => (v / step).round() * step.toDouble();

/// Clamps then rounds a fare into the inclusive [min, max] window.
double clampFare(double v, double min, double max, {int step = 5}) {
  var r = roundFare(v, step: step);
  if (r < min) r = (min / step).ceil() * step.toDouble();
  if (r > max) r = (max / step).floor() * step.toDouble();
  if (r < min) r = min;
  if (r > max) r = max;
  return r;
}

String formatDistance(num? meters) {
  if (meters == null) return '—';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String formatDuration(num? seconds) {
  if (seconds == null) return '—';
  final mins = (seconds / 60).round();
  if (mins < 1) return '< 1 min';
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// mm:ss countdown text.
String formatCountdown(Duration d) {
  if (d.isNegative) return '00:00';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

String formatDateTime(DateTime? d) => d == null ? '—' : DateFormat('d MMM y, h:mm a').format(d);
String formatDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM y').format(d);
String formatTime(DateTime? d) => d == null ? '—' : DateFormat('h:mm a').format(d);
String formatShortDay(DateTime d) => DateFormat('EEE').format(d);

String formatRelative(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(d);
}

String formatRating(num? r) => (r ?? 0) <= 0 ? 'New' : (r!).toStringAsFixed(1);

/// `snake_case` -> `Snake case`.
String humanize(String? s) {
  if (s == null || s.isEmpty) return '';
  final t = s.replaceAll('_', ' ').replaceAll('.', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

/// `cnic_front` -> `CNIC front` with a few domain-specific acronyms.
String documentLabel(String type) {
  const map = {
    'cnic_front': 'CNIC (front)',
    'cnic_back': 'CNIC (back)',
    'license_front': 'Driving licence (front)',
    'license_back': 'Driving licence (back)',
    'vehicle_registration': 'Vehicle registration',
    'profile_photo': 'Profile photo',
    'vehicle_photo_front': 'Vehicle photo (front)',
    'vehicle_photo_back': 'Vehicle photo (back)',
    'vehicle_photo_interior': 'Vehicle photo (interior)',
    'insurance': 'Insurance certificate',
    'fitness_certificate': 'Fitness certificate',
    'police_clearance': 'Police clearance certificate',
    'cnic': 'CNIC',
    'nicop': 'NICOP',
    'passport': 'Passport',
    'other_government_id': 'Other government ID',
  };
  return map[type] ?? humanize(type);
}

String firstName(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  return name.trim().split(RegExp(r'\s+')).first;
}

String initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'FR';
  final parts = name.trim().split(RegExp(r'\s+'));
  final a = parts.first.isNotEmpty ? parts.first[0] : '';
  final b = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  return (a + b).toUpperCase();
}
