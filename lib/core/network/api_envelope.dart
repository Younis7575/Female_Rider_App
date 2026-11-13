import 'json.dart';

/// Pagination block from `meta.pagination`.
class Pagination {
  const Pagination({required this.currentPage, required this.perPage, required this.total, required this.lastPage});

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory Pagination.fromJson(Json j) => Pagination(
        currentPage: asInt(j['current_page'], 1),
        perPage: asInt(j['per_page'], 20),
        total: asInt(j['total']),
        lastPage: asInt(j['last_page'], 1),
      );
}

/// The backend envelope:
/// `{ success, message, data, meta, error: {code, details} }`.
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    this.message,
    this.data,
    this.meta,
    this.errorCode,
    this.errorDetails,
    this.statusCode,
  });

  final bool success;
  final String? message;
  final dynamic data;
  final Json? meta;
  final String? errorCode;
  final dynamic errorDetails;
  final int? statusCode;

  Pagination? get pagination {
    final p = meta?['pagination'];
    return p is Map ? Pagination.fromJson(asMap(p)) : null;
  }

  Json get dataMap => asMap(data);
  List<dynamic> get dataList => asList(data);

  /// Parses any decoded JSON body. Non-envelope bodies (e.g. the raw
  /// `{auth: ...}` returned by broadcasting auth) are wrapped as data.
  factory ApiEnvelope.fromJson(Object? body, {int? statusCode}) {
    if (body is Map && body.containsKey('success')) {
      final m = asMap(body);
      final err = asMapOrNull(m['error']);
      return ApiEnvelope(
        success: asBool(m['success']),
        message: asStringOrNull(m['message']),
        data: m['data'],
        meta: asMapOrNull(m['meta']),
        errorCode: asStringOrNull(err?['code']),
        errorDetails: err?['details'],
        statusCode: statusCode,
      );
    }
    final ok = statusCode == null || (statusCode >= 200 && statusCode < 300);
    return ApiEnvelope(success: ok, data: body, statusCode: statusCode);
  }
}

/// Typed error raised by the API layer. UI shows [message]; logic branches on [code].
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String code;
  final int? statusCode;
  final dynamic details;

  static const networkCode = 'network_error';
  static const timeoutCode = 'timeout';
  static const unknownCode = 'unknown';

  bool get isNetwork => code == networkCode || code == timeoutCode;
  bool get isUnauthenticated => statusCode == 401 || code == 'unauthenticated';
  bool get isValidation => code == 'validation_failed';

  Json get detailsMap => asMap(details);

  /// First validation message for a field (Laravel `errors` map).
  String? fieldError(String field) {
    final v = detailsMap[field];
    if (v is List && v.isNotEmpty) return v.first.toString();
    if (v is String) return v;
    return null;
  }

  /// `fare_out_of_bounds` helper.
  ({double min, double max})? get fareBounds {
    if (code != 'fare_out_of_bounds') return null;
    final d = detailsMap;
    final min = asDoubleOrNull(d['min_fare']);
    final max = asDoubleOrNull(d['max_fare']);
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  int? get attemptsLeft => asIntOrNull(detailsMap['attempts_left']);
  int? get retryAfter => asIntOrNull(detailsMap['retry_after']);

  factory ApiException.fromEnvelope(ApiEnvelope e) => ApiException(
        message: (e.message == null || e.message!.isEmpty) ? defaultMessageFor(e.statusCode) : e.message!,
        code: e.errorCode ?? (e.statusCode != null ? 'http_${e.statusCode}' : unknownCode),
        statusCode: e.statusCode,
        details: e.errorDetails,
      );

  static String defaultMessageFor(int? status) {
    switch (status) {
      case 401:
        return 'Please sign in again.';
      case 403:
        return 'You are not allowed to perform this action.';
      case 404:
        return 'We could not find what you were looking for.';
      case 429:
        return 'Too many requests. Please slow down.';
      case 500:
      case 502:
      case 503:
        return 'Our servers are having trouble. Please try again shortly.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Maps any thrown object to a human-readable message.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// A page of results.
class Paged<T> {
  const Paged({required this.items, this.pagination});
  final List<T> items;
  final Pagination? pagination;
  bool get hasMore => pagination?.hasMore ?? false;
  int get page => pagination?.currentPage ?? 1;
}
