import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../rides/domain/ride_models.dart';
import '../data/driver_repository.dart';
import '../domain/driver_models.dart';

/// Incoming ride requests for the driver: REST snapshot patched by realtime events.
class DriverRequestsController extends AsyncNotifier<List<DriverRequest>> {
  @override
  Future<List<DriverRequest>> build() => _fetch();

  Future<List<DriverRequest>> _fetch() async {
    final list = await ref.read(driverRepositoryProvider).requests();
    return _sorted(list.where((r) => r.isOpen).toList());
  }

  List<DriverRequest> _sorted(List<DriverRequest> l) {
    l.sort((a, b) {
      // Customer counters first, then by pickup distance.
      final ca = a.hasCustomerCounter ? 0 : 1;
      final cb = b.hasCustomerCounter ? 0 : 1;
      if (ca != cb) return ca - cb;
      return (a.pickupDistanceM ?? 1 << 30).compareTo(b.pickupDistanceM ?? 1 << 30);
    });
    return l;
  }

  List<DriverRequest> get _current => state.value ?? const [];

  Future<void> refresh() async {
    try {
      final list = await _fetch();
      state = AsyncData(list);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  void remove(String rideId) {
    state = AsyncData(_current.where((r) => r.id != rideId).toList());
  }

  /// [authoritativeOffer]: the payload carried `my_offer` (ride.requested / ride.updated do),
  /// so its value — including null — replaces local state; otherwise keep the existing offer.
  void upsert(DriverRequest r, {bool authoritativeOffer = false}) {
    final list = [..._current];
    final i = list.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      list[i] = authoritativeOffer || r.myOffer != null ? r : r.copyWith(myOffer: list[i].myOffer);
    } else {
      list.add(r);
    }
    state = AsyncData(_sorted(list));
  }

  void patchOffer(RideOffer offer) {
    final rideId = offer.rideId;
    if (rideId == null) return;
    final list = [..._current];
    final i = list.indexWhere((e) => e.id == rideId);
    if (i < 0) return;
    list[i] = list[i].copyWith(myOffer: offer);
    state = AsyncData(_sorted(list));
  }

  /// Applies a driver-channel realtime event. Returns a trip id when an offer was accepted.
  String? applyEvent(RealtimeEvent e) {
    switch (e.event) {
      case RtEvents.rideRequested:
      case RtEvents.rideUpdated:
        final ride = asMapOrNull(e.data['ride']);
        if (ride != null) {
          final r = DriverRequest.fromJson(ride);
          if (r.isOpen) {
            upsert(r, authoritativeOffer: ride.containsKey('my_offer'));
          } else {
            remove(r.id);
          }
        }
      case RtEvents.rideClosed:
      case RtEvents.rideCancelled:
      case RtEvents.rideExpired:
        final id = asStringOrNull(e.data['ride_id']);
        if (id != null) remove(id);
      case RtEvents.offerCreated:
      case RtEvents.offerCountered:
      case RtEvents.offerRejected:
      case RtEvents.offerWithdrawn:
        final o = asMapOrNull(e.data['offer']);
        if (o != null) {
          patchOffer(RideOffer.fromJson(o));
        } else {
          refresh();
        }
      case RtEvents.offerExpired:
        refresh();
      case RtEvents.offerAccepted:
        final tripId = asStringOrNull(e.data['trip_id']);
        final rideId = asStringOrNull(e.data['ride_id']);
        if (rideId != null) remove(rideId);
        return tripId;
    }
    return null;
  }
}

final driverRequestsProvider = AsyncNotifierProvider.autoDispose<DriverRequestsController, List<DriverRequest>>(DriverRequestsController.new);
