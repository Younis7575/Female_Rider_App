import 'package:femalerider/core/config/app_config.dart';
import 'package:femalerider/core/config/env.dart';
import 'package:femalerider/core/network/api_client.dart';
import 'package:femalerider/core/network/api_envelope.dart';
import 'package:femalerider/core/storage/secure_store.dart';
import 'package:femalerider/core/widgets/buttons.dart';
import 'package:femalerider/features/auth/data/auth_repository.dart';
import 'package:femalerider/features/auth/domain/otp_args.dart';
import 'package:femalerider/features/auth/domain/user.dart';
import 'package:femalerider/features/auth/presentation/otp_screen.dart';
import 'package:femalerider/features/auth/presentation/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

OtpArgs _args({String? debugCode = '654321', int resendIn = 60}) => OtpArgs(
      country: Country.pakistan,
      phone: '3001234567',
      request: OtpRequestResult(phone: '+923001234567', expiresIn: 300, resendIn: resendIn, debugCode: debugCode),
    );

Env _env(String appEnv) => Env.resolve(platform: EnvPlatform.android, appEnv: appEnv);

void main() {
  late FakeAuthRepository auth;
  late MemoryKeyValueStore store;

  setUp(() {
    auth = FakeAuthRepository();
    store = MemoryKeyValueStore();
  });

  Future<void> pump(WidgetTester tester, {required OtpArgs args, String appEnv = 'production'}) async {
    await pumpWithRouter(tester, child: OtpScreen(args: args), overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      envProvider.overrideWithValue(_env(appEnv)),
      keyValueStoreProvider.overrideWithValue(store),
    ]);
  }

  AppButton verifyButton(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const ValueKey('otp-verify')));

  testWidgets('shows resend countdown and enables Verify only for a full code', (tester) async {
    await pump(tester, args: _args());
    expect(find.byKey(const ValueKey('otp-countdown')), findsOneWidget);
    expect(find.textContaining('Resend code in 01:00'), findsOneWidget);
    // Production build: debug code must NOT be auto-filled.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('otp-input'))).controller!.text, isEmpty);
    expect(verifyButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123');
    await tester.pump();
    expect(verifyButton(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Resend code in 00:58'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('auto-fills debug code only in local env', (tester) async {
    await pump(tester, args: _args(), appEnv: 'local');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('otp-input'))).controller!.text, '654321');
    expect(verifyButton(tester).onPressed, isNotNull);
    await disposeTree(tester);
  });

  testWidgets('wrong code shows the server message with attempts left', (tester) async {
    await pump(tester, args: _args());
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '000000');
    await tester.pumpAndSettle();
    expect(auth.verifyCalls, 1); // auto-submits at full length
    expect(find.byKey(const ValueKey('otp-error')), findsOneWidget);
    expect(find.text('Incorrect code. 4 attempt(s) left.'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('correct code signs in, stores token and navigates home', (tester) async {
    await pump(tester, args: _args());
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.pumpAndSettle();
    expect(auth.verifyCalls, 1);
    expect(await store.read('auth_token'), 'test-token');
    expect(find.text('ROUTE:/home'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('resend appears after cooldown and requests a new code', (tester) async {
    await pump(tester, args: _args(resendIn: 2));
    expect(find.byKey(const ValueKey('otp-resend')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('otp-resend')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('otp-resend')));
    await tester.pump();
    await tester.pump();
    expect(auth.requestCalls, 1);
    expect(find.byKey(const ValueKey('otp-countdown')), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('resend cooldown error restarts the countdown from retry_after', (tester) async {
    auth.requestError = const ApiException(message: 'Please wait 30s before requesting another code.', code: 'otp_cooldown', details: {'retry_after': 30});
    await pump(tester, args: _args(resendIn: 0));
    await tester.tap(find.byKey(const ValueKey('otp-resend')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Please wait 30s before requesting another code.'), findsOneWidget);
    expect(find.textContaining('Resend code in 00:30'), findsOneWidget);
    await disposeTree(tester);
  });

  test('session provider wiring compiles with the fake', () {
    expect(sessionProvider, isNotNull);
    expect(apiClientProvider, isNotNull);
  });
}
