import '../../../core/network/json.dart';
import '../../rides/domain/ride_models.dart';
import '../../trips/domain/trip_models.dart';

/// Incoming ride request as seen by a driver (`DispatchService::driverPayload` + `my_offer`).
class DriverRequest {
  const DriverRequest({
    required this.id,
    required this.status,
    required this.pickup,
    this.dropoffArea,
    this.distanceM,
    this.durationS,
    this.pickupDistanceM,
    this.pickupEtaS,
    this.proposedFare = 0,
    this.suggestedFare = 0,
    this.minFare = 0,
    this.maxFare = 0,
    this.currency = 'PKR',
    this.paymentMethod = 'cash',
    this.vehicleCategory,
    this.customerFirstName = '',
    this.customerRating = 0,
    this.customerRides = 0,
    this.pickupNote,
    this.expiresAt,
    this.myOffer,
  });

  final String id;
  final String status;
  final LocationPoint pickup;
  final String? dropoffArea;
  final int? distanceM;
  final int? durationS;
  final int? pickupDistanceM;
  final int? pickupEtaS;
  final double proposedFare;
  final double suggestedFare;
  final double minFare;
  final double maxFare;
  final String currency;
  final String paymentMethod;
  final String? vehicleCategory;
  final String customerFirstName;
  final double customerRating;
  final int customerRides;
  final String? pickupNote;
  final DateTime? expiresAt;
  final RideOffer? myOffer;

  bool get isOpen => (status == 'searching' || status == 'offers_available') && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// My live offer awaiting the customer.
  bool get hasPendingOffer => myOffer != null && myOffer!.byDriver && myOffer!.isPending;

  /// Customer has countered and awaits my response.
  bool get hasCustomerCounter => myOffer != null && myOffer!.byCustomer && myOffer!.isPending;

  DriverRequest copyWith({RideOffer? myOffer, bool clearOffer = false, double? proposedFare, String? status, DateTime? expiresAt}) => DriverRequest(
        id: id,
        status: status ?? this.status,
        pickup: pickup,
        dropoffArea: dropoffArea,
        distanceM: distanceM,
        durationS: durationS,
        pickupDistanceM: pickupDistanceM,
        pickupEtaS: pickupEtaS,
        proposedFare: proposedFare ?? this.proposedFare,
        suggestedFare: suggestedFare,
        minFare: minFare,
        maxFare: maxFare,
        currency: currency,
        paymentMethod: paymentMethod,
        vehicleCategory: vehicleCategory,
        customerFirstName: customerFirstName,
        customerRating: customerRating,
        customerRides: customerRides,
        pickupNote: pickupNote,
        expiresAt: expiresAt ?? this.expiresAt,
        myOffer: clearOffer ? null : (myOffer ?? this.myOffer),
      );

  factory DriverRequest.fromJson(Json j) {
    final c = asMap(j['customer']);
    return DriverRequest(
      id: asString(j['id']),
      status: asString(j['status'], 'searching'),
      pickup: LocationPoint.fromJson(asMap(j['pickup'])),
      dropoffArea: asStringOrNull(j['dropoff_area']),
      distanceM: asIntOrNull(j['distance_m']),
      durationS: asIntOrNull(j['duration_s']),
      pickupDistanceM: asIntOrNull(j['pickup_distance_m']),
      pickupEtaS: asIntOrNull(j['pickup_eta_s']),
      proposedFare: asDouble(j['proposed_fare']),
      suggestedFare: asDouble(j['suggested_fare']),
      minFare: asDouble(j['min_fare']),
      maxFare: asDouble(j['max_fare']),
      currency: asString(j['currency'], 'PKR'),
      paymentMethod: asString(j['payment_method'], 'cash'),
      vehicleCategory: asStringOrNull(j['vehicle_category']),
      customerFirstName: asString(c['first_name'], 'Customer'),
      customerRating: asDouble(c['rating']),
      customerRides: asInt(c['rides']),
      pickupNote: asStringOrNull(j['pickup_note']),
      expiresAt: asDate(j['expires_at']),
      myOffer: j['my_offer'] is Map ? RideOffer.fromJson(asMap(j['my_offer'])) : null,
    );
  }
}

class DriverDocument {
  const DriverDocument({required this.id, required this.type, required this.label, required this.status, this.expiryDate, this.isExpired = false, this.rejectionReason, this.uploadedAt});
  final int id;
  final String type;
  final String label;
  final String status; // pending | approved | rejected
  final String? expiryDate;
  final bool isExpired;
  final String? rejectionReason;
  final DateTime? uploadedAt;

