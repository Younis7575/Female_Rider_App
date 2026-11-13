import 'package:femalerider/core/widgets/buttons.dart';
import 'package:femalerider/core/widgets/fare_stepper.dart';
import 'package:femalerider/features/rides/domain/ride_models.dart';
import 'package:femalerider/features/rides/presentation/widgets/offer_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/harness.dart';

/// Stateful host so the stepper can be driven like in the app.
class _StepperHost extends StatefulWidget {
  const _StepperHost({required this.initial, required this.log});
  final double initial;
  final List<double> log;
  @override
  State<_StepperHost> createState() => _StepperHostState();
}

class _StepperHostState extends State<_StepperHost> {
  late double v = widget.initial;
  @override
  Widget build(BuildContext context) => FareStepper(
        min: 205,
        max: 725,
        suggested: 290,
        value: v,
        onChanged: (n) {
          widget.log.add(n);
          setState(() => v = n);
        },
      );
}

RideOffer _offer({String proposedBy = 'driver', int id = 7}) => RideOffer.fromJson({
      'id': id,
      'ride_id': 'ride-1',
      'amount': 500,
      'proposed_by': proposedBy,
      'status': 'pending',
      'eta_s': 240,
      'distance_to_pickup_m': 1200,
      'expires_at': DateTime.now().add(const Duration(seconds: 40)).toIso8601String(),
      'driver': {'id': 'd1', 'first_name': 'Sana', 'photo_url': null, 'rating': 4.8, 'completed_trips': 120},
      'vehicle': {'make': 'Suzuki', 'model': 'Alto', 'color': 'Red', 'plate_number': 'LEA-11'},
    });

void main() {
  group('FareStepper bounds', () {
    testWidgets('steps by 5 and never goes below min / above max', (tester) async {
      final log = <double>[];
      await pumpPlain(tester, _StepperHost(initial: 210, log: log));
      expect(find.text('PKR 210'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fare-inc')));
      await tester.pump();
      expect(find.text('PKR 215'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fare-dec')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fare-dec')));
      await tester.pump();
      expect(find.text('PKR 205'), findsOneWidget);

      // At min: decrement disabled, value unchanged.
      final before = log.length;
      await tester.tap(find.byKey(const ValueKey('fare-dec')));
      await tester.pump();
      expect(log.length, before);
      expect(find.text('Min PKR 205'), findsOneWidget);
      expect(find.text('Max PKR 725'), findsOneWidget);
      expect(find.textContaining('below recommended'), findsOneWidget);
    });

    testWidgets('long-press jumps by 50 and clamps at max', (tester) async {
      final log = <double>[];
      await pumpPlain(tester, _StepperHost(initial: 700, log: log));
      await tester.longPress(find.byKey(const ValueKey('fare-inc')));
      await tester.pump();
      expect(find.text('PKR 725'), findsOneWidget);
      expect(log.last, 725);
      await tester.tap(find.byKey(const ValueKey('fare-inc')));
      await tester.pump();
      expect(log.last, 725);
      expect(log.every((v) => v >= 205 && v <= 725), isTrue);
    });

    testWidgets('initial value outside bounds is displayed clamped', (tester) async {
      await pumpPlain(tester, FareStepper(min: 300, max: 1000, value: 50, onChanged: (_) {}));
      expect(find.text('PKR 300'), findsOneWidget);
    });

    testWidgets('showFareSheet returns the chosen in-bounds amount', (tester) async {
      double? result;
      await pumpPlain(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'open',
            onPressed: () async => result = await showFareSheet(context, title: 'Counter offer', min: 300, max: 400, initial: 395),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fare-inc')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fare-inc'))); // clamped at 400
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fare-sheet-confirm')));
      await tester.pumpAndSettle();
      expect(result, 400);
    });
  });

  group('OfferCard', () {
    testWidgets('renders driver details and fires Accept / Decline / Counter', (tester) async {
      final taps = <String>[];
      await pumpPlain(
        tester,
        OfferCard(
          offer: _offer(),
          currency: 'PKR',
          onAccept: () => taps.add('accept'),
          onDecline: () => taps.add('decline'),
          onCounter: () => taps.add('counter'),
        ),
      );
      expect(find.text('Sana'), findsOneWidget);
      expect(find.textContaining('PKR 500'), findsWidgets);
      expect(find.textContaining('LEA-11'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('offer-accept-7')));
      await tester.tap(find.byKey(const ValueKey('offer-decline-7')));
      await tester.tap(find.byKey(const ValueKey('offer-counter-7')));
      await tester.pump();
      expect(taps, ['accept', 'decline', 'counter']);
      await disposeTree(tester);
    });

    testWidgets('busy disables all actions', (tester) async {
      final taps = <String>[];
      await pumpPlain(
        tester,
        OfferCard(offer: _offer(), currency: 'PKR', busy: true, onAccept: () => taps.add('a'), onDecline: () => taps.add('d'), onCounter: () => taps.add('c')),
      );
      await tester.tap(find.byKey(const ValueKey('offer-accept-7')), warnIfMissed: false);
      await tester.tap(find.byKey(const ValueKey('offer-decline-7')), warnIfMissed: false);
      await tester.tap(find.byKey(const ValueKey('offer-counter-7')), warnIfMissed: false);
      await tester.pump();
      expect(taps, isEmpty);
      await disposeTree(tester);
    });

    testWidgets('my own counter shows waiting state without actions', (tester) async {
      await pumpPlain(tester, OfferCard(offer: _offer(proposedBy: 'customer', id: 8), currency: 'PKR', onAccept: () {}, onDecline: () {}, onCounter: () {}));
      expect(find.text('Waiting for driver…'), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-accept-8')), findsNothing);
      expect(find.byKey(const ValueKey('offer-counter-8')), findsNothing);
      await disposeTree(tester);
    });
  });
}
