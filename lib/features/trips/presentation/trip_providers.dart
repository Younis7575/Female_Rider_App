import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trip_repository.dart';
import '../domain/trip_models.dart';

/// Single trip (detail / rating / receipt screens).
final tripDetailProvider = FutureProvider.autoDispose.family<Trip, String>((ref, id) {
  return ref.watch(tripRepositoryProvider).trip(id);
});

/// Receipt for a completed trip.
final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>((ref, id) {
  return ref.watch(tripRepositoryProvider).receipt(id);
});