  factory DriverDocument.fromJson(Json j) => DriverDocument(
        id: asInt(j['id']),
        type: asString(j['type']),
        label: asString(j['label'], asString(j['type'])),
        status: asString(j['status'], 'pending'),
        expiryDate: asStringOrNull(j['expiry_date']),
        isExpired: asBool(j['is_expired']),
        rejectionReason: asStringOrNull(j['rejection_reason']),
        uploadedAt: asDate(j['uploaded_at']),
      );
}

class PayoutAccount {
  const PayoutAccount({this.method, this.accountTitle, this.accountNumberMasked});
  final String? method;
  final String? accountTitle;
  final String? accountNumberMasked;
  bool get isSet => method != null && (accountNumberMasked?.isNotEmpty ?? false);

  factory PayoutAccount.fromJson(Json j) => PayoutAccount(
        method: asStringOrNull(j['method']),
        accountTitle: asStringOrNull(j['account_title']),
        accountNumberMasked: asStringOrNull(j['account_number_masked']),
      );
}

/// `DriverProfileResource`.
class DriverProfile {
  const DriverProfile({
    required this.status,
    required this.statusLabel,
    this.reason,
    this.fullName,
    this.cnicNumberMasked,
    this.dateOfBirth,
    this.licenseNumberMasked,
    this.licenseExpiry,
    this.address,
    this.emergencyContactName,
    this.hasEmergencyContactPhone = false,
    this.isOnline = false,
    this.rating = 0,
    this.completedTrips = 0,
    this.payout = const PayoutAccount(),
    this.vehicle,
    this.documents = const [],
    this.requiredDocuments = const [],
    this.optionalDocuments = const [],
    this.complianceIssues = const [],
    this.canEdit = true,
    this.submittedAt,
    this.approvedAt,
  });

  final String status;
  final String statusLabel;
  final String? reason;
  final String? fullName;
  final String? cnicNumberMasked;
  final String? dateOfBirth;
  final String? licenseNumberMasked;
  final String? licenseExpiry;
  final String? address;
  final String? emergencyContactName;
  final bool hasEmergencyContactPhone;
  final bool isOnline;
  final double rating;
  final int completedTrips;
  final PayoutAccount payout;
  final Vehicle? vehicle;
  final List<DriverDocument> documents;
  final List<String> requiredDocuments;
  final List<String> optionalDocuments;
  final List<String> complianceIssues;
  final bool canEdit;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  bool get personalComplete => (fullName?.isNotEmpty ?? false) && cnicNumberMasked != null && licenseNumberMasked != null;
  bool get vehicleComplete => vehicle != null;
  DriverDocument? documentFor(String type) {
    for (final d in documents) {
      if (d.type == type) return d;
    }
    return null;
  }

  List<String> get missingRequiredDocuments =>
      requiredDocuments.where((t) => documentFor(t) == null || documentFor(t)!.status == 'rejected').toList();

  factory DriverProfile.fromJson(Json j) => DriverProfile(
        status: asString(j['status'], 'not_submitted'),
        statusLabel: asString(j['status_label'], 'Not submitted'),
        reason: asStringOrNull(j['reason']),
        fullName: asStringOrNull(j['full_name']),
        cnicNumberMasked: asStringOrNull(j['cnic_number_masked']),
        dateOfBirth: asStringOrNull(j['date_of_birth']),
        licenseNumberMasked: asStringOrNull(j['license_number_masked']),
        licenseExpiry: asStringOrNull(j['license_expiry']),
        address: asStringOrNull(j['address']),
        emergencyContactName: asStringOrNull(j['emergency_contact_name']),
        hasEmergencyContactPhone: asBool(j['has_emergency_contact_phone']),
        isOnline: asBool(j['is_online']),
        rating: asDouble(j['rating']),
        completedTrips: asInt(j['completed_trips']),
        payout: PayoutAccount.fromJson(asMap(j['payout'])),
        vehicle: j['vehicle'] is Map ? Vehicle.fromJson(asMap(j['vehicle'])) : null,
        documents: asListOf(j['documents'], DriverDocument.fromJson),
        requiredDocuments: asStringList(j['required_documents']),
        optionalDocuments: asStringList(j['optional_documents']),
        complianceIssues: asStringList(j['compliance_issues']),
        canEdit: asBool(j['can_edit'], true),
        submittedAt: asDate(j['submitted_at']),
        approvedAt: asDate(j['approved_at']),
      );
}

