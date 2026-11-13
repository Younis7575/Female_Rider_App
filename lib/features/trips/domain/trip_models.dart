import '../../../core/network/json.dart';
import '../../../core/utils/polyline.dart';
import '../../rides/domain/ride_models.dart';

class TripPerson {
  const TripPerson({required this.id, required this.firstName, this.photoUrl, this.rating = 0, this.ratingCount = 0, this.completedTrips});
  final String id;
  final String firstName;
  final String? photoUrl;
  final double rating;
  final int ratingCount;
  final int? completedTrips;

  factory TripPerson.fromJson(Json j) => TripPerson(
        id: asString(j['id']),
        firstName: asString(j['first_name']),
        photoUrl: asStringOrNull(j['photo_url']),
        rating: asDouble(j['rating']),
        ratingCount: asInt(j['rating_count']),
        completedTrips: asIntOrNull(j['completed_trips']),
      );
}

/// `VehicleResource`.
class Vehicle {
  const Vehicle({
    this.id,
    this.make,
    this.model,
    this.color,
    this.year,
    this.plateNumber,
    this.capacity,
    this.status,
    this.rejectionReason,
    this.registrationExpiry,
    this.insuranceExpiry,
    this.categoryId,
    this.categoryName,
  });
  final int? id;
  final String? make;
  final String? model;
  final String? color;
  final int? year;
  final String? plateNumber;
  final int? capacity;
  final String? status;
  final String? rejectionReason;
  final String? registrationExpiry;
  final String? insuranceExpiry;
  final int? categoryId;
  final String? categoryName;

  String get title => [color, make, model].whereType<String>().where((e) => e.isNotEmpty).join(' ');

  factory Vehicle.fromJson(Json j) {
    final cat = asMapOrNull(j['category']);
    return Vehicle(
      id: asIntOrNull(j['id']),
      make: asStringOrNull(j['make']),
      model: asStringOrNull(j['model']),
      color: asStringOrNull(j['color']),
      year: asIntOrNull(j['year']),
      plateNumber: asStringOrNull(j['plate_number']),
      capacity: asIntOrNull(j['capacity']),
      status: asStringOrNull(j['status']),
      rejectionReason: asStringOrNull(j['rejection_reason']),
      registrationExpiry: asStringOrNull(j['registration_expiry']),
      insuranceExpiry: asStringOrNull(j['insurance_expiry']),
      categoryId: asIntOrNull(j['vehicle_category_id']) ?? (cat == null ? null : asIntOrNull(cat['id'])),
      categoryName: cat == null ? null : asStringOrNull(cat['name']),
    );
  }
}

class DriverLocation {
  const DriverLocation({required this.lat, required this.lng, this.heading, this.etaS, this.distanceM, this.at});
  final double lat;
  final double lng;
  final double? heading;
  final int? etaS;
  final int? distanceM;
  final DateTime? at;
  GeoPoint get point => GeoPoint(lat, lng);

  factory DriverLocation.fromJson(Json j) => DriverLocation(
        lat: asDouble(j['lat']),
        lng: asDouble(j['lng']),
        heading: asDoubleOrNull(j['heading']),
        etaS: asIntOrNull(j['pickup_eta_s']),
        distanceM: asIntOrNull(j['pickup_distance_m']),
        at: asDate(j['recorded_at']) ?? (j['ts'] != null ? DateTime.fromMillisecondsSinceEpoch(asInt(j['ts']) * 1000) : null),
      );
}

class TripTimeline {
  const TripTimeline({this.assignedAt, this.enRouteAt, this.arrivedAt, this.startedAt, this.completedAt, this.cancelledAt});
  final DateTime? assignedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  factory TripTimeline.fromJson(Json j) => TripTimeline(
        assignedAt: asDate(j['assigned_at']),
        enRouteAt: asDate(j['en_route_at']),
        arrivedAt: asDate(j['arrived_at']),
        startedAt: asDate(j['started_at']),
        completedAt: asDate(j['completed_at']),
        cancelledAt: asDate(j['cancelled_at']),
      );
}

/// `TripResource.cancellation_policy` (null when the trip is not active).
class CancellationPolicy {
  const CancellationPolicy({this.fee = 0, this.freeWindowSeconds, this.freeUntil, this.feeAppliesNow = false});
  final double fee;
  final int? freeWindowSeconds;
  final DateTime? freeUntil;
  final bool feeAppliesNow;

  /// Server flag, refined locally once the free window has passed.
  bool get feeAppliesAt => feeAppliesNow || (fee > 0 && freeUntil != null && DateTime.now().isAfter(freeUntil!));

