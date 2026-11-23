import 'package:femalerider/features/auth/domain/otp_args.dart';
import 'package:femalerider/features/auth/presentation/widgets/auth_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password and email rules match the API', () {
    expect(validateNewPassword('short1'), isNotNull);
    expect(validateNewPassword('onlyletters'), isNotNull);
    expect(validateNewPassword('12345678'), isNotNull);
    expect(validateNewPassword('secret123'), isNull);
    expect(validateEmail('ayesha@gmail.com'), isNull);
    expect(validateEmail('ayesha@'), isNotNull);
  });

  test('email OTP result parsing', () {
    final r = EmailOtpResult.fromJson({'email': 'a@b.com', 'email_masked': 'a*@b.com', 'resend_in': 60, 'purpose': 'register'}, fallbackPurpose: 'login');
    expect(r.purpose, 'register');
    expect(r.emailMasked, 'a*@b.com');
    expect(EmailOtpResult.fromJson({'email': 'a@b.com'}, fallbackPurpose: 'login').purpose, 'login');
  });
}
