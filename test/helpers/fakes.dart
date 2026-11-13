// Test-only fakes. Never imported from lib/.
import 'dart:async';

import 'package:femalerider/core/location/location_service.dart';
import 'package:femalerider/core/network/api_client.dart';
import 'package:femalerider/core/network/api_envelope.dart';
import 'package:femalerider/core/storage/secure_store.dart';
import 'package:femalerider/features/account/data/account_repository.dart';
import 'package:femalerider/features/auth/data/auth_repository.dart';
import 'package:femalerider/features/auth/domain/user.dart';
import 'package:femalerider/features/auth/presentation/session_controller.dart';
import 'package:femalerider/features/driver/data/driver_repository.dart';

final _dummyApi = ApiClient(baseUrl: 'http://localhost', storage: AppStorage(MemoryKeyValueStore()));

Map<String, dynamic> userJson({
  String mode = 'customer',
  bool driverMode = false,
  String eligibility = 'approved',
  String driverStatus = 'not_submitted',
  bool profileCompleted = true,
  String? name = 'Ayesha Khan',
}) =>
    {
      'id': 'e25c5bae-1c09-46b8-a4ff-c8a32fc01e03',
      'phone': '+923001234567',
      'country_code': '+92',
      'name': name,
      'email': null,
      'photo_url': null,
      'locale': 'en',
      'account_status': 'active',
      'active_mode': mode,
      'rating': 4.9,
      'rating_count': 12,
      'profile_completed': profileCompleted,
      'emergency_contact': {'name': 'Family', 'phone': '+923000000000'},
      'notification_preferences': {'push': true, 'promotions': true, 'payment': true},
      'privacy_preferences': {'share_trip_with_emergency_contact': false},
      'eligibility': {'status': eligibility, 'label': eligibility, 'reason': null, 'can_submit': eligibility == 'draft', 'can_appeal': false},
      'roles': [
        {'role': 'customer', 'status': 'active'},
      ],
      'capabilities': {'customer_mode': eligibility == 'approved', 'driver_mode': driverMode},
      'driver': {'status': driverStatus, 'is_online': false, 'reason': null},
      'realtime_channels': {'user': 'private-user.1', 'driver': driverMode ? 'private-driver.1' : null},
      'deletion_requested_at': null,
      'created_at': '2026-11-13T11:23:00+00:00',
    };

AppUser testUser({String mode = 'customer', bool driverMode = false, String eligibility = 'approved', String driverStatus = 'not_submitted'}) =>
    AppUser.fromJson(userJson(mode: mode, driverMode: driverMode, eligibility: eligibility, driverStatus: driverStatus));

/// Session pre-seeded with a signed-in user.
class TestSessionController extends SessionController {
  TestSessionController(this.initial);
  final SessionState initial;

  @override
  SessionState build() => initial;
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(_dummyApi);

  int requestCalls = 0;
  int verifyCalls = 0;
  String validCode = '123456';
  OtpRequestResult nextRequest = const OtpRequestResult(phone: '+923001234567', expiresIn: 300, resendIn: 60, debugCode: '654321');
  ApiException? requestError;

  @override
  Future<OtpRequestResult> requestOtp({required String countryCode, required String phone, String? deviceId}) async {
    requestCalls++;
    if (requestError != null) throw requestError!;
    return nextRequest;
  }

  @override
  Future<AuthResult> verifyOtp({required String countryCode, required String phone, required String code}) async {
    verifyCalls++;
    if (code != validCode) {
      throw const ApiException(message: 'Incorrect code. 4 attempt(s) left.', code: 'otp_invalid', statusCode: 422, details: {'attempts_left': 4});
    }
    return AuthResult(token: 'test-token', isNewUser: false, user: testUser());
  }

  @override
  Future<MeResult> me() async => MeResult(user: testUser());

  @override
  Future<void> logout({String? deviceToken}) async {}
}

class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository() : super(_dummyApi);

  final List<String> modeCalls = [];
  ApiException? modeError;

  @override
  Future<(AppUser, String?)> switchMode(String mode) async {
    modeCalls.add(mode);
    if (modeError != null) throw modeError!;
    return (testUser(mode: mode, driverMode: true, driverStatus: 'approved'), 'Switched to ${mode[0].toUpperCase()}${mode.substring(1)} mode.');
  }
}

class FakeDriverRepository extends DriverRepository {
  FakeDriverRepository() : super(_dummyApi);

  Completer<int>? onlineGate;
  ApiException? onlineError;
  int onlineCalls = 0;
  int offlineCalls = 0;
  final List<int> sequences = [];

  @override
  Future<int> goOnline(double lat, double lng) async {
    onlineCalls++;
    if (onlineError != null) throw onlineError!;
    if (onlineGate != null) return onlineGate!.future;
    return 10;
  }

  @override
  Future<void> goOffline() async => offlineCalls++;

  @override
  Future<LocationPingResult> sendLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    required int sequence,
    required DateTime recordedAt,
  }) async {
    sequences.add(sequence);
    return const LocationPingResult(accepted: true, nextIntervalS: 10);
  }
}

class FakeLocationService extends LocationService {
  FakeLocationService({this.access = LocationAccess.granted});
  final LocationAccess access;
  final fix = LocationFix(lat: 24.8607, lng: 67.0011, accuracy: 5, timestamp: DateTime(2026, 11, 13, 10));

  @override
  Future<LocationAccess> ensurePermission({bool background = false}) async => access;

  @override
  Future<LocationFix?> current({Duration timeout = const Duration(seconds: 12)}) async => access == LocationAccess.granted ? fix : null;

  @override
  Future<LocationFix?> lastKnown() async => fix;

  @override
  Stream<LocationFix> stream({bool background = false, int distanceFilterM = 10}) => const Stream.empty();
}
