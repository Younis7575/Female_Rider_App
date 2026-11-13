import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/redirect.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';
import '../domain/otp_args.dart';
import 'session_controller.dart';

/// One-time code verification with resend cooldown.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _remaining = 0;
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  int get _length => ref.read(appConfigProvider).otpLength;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.args.request.resendIn);
    final debug = widget.args.request.debugCode;
    if (debug != null && debug.isNotEmpty && ref.read(envProvider).isLocal) {
      _code.text = debug;
      _info = 'Development build: code filled automatically.';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    final value = seconds < 0 ? 0 : seconds;
    if (mounted && _timer != null) {
      setState(() => _remaining = value);
    } else {
      _remaining = value;
    }
    if (_remaining == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != _length || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).verifyOtp(
            countryCode: widget.args.country.code,
            phone: widget.args.phone,
            code: code,
          );
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
      final deviceId = await ref.read(appStorageProvider).deviceId();
      final res = await ref.read(authRepositoryProvider).requestOtp(
            countryCode: widget.args.country.code,
            phone: widget.args.phone,
            deviceId: deviceId,
          );
      if (!mounted) return;
      _code.clear();
      if (res.debugCode != null && ref.read(envProvider).isLocal) _code.text = res.debugCode!;
      setState(() => _info = 'A new code has been sent.');
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
    final phone = widget.args.request.phone.isNotEmpty ? widget.args.request.phone : '${widget.args.country.code} ${widget.args.phone}';
    final ready = _code.text.length == length;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
          const Text('Verify your number', style: AppText.h1),
          const SizedBox(height: AppSpace.xs),
          Text.rich(TextSpan(style: AppText.body.copyWith(color: AppColors.muted), children: [
            TextSpan(text: 'Enter the $length-digit code sent to '),
            TextSpan(text: phone, style: AppText.title),
          ])),
          const SizedBox(height: AppSpace.xl),
          TextField(
            key: const ValueKey('otp-input'),
            controller: _code,
            focusNode: _focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: length,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
            style: AppText.h1.copyWith(letterSpacing: 14, fontFeatures: const [FontFeature.tabularFigures()]),
            decoration: InputDecoration(counterText: '', hintText: '•' * length, hintStyle: AppText.h1.copyWith(color: AppColors.line, letterSpacing: 14)),
            onChanged: (v) {
              setState(() => _error = null);
              if (v.length == length) _verify();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, key: const ValueKey('otp-error'), style: AppText.bodySm.copyWith(color: AppColors.danger))),
            ]),
          ] else if (_info != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_info!, style: AppText.caption.copyWith(color: AppColors.success)),
          ],
          const SizedBox(height: AppSpace.lg),
          Center(
            child: _remaining > 0
                ? Text('Resend code in ${formatCountdown(Duration(seconds: _remaining))}', key: const ValueKey('otp-countdown'), style: AppText.bodySm)
                : TextButton(
                    key: const ValueKey('otp-resend'),
                    onPressed: _resending ? null : _resend,
                    child: Text(_resending ? 'Sending…' : 'Resend code'),
                  ),
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(key: const ValueKey('otp-verify'), label: 'Verify', loading: _verifying, onPressed: ready ? _verify : null),
          const SizedBox(height: AppSpace.md),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Change phone number'),
            ),
          ),
        ]),
      ),
    );
  }
}
