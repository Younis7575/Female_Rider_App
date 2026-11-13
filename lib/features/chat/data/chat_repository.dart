import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';

/// Trip chat: only the trip's customer and driver, writable while the trip is active.
class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<ChatThread> thread(String tripId, {int? after}) async =>
      ChatThread.fromJson((await _api.get('/trips/$tripId/messages', query: {'after': ?after})).dataMap);

  Future<ChatMessage> send(String tripId, String body, {required String clientId}) async =>
      ChatMessage.fromJson((await _api.post('/trips/$tripId/messages', data: {'body': body, 'client_id': clientId})).dataMap);

  Future<void> markRead(String tripId) => _api.post('/trips/$tripId/messages/read');
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

/// Trip id of the chat currently on screen (its pushes are not shown as banners).
abstract final class OpenChat {
  static String? tripId;
}
