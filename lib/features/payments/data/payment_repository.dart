import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../account/domain/account_models.dart';

class PaymentRepository {
  PaymentRepository(this._api);
  final ApiClient _api;

  Future<Paged<Payment>> payments({int page = 1}) async {
    final env = await _api.get('/payments', query: {'page': page});
    return Paged(items: asListOf(env.data, Payment.fromJson), pagination: env.pagination);
  }

  Future<Paged<Refund>> refunds({int page = 1}) async {
    final env = await _api.get('/refunds', query: {'page': page});
    return Paged(items: asListOf(env.data, Refund.fromJson), pagination: env.pagination);
  }

  Future<(Refund, String?)> requestRefund({required String tripId, required double amount, required String reason}) async {
    final env = await _api.post('/refunds', data: {'trip_id': tripId, 'amount': amount, 'reason': reason}, idempotent: true);
    return (Refund.fromJson(env.dataMap), env.message);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository(ref.watch(apiClientProvider)));
