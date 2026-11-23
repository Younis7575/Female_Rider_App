import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import '../domain/otp_args.dart';
import 'session_controller.dart';

/// Enter the code emailed for registration (verify email) or login.
class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({super.key, required this.request});
  final EmailOtpResult request;

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  EmailOtpResult get _req => widget.request;
  bool get _isRegister => _req.purpose == 'register';

  @override
  void initState() {
    super.initState();
    _startCountdown(_req.resendIn);
    final debug = _req.debugCode;
    if (debug != null && debug.isNotEmpty && ref.read(envProvider).isLocal) _code.text = debug;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds < 0 ? 0 : seconds);
    if (_remaining == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final length = ref.read(appConfigProvider).otpLength;
    final code = _code.text.trim();
    if (code.length != length || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).verifyEmailCode(email: _req.email, code: code, purpose: _req.purpose);
      final session = ref.read(sessionProvider.notifier);
      await session.signIn(result);
      final me = session.me;
      if (mounted && me != null) context.go(homeFor(me));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (e.code == 'otp_locked' || e.code == 'otp_expired') _code.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).resendEmailCode(email: _req.email, purpose: _req.purpose);
      if (!mounted) return;
      _code.clear();
      setState(() => _info = 'A new code has been sent. Check your inbox and spam folder.');
      _startCountdown(res.resendIn);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.retryAfter != null) _startCountdown(e.retryAfter!);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final length = ref.watch(appConfigProvider).otpLength;
    final ready = _code.text.length == length;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.crimson),
            const SizedBox(height: AppSpace.md),
            Text(_isRegister ? 'Verify your email' : 'Check your email', style: AppText.h1),
            const SizedBox(height: AppSpace.xs),
            Text.rich(
              TextSpan(
                style: AppText.body.copyWith(color: AppColors.muted),
                children: [
                  TextSpan(text: 'Enter the $length-digit code we sent to '),
                  TextSpan(text: _req.emailMasked, style: AppText.title),
                  const TextSpan(text: '. Can’t find it? Check the spam folder.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            TextField(
              key: const ValueKey('email-otp-input'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: length,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
              style: AppText.h1.copyWith(letterSpacing: 14, fontFeatures: const [FontFeature.tabularFigures()]),
              decoration: InputDecoration(
                counterText: '',
                hintText: '•' * length,
                hintStyle: AppText.h1.copyWith(color: AppColors.line, letterSpacing: 14),
              ),
              onChanged: (v) {
                setState(() => _error = null);
                if (v.length == length) _verify();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.sm),
              InfoBanner(message: _error!, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
            ] else if (_info != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(_info!, style: AppText.caption.copyWith(color: AppColors.success)),
            ],
            const SizedBox(height: AppSpace.lg),
            Center(
              child: _remaining > 0
                  ? Text('Resend code in ${formatCountdown(Duration(seconds: _remaining))}', style: AppText.bodySm)
                  : TextButton(onPressed: _resending ? null : _resend, child: Text(_resending ? 'Sending…' : 'Resend code')),
            ),
            const SizedBox(height: AppSpace.lg),
            AppButton(label: 'Verify', loading: _verifying, onPressed: ready ? _verify : null),
          ],
        ),
      ),
    );
  }
}
