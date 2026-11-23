import 'package:femalerider/features/driver_finance/data/manual_payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses payment info and deposits', () {
    final p = PaymentInfo.fromJson({
      'account': {'enabled': true, 'account_title': 'FemaleRider', 'account_number': '03001234567', 'min_amount': 100, 'max_amount': '100000'},
      'balance': -250.5,
      'amount_due': 250.5,
      'pending_amount': 0,
    });
    expect(p.enabled, isTrue);
    expect(p.accountNumber, '03001234567');
    expect(p.amountDue, 250.5);
    expect(p.maxAmount, 100000);

    final d = DriverDeposit.fromJson({'id': 'u1', 'amount': '500.00', 'approved_amount': null, 'transaction_ref': 'TID1', 'status': 'rejected', 'rejection_reason': 'Not found'});
    expect(d.amount, 500);
    expect(d.approvedAmount, isNull);
    expect(d.rejectionReason, 'Not found');
  });
}
