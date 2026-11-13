import '../../../core/config/app_config.dart';
import '../../../core/network/json.dart';
import '../../../core/utils/polyline.dart';

/// A geocoded location (search result, recent destination, pickup, ...).
class Place {
  const Place({required this.name, required this.address, required this.lat, required this.lng, this.placeId});
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? placeId;

  GeoPoint get point => GeoPoint(lat, lng);

  factory Place.fromJson(Json j) => Place(
        name: asString(j['name'], asString(j['address'])),
        address: asString(j['address']),
        lat: asDouble(j['lat']),
        lng: asDouble(j['lng']),
        placeId: asStringOrNull(j['place_id']),
      );

  Place copyWith({String? name, String? address}) => Place(name: name ?? this.name, address: address ?? this.address, lat: lat, lng: lng, placeId: placeId);
}

class SavedPlace {
  const SavedPlace({required this.id, required this.label, required this.name, required this.address, required this.lat, required this.lng});
  final int id;
  final String label; // home | work | other
  final String name;
  final String address;
  final double lat;
  final double lng;

  Place get place => Place(name: name, address: address, lat: lat, lng: lng);

  factory SavedPlace.fromJson(Json j) => SavedPlace(
        id: asInt(j['id']),
        label: asString(j['label'], 'other'),
        name: asString(j['name']),
        address: asString(j['address']),
        lat: asDouble(j['lat']),
        lng: asDouble(j['lng']),
      );
}

class FareOption {
  const FareOption({
    required this.category,
    required this.suggestedFare,
    required this.minFare,
    required this.maxFare,
    this.surgeMultiplier = 1,
    this.currency = 'PKR',
    this.breakdown = const {},
  });
  final VehicleCategory category;
  final double suggestedFare;
  final double minFare;
  final double maxFare;
  final double surgeMultiplier;
  final String currency;
  final Json breakdown;

  factory FareOption.fromJson(Json j) => FareOption(
        category: VehicleCategory.fromJson(asMap(j['vehicle_category'])),
        suggestedFare: asDouble(j['suggested_fare']),
        minFare: asDouble(j['min_fare']),
        maxFare: asDouble(j['max_fare']),
        surgeMultiplier: asDouble(j['surge_multiplier'], 1),
        currency: asString(j['currency'], 'PKR'),
        breakdown: asMap(j['breakdown']),
      );
}

class FareEstimate {
  const FareEstimate({required this.distanceM, required this.durationS, this.polyline, this.zoneName, this.city, required this.options});
  final int distanceM;
  final int durationS;
  final String? polyline;
  final String? zoneName;
  final String? city;
  final List<FareOption> options;

  factory FareEstimate.fromJson(Json j) {
    final zone = asMap(j['service_zone']);
    return FareEstimate(
      distanceM: asInt(j['distance_m']),
      durationS: asInt(j['duration_s']),
      polyline: asStringOrNull(j['polyline']),
      zoneName: asStringOrNull(zone['name']),
      city: asStringOrNull(zone['city']),
      options: asListOf(j['options'], FareOption.fromJson),
    );
  }
}

class OfferDriver {
  const OfferDriver({required this.id, required this.firstName, this.photoUrl, this.rating = 0, this.completedTrips = 0});
  final String id;
  final String firstName;
  final String? photoUrl;
  final double rating;
  final int completedTrips;

  factory OfferDriver.fromJson(Json j) => OfferDriver(
        id: asString(j['id']),
        firstName: asString(j['first_name'], 'Driver'),
        photoUrl: asStringOrNull(j['photo_url']),
        rating: asDouble(j['rating']),
        completedTrips: asInt(j['completed_trips']),
      );
}

class OfferVehicle {
  const OfferVehicle({this.make, this.model, this.color, this.plateNumber});
  final String? make;
  final String? model;
  final String? color;
  final String? plateNumber;

  String get title => [color, make, model].whereType<String>().where((e) => e.isNotEmpty).join(' ');

  factory OfferVehicle.fromJson(Json j) => OfferVehicle(
        make: asStringOrNull(j['make']),
        model: asStringOrNull(j['model']),
        color: asStringOrNull(j['color']),
        plateNumber: asStringOrNull(j['plate_number']),
      );
}

