import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../account/domain/account_models.dart';

/// Safety incident reports (SOS lives in TripRepository).
class SafetyRepository {
  SafetyRepository(this._api);
  final ApiClient _api;

  static const types = ['safety_report', 'harassment', 'unsafe_driving', 'accident', 'vehicle_mismatch', 'other'];
  static const severities = ['low', 'medium', 'high', 'critical'];

  Future<Paged<Incident>> incidents({int page = 1}) async {
    final env = await _api.get('/incidents', query: {'page': page});
    return Paged(items: asListOf(env.data, Incident.fromJson), pagination: env.pagination);
  }

  Future<(Incident, String?)> report({
    required String type,
    required String description,
    String? severity,
    String? tripId,
    List<String> evidencePaths = const [],
  }) async {
    final env = await _api.multipart('/incidents', fields: {
      'type': type,
      'description': description,
      'severity': severity,
      'trip_id': tripId,
    }, files: {
      if (evidencePaths.isNotEmpty) 'evidence': evidencePaths.map((p) => UploadFile(path: p)).toList(),
    });
    return (Incident.fromJson(env.dataMap), env.message);
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) => SafetyRepository(ref.watch(apiClientProvider)));