class PeriodStats {
  const PeriodStats({this.completedTrips = 0, this.cancelledTrips = 0, this.grossFares = 0, this.commission = 0, this.netEarnings = 0, this.cashCollected = 0, this.onlineHours = 0});
  final int completedTrips;
  final int cancelledTrips;
  final double grossFares;
  final double commission;
  final double netEarnings;
  final double cashCollected;
  final double onlineHours;

  factory PeriodStats.fromJson(Json j) => PeriodStats(
        completedTrips: asInt(j['completed_trips']),
        cancelledTrips: asInt(j['cancelled_trips']),
        grossFares: asDouble(j['gross_fares']),
        commission: asDouble(j['commission']),
        netEarnings: asDouble(j['net_earnings']),
        cashCollected: asDouble(j['cash_collected']),
        onlineHours: asDouble(j['online_hours']),
      );
}

class ExpiringDocument {
  const ExpiringDocument({required this.type, required this.label, required this.expiryDate});
  final String type;
  final String label;
  final String expiryDate;
  factory ExpiringDocument.fromJson(Json j) =>
      ExpiringDocument(type: asString(j['type']), label: asString(j['label']), expiryDate: asString(j['expiry_date']));
}

/// `GET /driver/dashboard`.
class DriverDashboard {
  const DriverDashboard({
    this.isOnline = false,
    this.status = 'not_submitted',
    this.rating = 0,
    this.totalCompletedTrips = 0,
    this.today = const PeriodStats(),
    this.week = const PeriodStats(),
    this.balance = 0,
    this.availableForPayout = 0,
    this.currency = 'PKR',
    this.complianceIssues = const [],
    this.expiringDocuments = const [],
    this.unreadNotifications = 0,
  });

  final bool isOnline;
  final String status;
  final double rating;
  final int totalCompletedTrips;
  final PeriodStats today;
  final PeriodStats week;
  final double balance;
  final double availableForPayout;
  final String currency;
  final List<String> complianceIssues;
  final List<ExpiringDocument> expiringDocuments;
  final int unreadNotifications;

  factory DriverDashboard.fromJson(Json j) => DriverDashboard(
        isOnline: asBool(j['is_online']),
        status: asString(j['status'], 'not_submitted'),
        rating: asDouble(j['rating']),
        totalCompletedTrips: asInt(j['total_completed_trips']),
        today: PeriodStats.fromJson(asMap(j['today'])),
        week: PeriodStats.fromJson(asMap(j['week'])),
        balance: asDouble(j['balance']),
        availableForPayout: asDouble(j['available_for_payout']),
        currency: asString(j['currency'], 'PKR'),
        complianceIssues: asStringList(j['compliance_issues']),
        expiringDocuments: asListOf(j['expiring_documents'], ExpiringDocument.fromJson),
        unreadNotifications: asInt(j['unread_notifications']),
      );
}

class DailyEarning {
  const DailyEarning({required this.date, this.trips = 0, this.earnings = 0, this.commission = 0});
  final DateTime date;
  final int trips;
  final double earnings;
  final double commission;
  factory DailyEarning.fromJson(Json j) => DailyEarning(
        date: DateTime.tryParse(asString(j['date'])) ?? DateTime.now(),
        trips: asInt(j['trips']),
        earnings: asDouble(j['earnings']),
        commission: asDouble(j['commission']),
      );
}

class EarningsReport {
  const EarningsReport({required this.period, required this.summary, this.daily = const [], this.currency = 'PKR'});
  final String period;
  final PeriodStats summary;
  final List<DailyEarning> daily;
  final String currency;
  factory EarningsReport.fromJson(Json j) => EarningsReport(
        period: asString(j['period'], 'week'),
        summary: PeriodStats.fromJson(asMap(j['summary'])),
        daily: asListOf(j['daily'], DailyEarning.fromJson),
        currency: asString(j['currency'], 'PKR'),
      );
}

class LedgerEntry {
  const LedgerEntry({required this.id, required this.type, required this.direction, required this.amount, this.currency = 'PKR', this.description, this.tripId, this.createdAt});
  final int id;
  final String type;
  final String direction; // credit | debit
  final double amount;
  final String currency;
  final String? description;
  final String? tripId;
  final DateTime? createdAt;
  bool get isCredit => direction == 'credit';

  factory LedgerEntry.fromJson(Json j) => LedgerEntry(
        id: asInt(j['id']),
        type: asString(j['type']),
        direction: asString(j['direction'], 'credit'),
        amount: asDouble(j['amount']),
        currency: asString(j['currency'], 'PKR'),
        description: asStringOrNull(j['description']),
        tripId: asStringOrNull(j['trip_id']),
        createdAt: asDate(j['created_at']),
      );
}