/// `RideOfferResource`.
class RideOffer {
  const RideOffer({
    required this.id,
    this.rideId,
    required this.amount,
    required this.proposedBy,
    required this.status,
    this.sequence = 1,
    this.parentOfferId,
    this.etaS,
    this.distanceToPickupM,
    this.expiresAt,
    this.createdAt,
    this.driver,
    this.vehicle,
  });

  final int id;
  final String? rideId;
  final double amount;
  final String proposedBy; // driver | customer
  final String status; // pending | countered | accepted | rejected | withdrawn | expired | closed
  final int sequence;
  final int? parentOfferId;
  final int? etaS;
  final int? distanceToPickupM;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final OfferDriver? driver;
  final OfferVehicle? vehicle;

  bool get isPending => status == 'pending' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  bool get byDriver => proposedBy == 'driver';
  bool get byCustomer => proposedBy == 'customer';

  factory RideOffer.fromJson(Json j) => RideOffer(
        id: asInt(j['id']),
        rideId: asStringOrNull(j['ride_id']),
        amount: asDouble(j['amount']),
        proposedBy: asString(j['proposed_by'], 'driver'),
        status: asString(j['status'], 'pending'),
        sequence: asInt(j['sequence'], 1),
        parentOfferId: asIntOrNull(j['parent_offer_id']),
        etaS: asIntOrNull(j['eta_s']),
        distanceToPickupM: asIntOrNull(j['distance_to_pickup_m']),
        expiresAt: asDate(j['expires_at']),
        createdAt: asDate(j['created_at']),
        driver: j['driver'] is Map ? OfferDriver.fromJson(asMap(j['driver'])) : null,
        vehicle: j['vehicle'] is Map ? OfferVehicle.fromJson(asMap(j['vehicle'])) : null,
      );
}

class LocationPoint {
  const LocationPoint({required this.lat, required this.lng, this.address});
  final double lat;
  final double lng;
  final String? address;
  GeoPoint get point => GeoPoint(lat, lng);

  factory LocationPoint.fromJson(Json j) =>
      LocationPoint(lat: asDouble(j['lat']), lng: asDouble(j['lng']), address: asStringOrNull(j['address']));
}

/// `RideRequestResource` (customer view).
class RideRequest {
  const RideRequest({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.pickupNote,
    this.distanceM,
    this.durationS,
    this.polyline,
    this.suggestedFare = 0,
    this.minFare = 0,
    this.maxFare = 0,
    this.proposedFare = 0,
    this.discountAmount = 0,
    this.currency = 'PKR',
    this.paymentMethod = 'cash',
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.driversNotified,
    this.searchRadiusKm,
    this.offers = const [],
    this.tripId,
    this.expiresAt,
    this.cancelReason,
    this.createdAt,
  });

  final String id;
  final String status;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final String? pickupNote;
  final int? distanceM;
  final int? durationS;
  final String? polyline;
  final double suggestedFare;
  final double minFare;
  final double maxFare;
  final double proposedFare;
  final double discountAmount;
  final String currency;
  final String paymentMethod;
  final int? categoryId;
  final String? categoryName;
  final String? categorySlug;
  final int? driversNotified;
  final double? searchRadiusKm;
  final List<RideOffer> offers;
  final String? tripId;
  final DateTime? expiresAt;
  final String? cancelReason;
  final DateTime? createdAt;

