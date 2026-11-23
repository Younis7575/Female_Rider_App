import '../../../core/config/app_config.dart';
import 'user.dart';

/// Navigation payload from the phone screen to the OTP screen.
class OtpArgs {
  const OtpArgs({required this.country, required this.phone, required this.request});
  final Country country;

  /// National number as typed (digits only).
  final String phone;
  final OtpRequestResult request;
}

/// Result of a request that emailed a one-time code.
class EmailOtpResult {
  const EmailOtpResult({required this.email, required this.emailMasked, required this.purpose, required this.resendIn, this.debugCode});
  final String email;
  final String emailMasked;

  /// "register" (verify email) or "login".
  final String purpose;
  final int resendIn;
  final String? debugCode;

  factory EmailOtpResult.fromJson(Map<String, dynamic> j, {required String fallbackPurpose}) => EmailOtpResult(
        email: (j['email'] ?? '').toString(),
        emailMasked: (j['email_masked'] ?? j['email'] ?? '').toString(),
        purpose: (j['purpose'] ?? fallbackPurpose).toString(),
        resendIn: int.tryParse('${j['resend_in'] ?? 60}') ?? 60,
        debugCode: j['debug_code']?.toString(),
      );
}
