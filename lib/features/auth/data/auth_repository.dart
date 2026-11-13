import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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