  bool get isOpen => (status == 'searching' || status == 'offers_available') && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  bool get isAccepted => status == 'accepted';
  bool get isExpired => status == 'expired' || status == 'no_driver_found' || (!isAccepted && status != 'cancelled_by_customer' && expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  RideRequest copyWith({String? status, double? proposedFare, int? driversNotified, double? searchRadiusKm, List<RideOffer>? offers, String? tripId, DateTime? expiresAt}) => RideRequest(
        id: id,
        status: status ?? this.status,
        pickup: pickup,
        dropoff: dropoff,
        pickupNote: pickupNote,
        distanceM: distanceM,
        durationS: durationS,
        polyline: polyline,
        suggestedFare: suggestedFare,
        minFare: minFare,
        maxFare: maxFare,
        proposedFare: proposedFare ?? this.proposedFare,
        discountAmount: discountAmount,
        currency: currency,
        paymentMethod: paymentMethod,
        categoryId: categoryId,
        categoryName: categoryName,
        categorySlug: categorySlug,
        driversNotified: driversNotified ?? this.driversNotified,
        searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
        offers: offers ?? this.offers,
        tripId: tripId ?? this.tripId,
        expiresAt: expiresAt ?? this.expiresAt,
        cancelReason: cancelReason,
        createdAt: createdAt,
      );

  factory RideRequest.fromJson(Json j) {
    final cat = asMapOrNull(j['vehicle_category']);
    return RideRequest(
      id: asString(j['id']),
      status: asString(j['status'], 'searching'),
      pickup: LocationPoint.fromJson(asMap(j['pickup'])),
      dropoff: LocationPoint.fromJson(asMap(j['dropoff'])),
      pickupNote: asStringOrNull(j['pickup_note']),
      distanceM: asIntOrNull(j['distance_m']),
      durationS: asIntOrNull(j['duration_s']),
      polyline: asStringOrNull(j['polyline']),
      suggestedFare: asDouble(j['suggested_fare']),
      minFare: asDouble(j['min_fare']),
      maxFare: asDouble(j['max_fare']),
      proposedFare: asDouble(j['proposed_fare']),
      discountAmount: asDouble(j['discount_amount']),
      currency: asString(j['currency'], 'PKR'),
      paymentMethod: asString(j['payment_method'], 'cash'),
      categoryId: cat == null ? null : asIntOrNull(cat['id']),
      categoryName: cat == null ? null : asStringOrNull(cat['name']),
      categorySlug: cat == null ? null : asStringOrNull(cat['slug']),
      driversNotified: asIntOrNull(j['drivers_notified']),
      searchRadiusKm: asDoubleOrNull(j['search_radius_km']),
      offers: asListOf(j['offers'], RideOffer.fromJson),
      tripId: asStringOrNull(j['trip_id']),
      expiresAt: asDate(j['expires_at']),
      cancelReason: asStringOrNull(j['cancel_reason']),
      createdAt: asDate(j['created_at']),
    );
  }
}

/// Body for `POST /rides`.
class CreateRideInput {
  const CreateRideInput({
    required this.categoryId,
    required this.pickup,
    required this.dropoff,
    required this.proposedFare,
    this.pickupNote,
    this.couponCode,
    this.paymentMethod = 'cash',
  });
  final int categoryId;
  final Place pickup;
  final Place dropoff;
  final double proposedFare;
  final String? pickupNote;
  final String? couponCode;
  final String paymentMethod;

  Json toJson() => {
        'vehicle_category_id': categoryId,
        'pickup_lat': pickup.lat,
        'pickup_lng': pickup.lng,
        'pickup_address': pickup.address.isNotEmpty ? pickup.address : pickup.name,
        'dropoff_lat': dropoff.lat,
        'dropoff_lng': dropoff.lng,
        'dropoff_address': dropoff.address.isNotEmpty ? dropoff.address : dropoff.name,
        'proposed_fare': proposedFare,
        'payment_method': paymentMethod,
        if (pickupNote != null && pickupNote!.trim().isNotEmpty) 'pickup_note': pickupNote!.trim(),
        if (couponCode != null && couponCode!.trim().isNotEmpty) 'coupon_code': couponCode!.trim(),
      };
}

class CouponValidation {
  const CouponValidation({required this.code, required this.discount, this.description});
  final String code;
  final double discount;
  final String? description;

  factory CouponValidation.fromJson(Json j) =>
      CouponValidation(code: asString(j['code']), discount: asDouble(j['discount']), description: asStringOrNull(j['description']));
}

class Coupon {
  const Coupon({required this.code, this.description, this.type, this.value = 0, this.maxDiscount, this.minFare, this.endsAt});
  final String code;
  final String? description;
  final String? type;
  final double value;
  final double? maxDiscount;
  final double? minFare;
  final DateTime? endsAt;

  factory Coupon.fromJson(Json j) => Coupon(
        code: asString(j['code']),
        description: asStringOrNull(j['description']),
        type: asStringOrNull(j['type']),
        value: asDouble(j['value']),
        maxDiscount: asDoubleOrNull(j['max_discount']),
        minFare: asDoubleOrNull(j['min_fare']),
        endsAt: asDate(j['ends_at']),
      );
}
