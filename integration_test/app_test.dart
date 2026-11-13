// Customer login happy path against the REAL local backend.
//
// Prerequisites:
//   * Laravel API running (php artisan serve) with OTP_EXPOSE_IN_RESPONSE=true and APP_ENV=local,
//     seeded demo customer +92 3001234567.
//   * A booted simulator/emulator that can reach the API (iOS simulator: 127.0.0.1, Android emulator: 10.0.2.2).
//
// Run:
//   flutter test integration_test/app_test.dart -d <device-id>
//   # physical device / custom host:
//   flutter test integration_test/app_test.dart -d <device-id> \
//     --dart-define=API_BASE_URL=http://<LAN-IP>:8000 --dart-define=WS_HOST=<LAN-IP>
//
// Note: the backend allows 5 OTP requests per phone per hour.
import 'package:femalerider/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _phone = String.fromEnvironment('IT_PHONE', defaultValue: '3001234567');

Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer signs in with OTP and reaches the home map', (tester) async {
    // Start from a clean, signed-out install.
    await const FlutterSecureStorage().deleteAll();

    await app.main();
    await tester.pump();

    // Onboarding (first launch) -> skip to login.
    final skip = find.text('Skip');
    final phoneInput = find.byKey(const ValueKey('phone-input'));
    await pumpUntil(tester, find.byWidgetPredicate((w) => w is Text && (w.data == 'Skip' || w.data == 'Continue')));
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
    }
    await pumpUntil(tester, phoneInput);

    await tester.enterText(phoneInput, _phone);
    await tester.pump();
    await tester.tap(find.text('Continue'));

    // OTP screen: local builds auto-fill data.debug_code from the API.
    final verify = find.byKey(const ValueKey('otp-verify'));
    await pumpUntil(tester, verify);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(verify);

    // Customer home with the destination entry.
    await pumpUntil(tester, find.byKey(const ValueKey('where-to')), timeout: const Duration(seconds: 45));
    // New/customer accounts always land on Customer home (no mode switcher on the home screen).
    expect(find.text('FemaleRider'), findsWidgets);
    expect(find.byKey(const ValueKey('mode-switch-tile')), findsNothing);
  });
}
