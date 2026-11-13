import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_models.dart';

/// SOS flow: confirm → POST /sos {trip_id, lat, lng} → show emergency number + call.
Future<void> runSosFlow(BuildContext context, WidgetRef ref, {String? tripId}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Send SOS alert?',
    message: 'Our safety team will be alerted immediately with your live location and trip details. Use this only if you feel unsafe or need urgent help.',
    confirmLabel: 'Send SOS',
    destructive: true,
    icon: Icons.sos_rounded,
  );
  if (!confirmed || !context.mounted) return;

  final fix = await ref.read(locationServiceProvider).current(timeout: const Duration(seconds: 6));
  if (!context.mounted) return;
  final result = await runGuarded<SosResult>(
    context,
    () => ref.read(tripRepositoryProvider).sos(tripId: tripId, lat: fix?.lat, lng: fix?.lng),
  );
  if (result == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 36),
      title: const Text('Help is on the way'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result.message ?? 'SOS alert sent to FemaleRider safety team.', style: AppText.body),
        if (result.reference != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text('Reference: ${result.reference}', style: AppText.label),
        ],
        const SizedBox(height: AppSpace.md),
        Text('If you are in immediate danger, call emergency services:', style: AppText.bodySm),
        const SizedBox(height: AppSpace.xs),
        Text(result.emergencyNumber, style: AppText.h1.copyWith(color: AppColors.danger)),
        if (result.supportHours != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text('Support hours: ${result.supportHours}', style: AppText.caption),
        ],
      ]),
      actions: [
        Row(children: [
          Expanded(child: AppButton.secondary(label: 'Close', height: 48, onPressed: () => Navigator.of(ctx).pop())),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: AppButton.danger(
              label: 'Call ${result.emergencyNumber}',
              icon: Icons.call_rounded,
              height: 48,
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: result.emergencyNumber)),
            ),
          ),
        ]),
      ],
    ),
  );
}
