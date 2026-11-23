import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/otp_args.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<OtpRequestResult> requestOtp({required String countryCode, required String phone, String? deviceId}) async {
    final env = await _api.post('/auth/otp/request', data: {'country_code': countryCode, 'phone': phone, 'device_id': ?deviceId});
    return OtpRequestResult.fromJson(env.dataMap);
  }

  Future<AuthResult> verifyOtp({required String countryCode, required String phone, required String code}) async {
    final env = await _api.post('/auth/otp/verify', data: {
      'country_code': countryCode,
      'phone': phone,
      'code': code,
      'device_name': _deviceName(),
      'accept_terms': true,
    });
    return AuthResult.fromJson(env.dataMap);
  }

  // ---- Email + password accounts (email OTP on registration and every login) ----

  Future<EmailOtpResult> register({
    required String name,
    required String email,
    required String countryCode,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final env = await _api.post('/auth/register', data: {
      'name': name.trim(),
      'email': email.trim(),
      'country_code': countryCode,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'accept_terms': true,
    });
    return EmailOtpResult.fromJson(env.dataMap, fallbackPurpose: 'register');
  }

  /// Step 1 of login: checks the password and emails a code.
  Future<EmailOtpResult> login({required String login, required String password}) async {
    final env = await _api.post('/auth/login', data: {'login': login.trim(), 'password': password});
    return EmailOtpResult.fromJson(env.dataMap, fallbackPurpose: 'login');
  }

  /// Step 2: verifies the emailed code ([purpose] "register" or "login").
  Future<AuthResult> verifyEmailCode({required String email, required String code, required String purpose}) async {
    final env = await _api.post(purpose == 'register' ? '/auth/register/verify' : '/auth/login/verify', data: {
      'email': email,
      'code': code,
      'device_name': _deviceName(),
    });
    return AuthResult.fromJson(env.dataMap);
  }

  Future<EmailOtpResult> resendEmailCode({required String email, required String purpose}) async {
    final env = await _api.post('/auth/email-otp/resend', data: {'email': email, 'purpose': purpose});
    return EmailOtpResult.fromJson(env.dataMap, fallbackPurpose: purpose);
  }

  Future<String?> forgotPassword(String email) async =>
      (await _api.post('/auth/password/forgot', data: {'email': email.trim()})).message;

  Future<String?> resetPassword({required String email, required String code, required String password, required String passwordConfirmation}) async =>
      (await _api.post('/auth/password/reset', data: {
        'email': email.trim(),
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      })).message;

  Future<MeResult> me() async => MeResult.fromJson((await _api.get('/me')).dataMap);

  Future<void> logout({String? deviceToken}) async {
    await _api.post('/auth/logout', data: {'device_token': ?deviceToken});
  }

  static String _deviceName() {
    try {
      final name = 'FemaleRider ${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      return name.length > 100 ? name.substring(0, 100) : name;
    } catch (_) {
      return 'FemaleRider mobile';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
