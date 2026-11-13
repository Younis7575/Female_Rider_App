import 'package:femalerider/core/config/app_config.dart';
import 'package:femalerider/features/account/domain/account_models.dart';
import 'package:femalerider/features/auth/domain/user.dart';
import 'package:femalerider/features/driver/domain/driver_models.dart';
import 'package:femalerider/features/rides/domain/ride_models.dart';
import 'package:femalerider/features/trips/domain/trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

// Fixtures captured from the local API (trimmed).
final configJson = {
  'app': {'name': 'FemaleRider', 'min_supported_version': '1.0.0', 'latest_version': '1.0.0', 'maintenance_mode': false, 'maintenance_message': 'Back soon'},
  'currency': 'PKR',
  'default_country_code': '+92',
  'countries': [
    {'code': '+92', 'iso': 'PK', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+971', 'iso': 'AE', 'name': 'United Arab Emirates', 'flag': '🇦🇪'},
  ],
  'otp': {'length': 6, 'resend_seconds': 60},
  'vehicle_categories': [
    {'id': 1, 'name': 'FemaleRider Bike', 'slug': 'bike', 'icon': 'bike', 'capacity': 1, 'description': 'Quick'},
    {'id': 3, 'name': 'FemaleRider Mini', 'slug': 'mini', 'icon': 'car', 'capacity': 4, 'description': 'AC car'},
  ],
  'cancel_reasons': {
    'customer': ['Driver is too far', 'Other'],
    'driver': ['Customer not at pickup', 'Other'],
  },
  'rating_tags': {
    'customer': ['Safe driving', 'Rude'],
    'driver': ['Polite', 'Late'],
  },
  'location': {'online_interval_seconds': 10, 'trip_interval_seconds': 4, 'idle_interval_seconds': 30, 'max_accuracy_m': 100, 'max_speed_kmh': 160},
  'trip': {'pin_length': 4},
  'dispatch': {'request_ttl_seconds': 180, 'offer_ttl_seconds': 45},
  'support': {'hours': 'Daily 08:00–23:00 PKT', 'phone': '+92-000-0000000', 'email': 'support@femalerider.example'},
  'realtime': {'driver': 'reverb', 'key': 'oldecmpqmsd2r2r1kivs', 'host': '', 'port': 8080, 'scheme': 'http', 'auth_endpoint': '/api/v1/broadcasting/auth'},
  'documents': {
    'required': ['cnic_front', 'cnic_back'],
    'optional': ['insurance'],
  },
  'legal': {'terms_url': 'http://127.0.0.1:8000/terms', 'privacy_url': 'http://127.0.0.1:8000/privacy', 'eligibility_policy_url': 'http://127.0.0.1:8000/eligibility-policy'},
};

final tripJson = {
  'id': '098a3fa1-2c29-44e9-8d27-59890021297e',
  'ride_id': 'c4922445-4304-49d1-ab1f-aa0c03135e95',
  'status': 'driver_en_route',
  'status_label': 'Driver en route',
  'viewer_role': 'customer',
  'pickup': {'lat': 24.8607, 'lng': 67.0011, 'address': 'Saddar, Karachi', 'note': 'Gate 2'},
  'dropoff': {'lat': 24.8021, 'lng': 67.03, 'address': 'Dolmen Mall Clifton, Karachi'},
  'distance_m': 9281,
  'duration_s': 1519,
  'polyline': null,
  'pickup_pin': '4821',
  'agreed_fare': '650.00',
  'final_fare': null,
  'amount_due': null,
  'discount_amount': 0,
  'cancellation_fee': 0,
  'commission_amount': null,
  'driver_earning': null,
  'fare_breakdown': null,
  'currency': 'PKR',
  'payment_method': 'cash',
  'payment_status': 'pending',
  'vehicle_category': 'FemaleRider Mini',
  'driver': {'id': 'ee290571', 'first_name': 'Sana', 'photo_url': null, 'rating': 5, 'rating_count': 1, 'completed_trips': 1},
  'customer': {'id': 'e25c5bae', 'first_name': 'Ayesha', 'photo_url': null, 'rating': 5, 'rating_count': 0},
  'vehicle': {'id': 1, 'make': 'Toyota', 'model': 'Yaris', 'color': 'White', 'year': 2022, 'plate_number': 'KHI-2026', 'capacity': 4, 'status': 'approved', 'vehicle_category_id': 3},
  'driver_location': {'lat': 24.85, 'lng': 67.0, 'heading': 90.0, 'ts': 1794000000},
  'my_rating': null,
  'timeline': {'assigned_at': '2026-11-13T11:23:34+00:00', 'en_route_at': '2026-11-13T11:24:00+00:00', 'arrived_at': null, 'started_at': null, 'completed_at': null, 'cancelled_at': null},
  'cancelled_by': null,
  'cancel_reason': null,
  'share': {'url': 'http://127.0.0.1:8000/t/abc', 'expires_at': '2026-11-13T17:23:34+00:00'},
  'created_at': '2026-11-13T11:23:34+00:00',
};

void main() {
  test('AppConfig.fromJson parses bootstrap config', () {
    final c = AppConfig.fromJson(configJson);
    expect(c.currency, 'PKR');
    expect(c.countries, hasLength(2));
    expect(c.defaultCountry.code, '+92');
    expect(c.otpLength, 6);
    expect(c.vehicleCategories.map((e) => e.slug), ['bike', 'mini']);
    expect(c.categoryById(3)!.capacity, 4);
    expect(c.customerCancelReasons.first, 'Driver is too far');
    expect(c.driverRatingTags, ['Polite', 'Late']);
    expect(c.location.trip, 4);
    expect(c.pinLength, 4);
    expect(c.realtime!.key, 'oldecmpqmsd2r2r1kivs');
    expect(c.realtime!.host, '');
    expect(c.requiredDocuments, ['cnic_front', 'cnic_back']);
    expect(c.termsUrl, contains('/terms'));
  });

  test('compareVersions', () {
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
  });

  test('MeResult / AppUser parse capabilities and realtime channels', () {
    final me = MeResult.fromJson({
      'user': userJson(mode: 'driver', driverMode: true, driverStatus: 'approved'),
      'active_trip_id': 'trip-1',
      'active_ride_id': null,
      'unread_notifications': 3,
    });
    expect(me.user.isDriverMode, isTrue);
    expect(me.user.canUseDriverMode, isTrue);
    expect(me.user.eligibility.isApproved, isTrue);
    expect(me.user.userChannel, 'private-user.1');
    expect(me.user.driverChannel, 'private-driver.1');
    expect(me.user.firstName, 'Ayesha');
    expect(me.activeTripId, 'trip-1');
    expect(me.unreadNotifications, 3);
    expect(me.user.notificationPreferences['push'], isTrue);
  });

  test('Trip.fromJson handles string decimals, PIN, driver location and share', () {
    final t = Trip.fromJson(tripJson);
    expect(t.isActive, isTrue);
    expect(t.agreedFare, 650);
    expect(t.displayFare, 650);
    expect(t.pickupPin, '4821');
    expect(t.pickupNote, 'Gate 2');
    expect(t.vehicle!.plateNumber, 'KHI-2026');
    expect(t.vehicle!.title, 'White Toyota Yaris');
    expect(t.driverLocation!.lat, 24.85);
    expect(t.driverLocation!.at, isNotNull);
    expect(t.timeline.enRouteAt, isNotNull);
    expect(t.shareUrl, contains('/t/abc'));
    expect(t.fareBreakdown, isEmpty);
  });

  test('RideRequest + RideOffer parse negotiation state', () {
    final r = RideRequest.fromJson({
      'id': 'ride-1',
      'status': 'offers_available',
      'pickup': {'lat': 24.86, 'lng': 67.0, 'address': 'Saddar'},
      'dropoff': {'lat': 24.80, 'lng': 67.03, 'address': 'Clifton'},
      'suggested_fare': 425,
      'min_fare': 300,
      'max_fare': 1065,
      'proposed_fare': '450',
      'vehicle_category': {'id': 2, 'name': 'FemaleRider Rickshaw', 'icon': 'rickshaw'},
      'drivers_notified': 4,
      'expires_at': DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
      'offers': [
        {
          'id': 7,
          'ride_id': 'ride-1',
          'amount': 500,
          'proposed_by': 'driver',
          'status': 'pending',
          'sequence': 1,
          'eta_s': 240,
          'distance_to_pickup_m': 1200,
          'expires_at': DateTime.now().add(const Duration(seconds: 40)).toIso8601String(),
          'driver': {'id': 'd1', 'first_name': 'Sana', 'photo_url': null, 'rating': 4.8, 'completed_trips': 120},
          'vehicle': {'make': 'Suzuki', 'model': 'Alto', 'color': 'Red', 'plate_number': 'LEA-11'},
        },
      ],
    });
    expect(r.isOpen, isTrue);
    expect(r.proposedFare, 450);
    expect(r.categoryId, 2);
    expect(r.driversNotified, 4);
    final o = r.offers.single;
    expect(o.byDriver, isTrue);
    expect(o.isPending, isTrue);
    expect(o.driver!.completedTrips, 120);
    expect(o.vehicle!.title, 'Red Suzuki Alto');
  });

  test('CreateRideInput serialises the POST /rides contract', () {
    final j = const CreateRideInput(
      categoryId: 3,
      pickup: Place(name: 'Saddar', address: 'Saddar, Karachi', lat: 24.86, lng: 67.0),
      dropoff: Place(name: 'Dolmen', address: '', lat: 24.80, lng: 67.03),
      proposedFare: 650,
      pickupNote: '  Gate 2 ',
      couponCode: '',
    ).toJson();
    expect(j['vehicle_category_id'], 3);
    expect(j['dropoff_address'], 'Dolmen');
    expect(j['pickup_note'], 'Gate 2');
    expect(j.containsKey('coupon_code'), isFalse);
    expect(j['payment_method'], 'cash');
  });

  test('FareEstimate parses options', () {
    final e = FareEstimate.fromJson({
      'distance_m': 9281,
      'duration_s': 1519,
      'polyline': null,
      'service_zone': {'id': 1, 'name': 'Karachi Metro', 'city': 'Karachi'},
      'options': [
        {
          'vehicle_category': {'id': 1, 'name': 'Bike', 'slug': 'bike', 'capacity': 1},
          'suggested_fare': 290,
          'min_fare': 205,
          'max_fare': 725,
          'surge_multiplier': 1,
          'currency': 'PKR',
          'breakdown': {'base_fare': 60},
        },
      ],
    });
    expect(e.city, 'Karachi');
    expect(e.options.single.minFare, 205);
    expect(e.options.single.category.slug, 'bike');
  });

  test('DriverRequest exposes my offer / customer counter state', () {
    Map<String, dynamic> req(Map<String, dynamic>? myOffer) => {
          'id': 'ride-9',
          'status': 'searching',
          'pickup': {'lat': 24.8607, 'lng': 67.0011, 'address': 'Saddar'},
          'dropoff_area': 'Clifton',
          'pickup_distance_m': 800,
          'pickup_eta_s': 180,
          'proposed_fare': 400,
          'min_fare': 300,
          'max_fare': 1000,
          'customer': {'first_name': 'Ayesha', 'rating': 5, 'rides': 3},
          'expires_at': DateTime.now().add(const Duration(minutes: 1)).toIso8601String(),
          'my_offer': myOffer,
        };
    final future = DateTime.now().add(const Duration(seconds: 30)).toIso8601String();
    final none = DriverRequest.fromJson(req(null));
    expect(none.hasPendingOffer, isFalse);
    expect(none.customerFirstName, 'Ayesha');
    expect(none.dropoffArea, 'Clifton');
    final mine = DriverRequest.fromJson(req({'id': 1, 'amount': 450, 'proposed_by': 'driver', 'status': 'pending', 'expires_at': future}));
    expect(mine.hasPendingOffer, isTrue);
    final counter = DriverRequest.fromJson(req({'id': 2, 'amount': 420, 'proposed_by': 'customer', 'status': 'pending', 'expires_at': future}));
    expect(counter.hasCustomerCounter, isTrue);
  });

  test('DriverProfile / dashboard / ledger parse', () {
    final p = DriverProfile.fromJson({
      'status': 'more_info_required',
      'status_label': 'More information required',
      'reason': 'Licence photo is blurry',
      'full_name': 'Sana Malik',
      'cnic_number_masked': '•••98-5',
      'license_number_masked': '••9541',
      'payout': {'method': 'jazzcash', 'account_title': 'Sana', 'account_number_masked': '••5053'},
      'vehicle': {'id': 1, 'make': 'Toyota', 'model': 'Yaris', 'category': {'id': 3, 'name': 'Mini', 'slug': 'mini'}},
      'documents': [
        {'id': 1, 'type': 'cnic_front', 'label': 'Cnic Front', 'status': 'approved'},
        {'id': 2, 'type': 'cnic_back', 'label': 'Cnic Back', 'status': 'rejected', 'rejection_reason': 'Blurry'},
      ],
      'required_documents': ['cnic_front', 'cnic_back', 'license_front'],
      'compliance_issues': ['Vehicle is not approved.'],
      'can_edit': true,
    });
    expect(p.personalComplete, isTrue);
    expect(p.vehicle!.categoryId, 3);
    expect(p.payout.isSet, isTrue);
    expect(p.missingRequiredDocuments, ['cnic_back', 'license_front']);
    expect(p.documentFor('cnic_back')!.rejectionReason, 'Blurry');

    final d = DriverDashboard.fromJson({
      'is_online': true,
      'today': {'completed_trips': 1, 'net_earnings': 552.5, 'online_hours': 1.5},
      'week': {'completed_trips': 4},
      'balance': -97.5,
      'available_for_payout': 0,
      'expiring_documents': [
        {'type': 'insurance', 'label': 'Insurance', 'expiry_date': '2026-12-01'},
      ],
    });
    expect(d.isOnline, isTrue);
    expect(d.today.netEarnings, 552.5);
    expect(d.balance, -97.5);
    expect(d.expiringDocuments.single.type, 'insurance');

    final l = LedgerEntry.fromJson({'id': 2, 'type': 'trip_fare', 'direction': 'credit', 'amount': 650, 'trip_id': 't1'});
    expect(l.isCredit, isTrue);
  });

  test('VerificationState includes policy summary', () {
    final v = VerificationState.fromJson({
      'status': 'rejected',
      'label': 'Rejected',
      'reason': 'Document unreadable',
      'can_submit': true,
      'can_appeal': true,
      'policy': {'version': '1.0', 'accepted_documents': ['cnic', 'passport'], 'require_selfie': false, 'summary': 'FemaleRider is a women-only community.'},
    });
    expect(v.canAppeal, isTrue);
    expect(v.acceptedDocuments, ['cnic', 'passport']);
    expect(v.policySummary, startsWith('FemaleRider'));
  });
}
