import 'package:femalerider/core/config/app_config.dart';
import 'package:femalerider/features/account/domain/account_models.dart';
import 'package:femalerider/features/driver/domain/driver_models.dart';
import 'package:femalerider/features/rides/domain/ride_models.dart';
import 'package:femalerider/features/trips/domain/trip_models.dart';
import 'package:femalerider/features/trips/presentation/widgets/trip_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'models_test.dart' show tripJson;

Trip _trip(Map<String, dynamic>? policy, {String status = 'driver_assigned'}) =>
    Trip.fromJson({...tripJson, 'status': status, 'cancellation_policy': policy, 'vehicle_category_slug': 'mini'});

void main() {
  group('cancellation policy', () {
    final freeUntil = DateTime.utc(2026, 11, 13, 12, 0);

    test('parses TripResource.cancellation_policy and vehicle_category_slug', () {
      final t = _trip({'fee': 100, 'free_window_seconds': 120, 'free_until': freeUntil.toIso8601String(), 'fee_applies_now': false});
      expect(t.vehicleCategorySlug, 'mini');
      expect(t.cancellationPolicy!.fee, 100);
      expect(t.cancellationPolicy!.freeWindowSeconds, 120);
      expect(t.cancellationPolicy!.freeUntil, freeUntil.toLocal());
      expect(_trip(null).cancellationPolicy, isNull);
    });

    test('fee applies now -> "Cancellation fee PKR X applies"', () {
      final t = _trip({'fee': 150, 'free_window_seconds': 120, 'free_until': freeUntil.toIso8601String(), 'fee_applies_now': true});
      expect(cancellationWarning(t, freeCancelSeconds: 120, now: freeUntil.subtract(const Duration(minutes: 1))), 'Cancellation fee PKR 150 applies.');
    });

    test('inside free window -> "Free cancellation until HH:MM"', () {
      final t = _trip({'fee': 150, 'free_window_seconds': 120, 'free_until': freeUntil.toIso8601String(), 'fee_applies_now': false});
      final w = cancellationWarning(t, freeCancelSeconds: 120, now: freeUntil.toLocal().subtract(const Duration(seconds: 30)))!;
      expect(w, startsWith('Free cancellation until '));
      expect(w, contains('PKR 150 applies after that'));
      // Window passes while the dialog data is cached -> fee message.
      expect(cancellationWarning(t, freeCancelSeconds: 120, now: freeUntil.toLocal().add(const Duration(seconds: 1))), 'Cancellation fee PKR 150 applies.');
    });

    test('zero-fee category never warns about a fee', () {
      final t = _trip({'fee': 0, 'free_window_seconds': 120, 'free_until': freeUntil.toIso8601String(), 'fee_applies_now': true});
      expect(cancellationWarning(t, freeCancelSeconds: 120), isNull);
    });

    test('config exposes customer_free_cancel_seconds', () {
      expect(AppConfig.fromJson({'trip': {'pin_length': 4, 'customer_free_cancel_seconds': 90}}).customerFreeCancelSeconds, 90);
      expect(AppConfig.fromJson({}).customerFreeCancelSeconds, 120);
    });
  });

  test('DriverStatement parses GET /driver/statements', () {
    final s = DriverStatement.fromJson({
      'month': '2026-11',
      'period': {'from': '2026-11-01', 'to': '2026-11-30'},
      'currency': 'PKR',
      'summary': {
        'completed_trips': 2,
        'cancelled_trips': 0,
        'gross_fares': 1350,
        'commission': 202.5,
        'net_earnings': 1147.5,
        'cash_collected': 1350,
        'payouts_paid': 500,
        'opening_balance': 0,
        'closing_balance': -202.5,
      },
      'trips': [
        {'id': 't1', 'completed_at': '2026-11-13T11:23:34+00:00', 'from': 'Saddar', 'to': 'Clifton', 'fare': 650, 'commission': 97.5, 'earning': 552.5, 'payment_method': 'cash'},
      ],
      'payouts': [
        {'id': 'p1', 'amount': '500.00', 'paid_at': '2026-11-10T09:00:00+00:00', 'reference': 'JC-123'},
      ],
    });
    expect(s.month, '2026-11');
    expect(s.from, DateTime(2026, 11, 1));
    expect(s.summary.payoutsPaid, 500);
    expect(s.summary.closingBalance, -202.5);
    expect(s.trips.single.earning, 552.5);
    expect(s.payouts.single.amount, 500);
    expect(s.payouts.single.reference, 'JC-123');
  });

  test('receipt refundable_amount, ride category slug, ticket attachments', () {
    expect(Receipt.fromJson({'receipt_number': 'FR-1', 'trip_id': 't', 'refundable_amount': 300}).refundableAmount, 300);
    final r = RideRequest.fromJson({
      'id': 'r',
      'status': 'searching',
      'pickup': {'lat': 1, 'lng': 1},
      'dropoff': {'lat': 2, 'lng': 2},
      'vehicle_category': {'id': 3, 'name': 'Mini', 'slug': 'mini', 'icon': 'car'},
      'drivers_notified': 5,
    });
    expect(r.categorySlug, 'mini');
    expect(r.driversNotified, 5);
    expect(TicketMessage.fromJson({'id': 1, 'from': 'me', 'body': 'x', 'has_attachment': true}).hasAttachment, isTrue);
  });

  test('ride.updated payload with my_offer is parsed', () {
    final r = DriverRequest.fromJson({
      'id': 'r',
      'status': 'offers_available',
      'pickup': {'lat': 1, 'lng': 1},
      'expires_at': DateTime.now().add(const Duration(minutes: 1)).toIso8601String(),
      'my_offer': {'id': 9, 'amount': 450, 'proposed_by': 'driver', 'status': 'pending', 'expires_at': DateTime.now().add(const Duration(seconds: 30)).toIso8601String()},
    });
    expect(r.hasPendingOffer, isTrue);
  });
}
