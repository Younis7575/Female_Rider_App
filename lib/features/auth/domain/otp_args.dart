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