  factory CancellationPolicy.fromJson(Json j) => CancellationPolicy(
        fee: asDouble(j['fee']),
        freeWindowSeconds: asIntOrNull(j['free_window_seconds']),
        freeUntil: asDate(j['free_until']),
        feeAppliesNow: asBool(j['fee_applies_now']),
      );
}

abstract final class TripStatus {
  static const assigned = 'driver_assigned';
  static const enRoute = 'driver_en_route';
  static const arrived = 'arrived';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const safetyHold = 'safety_hold';
  static const disputed = 'disputed';

  static const active = [assigned, enRoute, arrived, inProgress, safetyHold];
  static bool isCancelled(String s) => s.startsWith('cancelled');
}

/// `TripResource` (shape depends on viewer role).
class Trip {
  const Trip({
    required this.id,
    required this.rideId,
    required this.status,
    required this.statusLabel,
    this.viewerRole,
    required this.pickup,
    required this.dropoff,
    this.pickupNote,
    this.distanceM,
    this.durationS,
    this.polyline,
    this.pickupPin,
    this.agreedFare = 0,
    this.finalFare,
    this.amountDue,
    this.discountAmount = 0,
    this.cancellationFee = 0,
    this.commissionAmount,
    this.driverEarning,
    this.fareBreakdown = const {},
    this.currency = 'PKR',
    this.paymentMethod = 'cash',
    this.paymentStatus,
    this.vehicleCategory,
    this.vehicleCategorySlug,
    this.cancellationPolicy,
    required this.driver,
    required this.customer,
    this.vehicle,
    this.driverLocation,
    this.myRating,
    this.timeline = const TripTimeline(),
    this.cancelledBy,
    this.cancelReason,
    this.shareUrl,
    this.shareExpiresAt,
    this.createdAt,
    this.chatEnabled = false,
    this.chatUnread = 0,
  });

  final String id;
  final String rideId;
  final String status;
  final String statusLabel;
  final String? viewerRole;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final String? pickupNote;
  final int? distanceM;
  final int? durationS;
  final String? polyline;
  final String? pickupPin;
  final double agreedFare;
  final double? finalFare;
  final double? amountDue;
  final double discountAmount;
  final double cancellationFee;
  final double? commissionAmount;
  final double? driverEarning;
  final Json fareBreakdown;
  final String currency;
  final String paymentMethod;
  final String? paymentStatus;
  final String? vehicleCategory;
  final String? vehicleCategorySlug;
  final CancellationPolicy? cancellationPolicy;
  final TripPerson driver;
  final TripPerson customer;
  final Vehicle? vehicle;
  final DriverLocation? driverLocation;
  final int? myRating;
  final TripTimeline timeline;
  final String? cancelledBy;
  final String? cancelReason;
  final String? shareUrl;
  final DateTime? shareExpiresAt;
  final DateTime? createdAt;

  /// Customer ⇄ driver chat: writable while the trip is active.
  final bool chatEnabled;
  final int chatUnread;

  bool get isActive => TripStatus.active.contains(status);
  bool get isCompleted => status == TripStatus.completed;
  bool get isCancelled => TripStatus.isCancelled(status);
  bool get isDriverView => viewerRole == 'driver';
  bool get isCashPaid => paymentStatus == 'paid';
  double get displayFare => finalFare ?? agreedFare;

  Trip copyWith({String? status, String? statusLabel, DriverLocation? driverLocation}) => Trip(
        id: id,
        rideId: rideId,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        viewerRole: viewerRole,
        pickup: pickup,
        dropoff: dropoff,
        pickupNote: pickupNote,
        distanceM: distanceM,
        durationS: durationS,
        polyline: polyline,
        pickupPin: pickupPin,
        agreedFare: agreedFare,
        finalFare: finalFare,
        amountDue: amountDue,
        discountAmount: discountAmount,
        cancellationFee: cancellationFee,
        commissionAmount: commissionAmount,
        driverEarning: driverEarning,
        fareBreakdown: fareBreakdown,
        currency: currency,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        vehicleCategory: vehicleCategory,
        vehicleCategorySlug: vehicleCategorySlug,
        cancellationPolicy: cancellationPolicy,
        driver: driver,
        customer: customer,
        vehicle: vehicle,
        driverLocation: driverLocation ?? this.driverLocation,
        myRating: myRating,
        timeline: timeline,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        shareUrl: shareUrl,
        shareExpiresAt: shareExpiresAt,
        createdAt: createdAt,
        chatEnabled: chatEnabled,
        chatUnread: chatUnread,
      );

