import 'package:femalerider/core/config/app_config.dart';
import 'package:femalerider/core/config/config_repository.dart';
import 'package:femalerider/core/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

class _Cfg extends AppConfigController {
  _Cfg(this.cfg);
  final AppConfig cfg;
  @override
  AppConfig build() => cfg;
}

void main() {
  testWidgets('offline banner is hidden in polling mode (no realtime key)', (tester) async {
    await pumpPlain(tester, const OfflineBanner(), overrides: [appConfigProvider.overrideWith(() => _Cfg(const AppConfig()))]);
    expect(find.textContaining('Reconnecting'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('offline banner shows when sockets are configured but down', (tester) async {
    final cfg = AppConfig.fromJson({
      'realtime': {'key': 'pk_live', 'host': 'ws.example', 'port': 443, 'scheme': 'https'},
    });
    await pumpPlain(tester, const OfflineBanner(), overrides: [appConfigProvider.overrideWith(() => _Cfg(cfg))]);
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    await disposeTree(tester);
  });
}
