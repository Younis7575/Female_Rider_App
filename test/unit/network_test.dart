import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:femalerider/core/network/api_client.dart';
import 'package:femalerider/core/network/api_envelope.dart';
import 'package:femalerider/core/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned-response Dio adapter capturing requests.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Fails the first [failures] attempts with a connection error, then answers 200.
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter(this.failures, {this.type = DioExceptionType.connectionError});
  int failures;
  final DioExceptionType type;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': {'ok': true}}), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _flakyClient(_FlakyAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1', validateStatus: (_) => true))..httpClientAdapter = adapter;
  return ApiClient(baseUrl: 'http://api.test/api/v1', storage: AppStorage(MemoryKeyValueStore({})), dio: dio);
}

ApiClient _client(_Adapter adapter, {void Function()? onUnauthorized, String? token}) {
  final storage = AppStorage(MemoryKeyValueStore({'auth_token': ?token}));
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1', validateStatus: (_) => true))..httpClientAdapter = adapter;
  return ApiClient(baseUrl: 'http://api.test/api/v1', storage: storage, dio: dio, onUnauthorized: onUnauthorized);
}

void main() {
  group('ApiEnvelope', () {
    test('parses success envelope with pagination', () {
      final env = ApiEnvelope.fromJson({
        'success': true,
        'message': 'ok',
        'data': [1, 2],
        'meta': {
          'pagination': {'current_page': 1, 'per_page': 20, 'total': 45, 'last_page': 3},
          'unread': 2,
        },
        'error': null,
      }, statusCode: 200);
      expect(env.success, isTrue);
      expect(env.dataList, [1, 2]);
      expect(env.pagination!.hasMore, isTrue);
      expect(env.pagination!.total, 45);
      expect(env.meta!['unread'], 2);
    });

    test('parses error envelope into ApiException with details', () {
      final env = ApiEnvelope.fromJson({
        'success': false,
        'message': 'Fare must be between 205 and 725.',
        'data': null,
        'meta': null,
        'error': {
          'code': 'fare_out_of_bounds',
          'details': {'min_fare': 205, 'max_fare': '725.00'},
        },
      }, statusCode: 422);
      final ex = ApiException.fromEnvelope(env);
      expect(ex.code, 'fare_out_of_bounds');
      expect(ex.message, 'Fare must be between 205 and 725.');
      expect(ex.fareBounds, (min: 205.0, max: 725.0));
      expect(ex.statusCode, 422);
    });

    test('validation errors expose field messages', () {
      final ex = ApiException.fromEnvelope(ApiEnvelope.fromJson({
        'success': false,
        'message': 'The name field is required.',
        'error': {
          'code': 'validation_failed',
          'details': {
            'name': ['The name field is required.'],
          },
        },
      }, statusCode: 422));
      expect(ex.isValidation, isTrue);
      expect(ex.fieldError('name'), 'The name field is required.');
      expect(ex.fieldError('email'), isNull);
    });

    test('OTP attempts / retry_after helpers', () {
      const ex = ApiException(message: 'x', code: 'otp_invalid', details: {'attempts_left': 3});
      expect(ex.attemptsLeft, 3);
      const cd = ApiException(message: 'x', code: 'otp_cooldown', details: {'retry_after': 42});
      expect(cd.retryAfter, 42);
    });

    test('non-envelope body (broadcast auth) is wrapped as data', () {
      final env = ApiEnvelope.fromJson({'auth': 'key:sig'}, statusCode: 200);
      expect(env.success, isTrue);
      expect(env.dataMap['auth'], 'key:sig');
    });

    test('missing message falls back to a friendly default', () {
      final ex = ApiException.fromEnvelope(ApiEnvelope.fromJson({'success': false, 'error': {'code': 'x'}}, statusCode: 503));
      expect(ex.message, contains('trouble'));
    });
  });

  group('ApiClient retries (flaky networks)', () {
    test('a request that never reached the server is retried', () async {
      final adapter = _FlakyAdapter(2);
      final env = await _flakyClient(adapter).post('/trips/t1/arrive');
      expect(env.success, isTrue);
      expect(adapter.calls, 3);
    });

    test('gives up after two retries', () async {
      final adapter = _FlakyAdapter(5);
      await expectLater(_flakyClient(adapter).get('/me'), throwsA(isA<ApiException>()));
      expect(adapter.calls, 3);
    });

    test('a POST that timed out after sending is not repeated, a GET is', () async {
      final post = _FlakyAdapter(1, type: DioExceptionType.receiveTimeout);
      await expectLater(_flakyClient(post).post('/offers/1/accept'), throwsA(isA<ApiException>()));
      expect(post.calls, 1);
      final get = _FlakyAdapter(1, type: DioExceptionType.receiveTimeout);
      expect((await _flakyClient(get).get('/driver/requests')).success, isTrue);
      expect(get.calls, 2);
    });
  });

  group('ApiClient', () {
    test('adds bearer token + Accept header and unwraps data', () async {
      final adapter = _Adapter(200, {'success': true, 'message': null, 'data': {'ok': 1}, 'meta': null, 'error': null});
      final env = await _client(adapter, token: 'tok').get('/me');
      expect(env.dataMap['ok'], 1);
      expect(adapter.last!.headers['Authorization'], 'Bearer tok');
      expect(adapter.last!.headers['Accept'], 'application/json');
    });

    test('throws ApiException mapped from error envelope', () async {
      final adapter = _Adapter(409, {
        'success': false,
        'message': 'You already have an active trip.',
        'data': null,
        'meta': null,
        'error': {'code': 'active_trip_exists', 'details': null},
      });
      expect(
        () => _client(adapter).post('/rides', data: {}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'active_trip_exists').having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('401 triggers onUnauthorized', () async {
      var fired = 0;
      final adapter = _Adapter(401, {'success': false, 'message': 'Please sign in again.', 'error': {'code': 'unauthenticated'}});
      await expectLater(_client(adapter, onUnauthorized: () => fired++).get('/me'), throwsA(isA<ApiException>()));
      expect(fired, 1);
    });

    test('idempotent POST sends a UUID Idempotency-Key', () async {
      final adapter = _Adapter(201, {'success': true, 'data': {}});
      await _client(adapter).post('/offers/1/accept', idempotent: true);
      final key = adapter.last!.headers['Idempotency-Key'] as String;
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(key), isTrue);
    });

    test('explicit idempotency key is reused verbatim', () async {
      final adapter = _Adapter(201, {'success': true, 'data': {}});
      await _client(adapter).post('/rides', data: {}, idempotencyKey: 'fixed-key');
      expect(adapter.last!.headers['Idempotency-Key'], 'fixed-key');
    });

    test('connection errors become network ApiException', () {
      final ex = ApiClient.mapDioException(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError));
      expect(ex.isNetwork, isTrue);
    });
  });
}
