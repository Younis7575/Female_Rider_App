import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Target platform used to pick sensible local-development defaults.
enum EnvPlatform { android, ios, other }

/// Single source of truth for environment configuration.
///
/// Values come from `--dart-define` / `--dart-define-from-file`:
///   API_BASE_URL, WS_HOST, WS_PORT, WS_SCHEME, APP_ENV, APP_VERSION
///
/// Defaults (no defines): Android emulator -> http://10.0.2.2:8000,
/// iOS simulator -> http://127.0.0.1:8000, websocket on the same host, port 8080, ws.
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.wsHost,
    required this.wsPort,
    required this.wsScheme,
    required this.appEnv,
    required this.appVersion,
  });

  final String apiBaseUrl;
  final String wsHost;
  final int wsPort;
  final String wsScheme;
  final String appEnv;
  final String appVersion;

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _wsHost = String.fromEnvironment('WS_HOST');
  static const _wsPort = String.fromEnvironment('WS_PORT');
  static const _wsScheme = String.fromEnvironment('WS_SCHEME');
  static const _appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');
  static const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// `--dart-define=GOOGLE_MAPS_ENABLED=true` switches maps from OpenStreetMap to Google Maps
  /// (requires native keys; falls back to OSM if the key is missing at runtime).
  static const googleMapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

  /// Resolved environment for the current process.
  static final Env current = resolve(
    platform: _detectPlatform(),
    apiBaseUrl: _apiBaseUrl,
    wsHost: _wsHost,
    wsPort: _wsPort,
    wsScheme: _wsScheme,
    appEnv: _appEnv,
    appVersion: _appVersion,
  );

  static EnvPlatform _detectPlatform() {
    if (kIsWeb) return EnvPlatform.other;
    try {
      if (Platform.isAndroid) return EnvPlatform.android;
      if (Platform.isIOS) return EnvPlatform.ios;
    } catch (_) {}
    return EnvPlatform.other;
  }

  /// Pure resolver (unit-testable): applies defaults for empty values.
  static Env resolve({
    required EnvPlatform platform,
    String apiBaseUrl = '',
    String wsHost = '',
    String wsPort = '',
    String wsScheme = '',
    String appEnv = 'local',
    String appVersion = '1.0.0',
  }) {
    final defaultHost = platform == EnvPlatform.android ? '10.0.2.2' : '127.0.0.1';
    var base = apiBaseUrl.trim().isEmpty ? 'http://$defaultHost:8000' : apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final apiHost = Uri.tryParse(base)?.host;
    final host = wsHost.trim().isNotEmpty
        ? wsHost.trim()
        : (apiHost != null && apiHost.isNotEmpty ? apiHost : defaultHost);
    return Env(
      apiBaseUrl: base,
      wsHost: host,
      wsPort: int.tryParse(wsPort.trim()) ?? 8080,
      wsScheme: wsScheme.trim().isEmpty ? 'ws' : wsScheme.trim(),
      appEnv: appEnv.trim().isEmpty ? 'local' : appEnv.trim(),
      appVersion: appVersion,
    );
  }

  /// `/api/v1` root used by the HTTP client.
  String get apiRoot => '$apiBaseUrl/api/v1';

  bool get isLocal => appEnv == 'local';
  bool get isProduction => appEnv == 'production';

  @override
  String toString() => 'Env($appEnv, api=$apiBaseUrl, ws=$wsScheme://$wsHost:$wsPort)';
}
