import 'package:femalerider/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] inside a themed app with a minimal router that records navigation.
Future<GoRouter> pumpWithRouter(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  List<String> extraRoutes = const ['/home', '/driver', '/profile-setup', '/account-status', '/driver-apply', '/driver-apply/status'],
}) async {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => child),
      for (final r in extraRoutes) GoRoute(path: r, builder: (_, _) => Scaffold(body: Text('ROUTE:$r'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pump();
  return router;
}

/// Pumps a plain widget inside a themed Scaffold.
Future<void> pumpPlain(WidgetTester tester, Widget child, {List<Override> overrides = const []}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await tester.pump();
}

/// Disposes the tree so timers / provider loops are cancelled before the test ends.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}
