import 'package:femalerider/features/driver/domain/driver_models.dart';
import 'package:femalerider/features/driver/presentation/widgets/request_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Map<String, dynamic> _request({Map<String, dynamic>? myOffer}) => {
      'id': 'ride-9',
      'status': 'offers_available',
      'pickup': {'lat': 33.65, 'lng': 73.08, 'address': 'Shamsabad, Rawalpindi'},
      'dropoff_area': 'Islamabad',
      'distance_m': 9200,
      'duration_s': 840,
      'pickup_distance_m': 280,
      'pickup_eta_s': 60,
      'proposed_fare': 300,
      'suggested_fare': 320,
      'min_fare': 225,
      'max_fare': 800,
      'currency': 'PKR',
      'payment_method': 'cash',
      'vehicle_category': 'FemaleRider Mini',
      'customer': {'first_name': 'Fatima', 'rating': 5.0, 'rides': 0},
      'expires_at': DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
      'my_offer': myOffer,
    };

void main() {
  testWidgets('new request: driver can accept the customer price or bid higher', (tester) async {
    final taps = <String>[];
    await pumpPlain(
      tester,
      RequestCard(
        request: DriverRequest.fromJson(_request()),
        busy: false,
        onAccept: () => taps.add('accept'),
        onCounter: () => taps.add('bid'),
        onDecline: () => taps.add('decline'),
        onWithdraw: () {},
        onAcceptCounter: () {},
        onRejectCounter: () {},
        onCounterCounter: () {},
      ),
    );
    expect(find.text('Accept PKR 300'), findsOneWidget);
    expect(find.text('Bid higher'), findsOneWidget);
    await tester.tap(find.text('Bid higher'));
    await tester.pump();
    expect(taps, ['bid']);
    await disposeTree(tester);
  });

  testWidgets('customer re-bid: driver sees the fare and can accept, reject or bid higher', (tester) async {
    final taps = <String>[];
    await pumpPlain(
      tester,
      RequestCard(
        request: DriverRequest.fromJson(_request(myOffer: {
          'id': 41,
          'ride_id': 'ride-9',
          'amount': 400,
          'proposed_by': 'customer',
          'status': 'pending',
          'sequence': 2,
          'expires_at': DateTime.now().add(const Duration(seconds: 40)).toIso8601String(),
        })),
        busy: false,
        onAccept: () {},
        onCounter: () {},
        onDecline: () {},
        onWithdraw: () {},
        onAcceptCounter: () => taps.add('accept'),
        onRejectCounter: () => taps.add('reject'),
        onCounterCounter: () => taps.add('bid'),
      ),
    );
    expect(find.text('Fatima wants to go for PKR 400'), findsOneWidget);
    await tester.tap(find.text('Accept PKR 400'));
    await tester.tap(find.text('Reject'));
    await tester.tap(find.text('Bid higher'));
    await tester.pump();
    expect(taps, ['accept', 'reject', 'bid']);
    await disposeTree(tester);
  });
}