  factory Trip.fromJson(Json j) {
    final pickup = asMap(j['pickup']);
    final share = asMapOrNull(j['share']);
    return Trip(
      id: asString(j['id']),
      rideId: asString(j['ride_id']),
      status: asString(j['status']),
      statusLabel: asString(j['status_label'], asString(j['status'])),
      viewerRole: asStringOrNull(j['viewer_role']),
      pickup: LocationPoint.fromJson(pickup),
      dropoff: LocationPoint.fromJson(asMap(j['dropoff'])),
      pickupNote: asStringOrNull(pickup['note']),
      distanceM: asIntOrNull(j['distance_m']),
      durationS: asIntOrNull(j['duration_s']),
      polyline: asStringOrNull(j['polyline']),
      pickupPin: asStringOrNull(j['pickup_pin']),
      agreedFare: asDouble(j['agreed_fare']),
      finalFare: asDoubleOrNull(j['final_fare']),
      amountDue: asDoubleOrNull(j['amount_due']),
      discountAmount: asDouble(j['discount_amount']),
      cancellationFee: asDouble(j['cancellation_fee']),
      commissionAmount: asDoubleOrNull(j['commission_amount']),
      driverEarning: asDoubleOrNull(j['driver_earning']),
      fareBreakdown: asMap(j['fare_breakdown']),
      currency: asString(j['currency'], 'PKR'),
      paymentMethod: asString(j['payment_method'], 'cash'),
      paymentStatus: asStringOrNull(j['payment_status']),
      vehicleCategory: asStringOrNull(j['vehicle_category']),
      vehicleCategorySlug: asStringOrNull(j['vehicle_category_slug']),
      cancellationPolicy: j['cancellation_policy'] is Map ? CancellationPolicy.fromJson(asMap(j['cancellation_policy'])) : null,
      driver: TripPerson.fromJson(asMap(j['driver'])),
      customer: TripPerson.fromJson(asMap(j['customer'])),
      vehicle: j['vehicle'] is Map ? Vehicle.fromJson(asMap(j['vehicle'])) : null,
      driverLocation: j['driver_location'] is Map ? DriverLocation.fromJson(asMap(j['driver_location'])) : null,
      myRating: asIntOrNull(j['my_rating']),
      timeline: TripTimeline.fromJson(asMap(j['timeline'])),
      cancelledBy: asStringOrNull(j['cancelled_by']),
      cancelReason: asStringOrNull(j['cancel_reason']),
      shareUrl: share == null ? null : asStringOrNull(share['url']),
      shareExpiresAt: share == null ? null : asDate(share['expires_at']),
      createdAt: asDate(j['created_at']),
      chatEnabled: asBool(asMap(j['chat'])['enabled']),
      chatUnread: asInt(asMap(j['chat'])['unread']),
    );
  }
}

/// `GET /trips/{id}/receipt`.
class Receipt {
  const Receipt({
    required this.receiptNumber,
    required this.tripId,
    this.date,
    this.from,
    this.to,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.vehicleCategory,
    this.driverFirstName,
    this.vehiclePlate,
    this.fareBreakdown = const {},
    this.total = 0,
    this.discount = 0,
    this.amountPaid = 0,
    this.currency = 'PKR',
    this.paymentMethod = 'cash',
    this.paymentStatus,
    this.refundableAmount,
  });
  final String receiptNumber;
  final String tripId;
  final DateTime? date;
  final String? from;
  final String? to;
  final double distanceKm;
  final int durationMin;
  final String? vehicleCategory;
  final String? driverFirstName;
  final String? vehiclePlate;
  final Json fareBreakdown;
  final double total;
  final double discount;
  final double amountPaid;
  final String currency;
  final String paymentMethod;
  final String? paymentStatus;

  /// Remaining refundable amount (caps refund requests).
  final double? refundableAmount;

  factory Receipt.fromJson(Json j) => Receipt(
        receiptNumber: asString(j['receipt_number']),
        tripId: asString(j['trip_id']),
        date: asDate(j['date']),
        from: asStringOrNull(j['from']),
        to: asStringOrNull(j['to']),
        distanceKm: asDouble(j['distance_km']),
        durationMin: asInt(j['duration_min']),
        vehicleCategory: asStringOrNull(j['vehicle_category']),
        driverFirstName: asStringOrNull(j['driver_first_name']),
        vehiclePlate: asStringOrNull(j['vehicle_plate']),
        fareBreakdown: asMap(j['fare_breakdown']),
        total: asDouble(j['total']),
        discount: asDouble(j['discount']),
        amountPaid: asDouble(j['amount_paid']),
        currency: asString(j['currency'], 'PKR'),
        paymentMethod: asString(j['payment_method'], 'cash'),
        paymentStatus: asStringOrNull(j['payment_status']),
        refundableAmount: asDoubleOrNull(j['refundable_amount']),
      );
}

class SosResult {
  const SosResult({required this.emergencyNumber, this.supportHours, this.reference, this.message});
  final String emergencyNumber;
  final String? supportHours;
  final String? reference;
  final String? message;
}
