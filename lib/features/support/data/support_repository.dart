import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../account/domain/account_models.dart';

/// Support tickets.
class SupportRepository {
  SupportRepository(this._api);
  final ApiClient _api;

  static const categories = ['general', 'payment', 'lost_item', 'complaint', 'account', 'driver', 'safety', 'refund', 'fare_dispute'];

  Future<Paged<SupportTicket>> tickets({int page = 1}) async {
    final env = await _api.get('/support/tickets', query: {'page': page});
    return Paged(items: asListOf(env.data, SupportTicket.fromJson), pagination: env.pagination);
  }

  Future<(SupportTicket, String?)> createTicket({
    required String category,
    required String subject,
    required String message,
    String? tripId,
    String? attachmentPath,
  }) async {
    final env = await _api.multipart('/support/tickets', fields: {
      'category': category,
      'subject': subject,
      'message': message,
      'trip_id': tripId,
    }, files: {
      if (attachmentPath != null) 'attachment': UploadFile(path: attachmentPath),
    });
    return (SupportTicket.fromJson(env.dataMap), env.message);
  }

  Future<SupportTicket> ticket(String reference) async => SupportTicket.fromJson((await _api.get('/support/tickets/$reference')).dataMap);

  /// Reply with optional attachment (jpg/png/pdf ≤ 8 MB) — sent as multipart when present.
  Future<SupportTicket> reply(String reference, String message, {String? attachmentPath}) async {
    final path = '/support/tickets/$reference/messages';
    final env = attachmentPath == null
        ? await _api.post(path, data: {'message': message})
        : await _api.multipart(path, fields: {'message': message}, files: {'attachment': UploadFile(path: attachmentPath)});
    return SupportTicket.fromJson(env.dataMap);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) => SupportRepository(ref.watch(apiClientProvider)));