class Payout {
  const Payout({required this.id, required this.amount, this.currency = 'PKR', this.method, this.accountTitle, this.accountNumberMasked, required this.status, this.failureReason, this.paidAt, this.createdAt});
  final String id;
  final double amount;
  final String currency;
  final String? method;
  final String? accountTitle;
  final String? accountNumberMasked;
  final String status;
  final String? failureReason;
  final DateTime? paidAt;
  final DateTime? createdAt;

  factory Payout.fromJson(Json j) => Payout(
        id: asString(j['id']),
        amount: asDouble(j['amount']),
        currency: asString(j['currency'], 'PKR'),
        method: asStringOrNull(j['method']),
        accountTitle: asStringOrNull(j['account_title']),
        accountNumberMasked: asStringOrNull(j['account_number_masked']),
        status: asString(j['status'], 'requested'),
        failureReason: asStringOrNull(j['failure_reason']),
        paidAt: asDate(j['paid_at']),
        createdAt: asDate(j['created_at']),
      );
}

class StatementSummary {
  const StatementSummary({
    this.completedTrips = 0,
    this.cancelledTrips = 0,
    this.grossFares = 0,
    this.commission = 0,
    this.netEarnings = 0,
    this.cashCollected = 0,
    this.payoutsPaid = 0,
    this.openingBalance = 0,
    this.closingBalance = 0,
  });
  final int completedTrips;
  final int cancelledTrips;
  final double grossFares;
  final double commission;
  final double netEarnings;
  final double cashCollected;
  final double payoutsPaid;
  final double openingBalance;
  final double closingBalance;

  factory StatementSummary.fromJson(Json j) => StatementSummary(
        completedTrips: asInt(j['completed_trips']),
        cancelledTrips: asInt(j['cancelled_trips']),
        grossFares: asDouble(j['gross_fares']),
        commission: asDouble(j['commission']),
        netEarnings: asDouble(j['net_earnings']),
        cashCollected: asDouble(j['cash_collected']),
        payoutsPaid: asDouble(j['payouts_paid']),
        openingBalance: asDouble(j['opening_balance']),
        closingBalance: asDouble(j['closing_balance']),
      );
}

class StatementTrip {
  const StatementTrip({required this.id, this.completedAt, this.from, this.to, this.fare = 0, this.commission = 0, this.earning = 0, this.paymentMethod});
  final String id;
  final DateTime? completedAt;
  final String? from;
  final String? to;
  final double fare;
  final double commission;
  final double earning;
  final String? paymentMethod;

  factory StatementTrip.fromJson(Json j) => StatementTrip(
        id: asString(j['id']),
        completedAt: asDate(j['completed_at']),
        from: asStringOrNull(j['from']),
        to: asStringOrNull(j['to']),
        fare: asDouble(j['fare']),
        commission: asDouble(j['commission']),
        earning: asDouble(j['earning']),
        paymentMethod: asStringOrNull(j['payment_method']),
      );
}

class StatementPayout {
  const StatementPayout({required this.id, this.amount = 0, this.paidAt, this.reference});
  final String id;
  final double amount;
  final DateTime? paidAt;
  final String? reference;

  factory StatementPayout.fromJson(Json j) => StatementPayout(
        id: asString(j['id']),
        amount: asDouble(j['amount']),
        paidAt: asDate(j['paid_at']),
        reference: asStringOrNull(j['reference']),
      );
}

/// `GET /driver/statements?month=YYYY-MM`.
class DriverStatement {
  const DriverStatement({required this.month, this.from, this.to, this.currency = 'PKR', this.summary = const StatementSummary(), this.trips = const [], this.payouts = const []});
  final String month;
  final DateTime? from;
  final DateTime? to;
  final String currency;
  final StatementSummary summary;
  final List<StatementTrip> trips;
  final List<StatementPayout> payouts;

  factory DriverStatement.fromJson(Json j) {
    final period = asMap(j['period']);
    return DriverStatement(
      month: asString(j['month']),
      from: DateTime.tryParse(asString(period['from'])),
      to: DateTime.tryParse(asString(period['to'])),
      currency: asString(j['currency'], 'PKR'),
      summary: StatementSummary.fromJson(asMap(j['summary'])),
      trips: asListOf(j['trips'], StatementTrip.fromJson),
      payouts: asListOf(j['payouts'], StatementPayout.fromJson),
    );
  }
}
