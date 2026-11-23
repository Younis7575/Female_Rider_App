import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_fields.dart';

/// Create an account: name, email, phone, password. The email is then verified with a
/// one-time code, after which she submits her details and waits for admin approval.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      showSnack(context, 'Please accept the Terms and Privacy Policy', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final country = ref.read(appConfigProvider).defaultCountry;
      final res = await ref.read(authRepositoryProvider).register(
        name: _name.text,
        email: _email.text,
        countryCode: country.code,
        phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (mounted) context.push(Routes.emailOtp, extra: res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLegal(String? url) async {
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView).catchError((_) => false);
  }

  String? _serverError(String field) => _error?.fieldError(field);

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    final country = cfg.defaultCountry;
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
                const Text('Create your account', style: AppText.h1),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'FemaleRider is a women-only community. After verifying your email you’ll add your details, and our team approves your account.',
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  key: const ValueKey('reg-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: 'Full name', errorText: _serverError('name')),
                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  key: const ValueKey('reg-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: 'Email (Gmail)', errorText: _serverError('email')),
                  validator: validateEmail,
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  key: const ValueKey('reg-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                    LengthLimitingTextInputFormatter(17),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    prefixText: '${country.code} ',
                    hintText: '300 1234567',
                    errorText: _serverError('phone'),
                  ),
                  validator: (v) {
                    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return d.length < 9 || d.length > 15 ? 'Enter a valid phone number' : null;
                  },
                ),
                const SizedBox(height: AppSpace.md),
                PasswordField(
                  key: const ValueKey('reg-password'),
                  controller: _password,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                ),
                const SizedBox(height: AppSpace.md),
                PasswordField(
                  key: const ValueKey('reg-confirm'),
                  controller: _confirm,
                  label: 'Confirm password',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                if (_serverError('password') != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_serverError('password')!, style: AppText.caption.copyWith(color: AppColors.danger)),
                  ),
                const SizedBox(height: AppSpace.sm),
                CheckboxListTile(
                  key: const ValueKey('reg-terms'),
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text.rich(
                    TextSpan(
                      style: AppText.caption,
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(color: AppColors.crimson, fontWeight: FontWeight.w700),
                          recognizer: TapGestureRecognizer()..onTap = () => _openLegal(cfg.termsUrl),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(color: AppColors.crimson, fontWeight: FontWeight.w700),
                          recognizer: TapGestureRecognizer()..onTap = () => _openLegal(cfg.privacyUrl),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null && !_error!.isValidation) ...[
                  InfoBanner(message: _error!.message, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
                  const SizedBox(height: AppSpace.md),
                ],
                const SizedBox(height: AppSpace.sm),
                AppButton(key: const ValueKey('reg-submit'), label: 'Create account', loading: _loading, onPressed: _submit),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Already have an account?', style: AppText.body.copyWith(color: AppColors.muted)),
                    TextButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go(Routes.login),
                      child: const Text('Log in'),
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
