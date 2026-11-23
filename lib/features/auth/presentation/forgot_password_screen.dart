import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_fields.dart';

/// Email → code → new password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_loading || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await fn();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(authRepositoryProvider).forgotPassword(_email.text);
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _reset() => _run(() async {
    final msg = await ref.read(authRepositoryProvider).resetPassword(
      email: _email.text,
      code: _code.text.trim(),
      password: _password.text,
      passwordConfirmation: _confirm.text,
    );
    if (!mounted) return;
    showSnack(context, msg ?? 'Password changed. Please log in.', success: true);
    context.go(Routes.login);
  });

  @override
  Widget build(BuildContext context) {
    final length = ref.watch(appConfigProvider).otpLength;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              const Text('Reset password', style: AppText.h1),
              const SizedBox(height: AppSpace.xs),
              Text(
                _codeSent
                    ? 'If this email is registered, we sent a $length-digit code. Enter it with your new password.'
                    : 'Enter your account email and we’ll send you a code.',
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpace.xl),
              TextFormField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
              ),
              if (_codeSent) ...[
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
                  decoration: const InputDecoration(labelText: 'Code from email'),
                  validator: (v) => (v ?? '').trim().length != length ? 'Enter the $length-digit code' : null,
                ),
                const SizedBox(height: AppSpace.md),
                PasswordField(
                  controller: _password,
                  label: 'New password',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                ),
                const SizedBox(height: AppSpace.md),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                InfoBanner(message: _error!, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
              ],
              const SizedBox(height: AppSpace.xl),
              AppButton(
                label: _codeSent ? 'Change password' : 'Send code',
                loading: _loading,
                onPressed: _codeSent ? _reset : _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
