import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../auth/domain/user.dart';
import '../domain/account_models.dart';

/// Profile, mode, sessions, devices, verification, notifications and CMS content.
class AccountRepository {
  AccountRepository(this._api);
  final ApiClient _api;

  // ---- Profile ---------------------------------------------------------
  Future<AppUser> updateProfile(Map<String, dynamic> fields) async =>
      AppUser.fromJson((await _api.put('/me', data: fields)).dataMap);

  Future<AppUser> uploadPhoto(String path) async =>
      AppUser.fromJson((await _api.multipart('/me/photo', files: {'photo': UploadFile(path: path)})).dataMap);

  /// Returns the updated user plus the server message ("Switched to Driver mode.").
  Future<(AppUser, String?)> switchMode(String mode) async {
    final env = await _api.post('/me/mode', data: {'mode': mode});
    return (AppUser.fromJson(env.dataMap), env.message);
  }

  Future<String?> requestDeletion({String? reason}) async =>
      (await _api.post('/account/delete', data: {'reason': ?reason})).message;

  // ---- Sessions --------------------------------------------------------
  Future<List<SessionInfo>> sessions() async => asListOf((await _api.get('/sessions')).data, SessionInfo.fromJson);
  Future<void> revokeSession(int id) => _api.delete('/sessions/$id');
  Future<void> revokeOtherSessions() => _api.post('/sessions/revoke-others');

  // ---- Devices (push) --------------------------------------------------
  Future<void> registerDevice({required String token, required String platform, String? deviceId, String? deviceName, String? appVersion}) =>
      _api.post('/devices', data: {
        'token': token,
        'platform': platform,
        'device_id': ?deviceId,
        'device_name': ?deviceName,
        'app_version': ?appVersion,
      });

  Future<void> removeDevice(String token) => _api.delete('/devices', data: {'token': token});

  // ---- Eligibility verification ---------------------------------------
  Future<VerificationState> verification() async => VerificationState.fromJson((await _api.get('/verification')).dataMap);

  Future<String?> submitVerification({
    required String documentType,
    required String frontPath,
    String? backPath,
    String? selfiePath,
  }) async {
    final env = await _api.multipart('/verification', fields: {
      'document_type': documentType,
      'declaration': '1',
      'consent': '1',
    }, files: {
      'document_front': UploadFile(path: frontPath),
      if (backPath != null) 'document_back': UploadFile(path: backPath),
      if (selfiePath != null) 'selfie': UploadFile(path: selfiePath),
    });
    return env.message;
  }

  Future<String?> appealVerification(String reason) async =>
      (await _api.post('/verification/appeal', data: {'reason': reason})).message;

  // ---- Notifications ---------------------------------------------------
  Future<(Paged<AppNotification>, int unread)> notifications({int page = 1, bool unreadOnly = false}) async {
    final env = await _api.get('/notifications', query: {'page': page, if (unreadOnly) 'unread': 1});
    return (
      Paged(items: asListOf(env.data, AppNotification.fromJson), pagination: env.pagination),
      asInt(env.meta?['unread']),
    );
  }

  Future<void> markNotificationRead(int id) => _api.post('/notifications/$id/read');
  Future<void> markAllNotificationsRead() => _api.post('/notifications/read-all');

  // ---- Content -----------------------------------------------------------
  Future<List<Faq>> faqs({String? audience}) async =>
      asListOf((await _api.get('/faqs', query: {'audience': audience})).data, Faq.fromJson);

  Future<CmsPage> page(String slug) async => CmsPage.fromJson((await _api.get('/pages/$slug')).dataMap);

  Future<void> blockUser({required String tripId, String? reason}) =>
      _api.post('/users/block', data: {'trip_id': tripId, 'reason': ?reason});
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(apiClientProvider)));
