import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'app_config.dart';

class ConfigRepository {
  ConfigRepository(this._api);
  final ApiClient _api;

  Future<AppConfig> fetch() async => AppConfig.fromJson((await _api.get('/config')).dataMap);
}

final configRepositoryProvider = Provider<ConfigRepository>((ref) => ConfigRepository(ref.watch(apiClientProvider)));

/// Holds the last loaded `/config`. Loaded by the splash screen; falls back to defaults.
class AppConfigController extends Notifier<AppConfig> {
  bool _loaded = false;
  bool get loaded => _loaded;

  @override
  AppConfig build() => const AppConfig();

  Future<AppConfig> load() async {
    final cfg = await ref.read(configRepositoryProvider).fetch();
    _loaded = true;
    state = cfg;
    return cfg;
  }

  // Test hook.
  void set(AppConfig cfg) {
    _loaded = true;
    state = cfg;
  }
}

final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(AppConfigController.new);
