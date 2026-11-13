import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import '../domain/otp_args.dart';

/// Phone number entry with country picker; requests the OTP.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  Country? _country;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _digits.length >= 6 && _digits.length <= 15;

  Future<void> _pickCountry(List<Country> countries) async {
    final picked = await showAppSheet<Country>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.xs),
            child: Text('Select country', style: AppText.h3),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in countries)
                ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name),
                  trailing: Text(c.code, style: AppText.label),
                  onTap: () => Navigator.of(ctx).pop(c),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _submit(Country country) async {
    if (!_valid || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await ref.read(appStorageProvider).deviceId();
      final res = await ref.read(authRepositoryProvider).requestOtp(countryCode: country.code, phone: _digits, deviceId: deviceId);
      if (!mounted) return;
      context.push(Routes.otp, extra: OtpArgs(country: country, phone: _digits, request: res));
    } on ApiException catch (e) {
      setState(() {
        final wait = e.retryAfter;
        _error = (e.code == 'otp_cooldown' || e.code == 'otp_rate_limited') && wait != null && !e.message.contains('${wait}s')
            ? '${e.message} (try again in ${wait}s)'
            : e.message;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Signed-out users can't reach in-app routes other than auth, so legal docs open in the browser.
  Future<void> _openLegal(String? url) async {
    if (url == null || url.isEmpty) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView).catchError((_) => false);
    if (!ok && mounted) showSnack(context, 'Could not open the page.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    final country = _country ?? cfg.defaultCountry;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
          const BrandLogo(size: 64),
          const SizedBox(height: AppSpace.lg),
          const Text('Enter your phone number', style: AppText.h1),
          const SizedBox(height: AppSpace.xs),
          Text('We’ll send a ${cfg.otpLength}-digit code to verify it’s you.', style: AppText.body.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpace.xl),
          Row(children: [
            Semantics(
              button: true,
              label: 'Country ${country.name} ${country.code}',
              child: InkWell(
                borderRadius: AppRadius.input,
                onTap: () => _pickCountry(cfg.countries),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  decoration: BoxDecoration(color: AppColors.field, borderRadius: AppRadius.input),
                  child: Row(children: [
                    Text(country.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(country.code, style: AppText.title),
                    const Icon(Icons.expand_more_rounded, color: AppColors.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('phone-input'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')), LengthLimitingTextInputFormatter(17)],
                style: AppText.h3,
                decoration: const InputDecoration(hintText: '300 1234567'),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(country),
              ),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            InfoBanner(message: _error!, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
          ],
          const SizedBox(height: AppSpace.xl),
          AppButton(label: 'Continue', loading: _loading, onPressed: _valid ? () => _submit(country) : null),
          const SizedBox(height: AppSpace.lg),
          Text.rich(
            TextSpan(style: AppText.caption, children: [
              const TextSpan(text: 'By continuing you agree to our '),
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
              const TextSpan(text: '. FemaleRider is a women-only community; accounts are verified by our team.'),
            ]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
