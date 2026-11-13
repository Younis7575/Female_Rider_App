import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';

/// `GET /driver/profile` — application state, vehicle, documents, payout account.
final driverProfileProvider = FutureProvider.autoDispose<DriverProfile>((ref) {
  return ref.watch(driverRepositoryProvider).profile();
});

/// Application step completion derived from the profile.
class ApplicationProgress {
  ApplicationProgress(this.p);
  final DriverProfile p;

  bool get personal => p.personalComplete && (p.address?.isNotEmpty ?? false) && p.hasEmergencyContactPhone;
  bool get vehicle => p.vehicleComplete;
  bool get documents => p.missingRequiredDocuments.isEmpty;
  bool get payout => p.payout.isSet;
  int get done => [personal, vehicle, documents, payout].where((e) => e).length;
  // The backend requires a payout account before submission (missing: "payout account").
  bool get readyToSubmit => personal && vehicle && documents && payout;
}

/// Document types that carry an expiry date.
const expiringDocumentTypes = {'license_front', 'license_back', 'vehicle_registration', 'insurance', 'fitness_certificate', 'cnic_front', 'cnic_back'};
