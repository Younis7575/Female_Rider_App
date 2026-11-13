import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key/value persistence abstraction (secure storage in the app, in-memory in tests).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;
  final Map<String, String?> _cache = {};

  @override
  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final v = await _storage.read(key: key);
      _cache[key] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    _cache[key] = value;
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) => write(key, null);
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : _data = {...?initial};
  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Typed accessors for app-level persisted values.
class AppStorage {
  AppStorage(this._kv);
  final KeyValueStore _kv;

  static const _kToken = 'auth_token';
  static const _kDeviceId = 'device_id';
  static const _kOnboarding = 'onboarding_seen';
  static const _kFcmToken = 'fcm_token';
  static const _kLocale = 'locale';

  String? _tokenCache;
  String? get cachedToken => _tokenCache;

  Future<String?> readToken() async => _tokenCache = await _kv.read(_kToken);
  Future<void> writeToken(String? token) async {
    _tokenCache = token;
    await _kv.write(_kToken, token);
  }

  Future<bool> onboardingSeen() async => (await _kv.read(_kOnboarding)) == '1';
  Future<void> setOnboardingSeen() => _kv.write(_kOnboarding, '1');

  Future<String?> fcmToken() => _kv.read(_kFcmToken);
  Future<void> setFcmToken(String? t) => _kv.write(_kFcmToken, t);

  Future<String?> locale() => _kv.read(_kLocale);
  Future<void> setLocale(String l) => _kv.write(_kLocale, l);

  /// Stable per-install identifier sent with OTP and device registration.
  Future<String> deviceId() async {
    final existing = await _kv.read(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = generateUuidV4();
    await _kv.write(_kDeviceId, id);
    return id;
  }
}

final _rng = Random.secure();

/// RFC 4122 v4 UUID (used for Idempotency-Key headers and device ids).
String generateUuidV4() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SecureKeyValueStore());

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage(ref.watch(keyValueStoreProvider)));
