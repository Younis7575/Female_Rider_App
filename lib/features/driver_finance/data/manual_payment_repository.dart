import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// Where drivers send money (FemaleRider's JazzCash account) and what they owe.
class PaymentInfo {
  const PaymentInfo({
    required this.enabled,
    required this.accountTitle,
    required this.accountNumber,
    required this.instructions,
    required this.minAmount,
    required this.maxAmount,
    required this.balance,
    required this.amountDue,
    required this.pendingAmount,
  });

  final bool enabled;
  final String accountTitle;
  final String accountNumber;
  final String instructions;
  final double minAmount;
  final double maxAmount;
  final double balance;
  final double amountDue;
  final double pendingAmount;

  factory PaymentInfo.fromJson(Json j) {
    final a = asMap(j['account']);
    return PaymentInfo(
      enabled: asBool(a['enabled']),
      accountTitle: asString(a['account_title'], 'FemaleRider'),
      accountNumber: asString(a['account_number']),
      instructions: asString(a['instructions']),
      minAmount: asDouble(a['min_amount'], 100),
      maxAmount: asDouble(a['max_amount'], 100000),
      balance: asDouble(j['balance']),
      amountDue: asDouble(j['amount_due']),
      pendingAmount: asDouble(j['pending_amount']),
    );
  }
}

/// A payment the driver submitted for admin verification.
class DriverDeposit {
  const DriverDeposit({
    required this.id,
    required this.amount,
    this.approvedAmount,
    required this.transactionRef,
    required this.status,
    this.rejectionReason,
    this.createdAt,
  });

  final String id;
  final double amount;
  final double? approvedAmount;
  final String transactionRef;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;

  factory DriverDeposit.fromJson(Json j) => DriverDeposit(
    id: asString(j['id']),
    amount: asDouble(j['amount']),
    approvedAmount: asDoubleOrNull(j['approved_amount']),
    transactionRef: asString(j['transaction_ref']),
    status: asString(j['status'], 'pending'),
    rejectionReason: asStringOrNull(j['rejection_reason']),
    createdAt: asDate(j['created_at']),
  );
}

class ManualPaymentRepository {
  ManualPaymentRepository(this._api);
  final ApiClient _api;

  Future<PaymentInfo> info() async =>
      PaymentInfo.fromJson((await _api.get('/driver/payment-info')).dataMap);

  Future<List<DriverDeposit>> deposits() async =>
      asListOf((await _api.get('/driver/deposits')).data, DriverDeposit.fromJson);

  Future<(DriverDeposit, String?)> submit({
    required double amount,
    required String transactionRef,
    required String screenshotPath,
    String? senderNumber,
    String? note,
  }) async {
    final env = await _api.multipart(
      '/driver/deposits',
      fields: {
        'amount': amount,
        'transaction_ref': transactionRef.trim(),
        'sender_number': (senderNumber ?? '').trim().isEmpty ? null : senderNumber!.trim(),
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      },
      files: {'screenshot': UploadFile(path: screenshotPath)},
    );
    return (DriverDeposit.fromJson(env.dataMap), env.message);
  }
}

final manualPaymentRepositoryProvider = Provider<ManualPaymentRepository>(
  (ref) => ManualPaymentRepository(ref.watch(apiClientProvider)),
);

final paymentInfoProvider = FutureProvider.autoDispose<PaymentInfo>(
  (ref) => ref.watch(manualPaymentRepositoryProvider).info(),
);

final depositsProvider = FutureProvider.autoDispose<List<DriverDeposit>>(
  (ref) => ref.watch(manualPaymentRepositoryProvider).deposits(),
);
