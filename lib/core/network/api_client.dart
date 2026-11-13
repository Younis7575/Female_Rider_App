import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/secure_store.dart';
import 'api_envelope.dart';

/// Callback invoked when the API rejects our token (HTTP 401).
typedef UnauthorizedHandler = void Function();

/// A file to upload in a multipart request.
class UploadFile {
  const UploadFile({required this.path, this.filename});
  final String path;
  final String? filename;
}

/// Thin, typed wrapper over Dio that speaks the FemaleRider envelope.
///
/// * Adds `Accept: application/json` and `Authorization: Bearer <token>`.
/// * Unwraps `{success, message, data, meta, error}`; throws [ApiException] on failure.
/// * Adds `Idempotency-Key` for critical POSTs when requested.
/// * Triggers [onUnauthorized] on 401 so the session can log out.
class ApiClient {
  ApiClient({required String baseUrl, required this.storage, Dio? dio, this.onUnauthorized})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 60),
              headers: const {'Accept': 'application/json'},
              // We parse every status ourselves to read the envelope.
              validateStatus: (_) => true,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = storage.cachedToken ?? await storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      options.headers['Accept'] = 'application/json';
      handler.next(options);
    }));
  }

  final Dio _dio;
  final AppStorage storage;
  UnauthorizedHandler? onUnauthorized;

  Dio get dio => _dio;

  Future<ApiEnvelope> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<ApiEnvelope> post(String path, {Object? data, bool idempotent = false, String? idempotencyKey}) =>
      _send(() => _dio.post(path, data: data, options: _idem(idempotent, idempotencyKey)));

  Future<ApiEnvelope> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data));

  Future<ApiEnvelope> delete(String path, {Object? data}) => _send(() => _dio.delete(path, data: data));

  /// Multipart POST. `files` values may be a single [UploadFile] or a `List<UploadFile>`
  /// (sent as `field[]`).
  Future<ApiEnvelope> multipart(
    String path, {
    Map<String, dynamic> fields = const {},
    Map<String, Object?> files = const {},
    bool idempotent = false,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    fields.forEach((k, v) {
      if (v != null) form.fields.add(MapEntry(k, v.toString()));
    });
    for (final entry in files.entries) {
      final v = entry.value;
      if (v is UploadFile) {
        form.files.add(MapEntry(entry.key, await MultipartFile.fromFile(v.path, filename: v.filename)));
      } else if (v is List<UploadFile>) {
        for (final f in v) {
          form.files.add(MapEntry('${entry.key}[]', await MultipartFile.fromFile(f.path, filename: f.filename)));
        }
      }
    }
    return _send(() => _dio.post(path, data: form, options: _idem(idempotent, null), onSendProgress: onProgress));
  }

  Options? _idem(bool idempotent, String? key) =>
      idempotent || key != null ? Options(headers: {'Idempotency-Key': key ?? generateUuidV4()}) : null;

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final m = Map<String, dynamic>.from(q)..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    return m;
  }

  Future<ApiEnvelope> _send(Future<Response<dynamic>> Function() call) async {
    Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    } catch (e) {
      throw ApiException(message: 'Something went wrong. Please try again.', code: ApiException.unknownCode, details: e.toString());
    }
    final env = ApiEnvelope.fromJson(res.data, statusCode: res.statusCode);
    final status = res.statusCode ?? 0;
    if (status == 401) {
      final ex = ApiException.fromEnvelope(env);
      onUnauthorized?.call();
      throw ex;
    }
    if (!env.success || status >= 400) {
      throw ApiException.fromEnvelope(env);
    }
    return env;
  }

  static ApiException mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(message: 'The connection timed out. Check your internet and try again.', code: ApiException.timeoutCode);
      case DioExceptionType.connectionError:
        return const ApiException(message: 'You appear to be offline. Check your internet connection.', code: ApiException.networkCode);
      case DioExceptionType.badResponse:
        final r = e.response;
        return ApiException.fromEnvelope(ApiEnvelope.fromJson(r?.data, statusCode: r?.statusCode));
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request cancelled.', code: 'cancelled');
      default:
        if (kDebugMode) debugPrint('Dio error: ${e.message}');
        return const ApiException(message: 'You appear to be offline. Check your internet connection.', code: ApiException.networkCode);
    }
  }
}

/// Global unauthorized broadcast so the session layer can react without a provider cycle.
class UnauthorizedSignal {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get stream => _controller.stream;
  void fire() => _controller.add(null);
}

final unauthorizedSignalProvider = Provider<UnauthorizedSignal>((ref) => UnauthorizedSignal());

final envProvider = Provider<Env>((ref) => Env.current);

final apiClientProvider = Provider<ApiClient>((ref) {
  final signal = ref.watch(unauthorizedSignalProvider);
  return ApiClient(
    baseUrl: ref.watch(envProvider).apiRoot,
    storage: ref.watch(appStorageProvider),
    onUnauthorized: signal.fire,
  );
});
