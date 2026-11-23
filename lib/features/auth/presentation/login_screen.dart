import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_fields.dart';

/// Email (or phone) + password; a one-time code is then emailed (see EmailOtpScreen).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).login(login: _login.text, password: _password.text);
      if (mounted) context.push(Routes.emailOtp, extra: res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                const BrandLogo(size: 64),
                const SizedBox(height: AppSpace.lg),
                const Text('Welcome back', style: AppText.h1),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Log in with your email or phone and password. We’ll email you a code to confirm it’s you.',
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpace.xl),
                TextFormField(
                  key: const ValueKey('login-input'),
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Email or phone number'),
                  validator: (v) => (v ?? '').trim().length < 6 ? 'Enter your email or phone number' : null,
                ),
                const SizedBox(height: AppSpace.md),
                PasswordField(
                  key: const ValueKey('login-password'),
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(Routes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (_error != null) ...[
                  InfoBanner(message: _error!, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
                  const SizedBox(height: AppSpace.md),
                ],
                AppButton(key: const ValueKey('login-submit'), label: 'Log in', loading: _loading, onPressed: _submit),
                const SizedBox(height: AppSpace.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('New to FemaleRider?', style: AppText.body.copyWith(color: AppColors.muted)),
                    TextButton(
                      key: const ValueKey('go-register'),
                      onPressed: () => context.push(Routes.register),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
