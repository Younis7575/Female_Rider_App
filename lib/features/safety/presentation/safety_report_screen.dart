import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/safety_repository.dart';

const _typeLabels = {
  'safety_report': ('General safety concern', Icons.shield_outlined),
  'harassment': ('Harassment', Icons.front_hand_outlined),
  'unsafe_driving': ('Unsafe driving', Icons.speed_rounded),
  'accident': ('Accident', Icons.car_crash_outlined),
  'vehicle_mismatch': ('Vehicle or driver mismatch', Icons.no_crash_outlined),
  'other': ('Something else', Icons.more_horiz_rounded),
};

const _severityLabels = {'low': 'Low', 'medium': 'Medium', 'high': 'High', 'critical': 'Critical'};

/// Confidential safety incident report with optional evidence files.
class SafetyReportScreen extends ConsumerStatefulWidget {
  const SafetyReportScreen({super.key, this.tripId});
  final String? tripId;

  @override
  ConsumerState<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends ConsumerState<SafetyReportScreen> {
  final _description = TextEditingController();
  String _type = 'safety_report';
  String _severity = 'medium';
  final List<String> _evidence = [];
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _addEvidence() async {
    final remaining = 5 - _evidence.length;
    if (remaining <= 0) return;
    final picked = await pickMultipleImagePaths(limit: remaining);
    if (picked.isNotEmpty) setState(() => _evidence.addAll(picked.take(remaining)));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final (incident, message) = await ref.read(safetyRepositoryProvider).report(
            type: _type,
            severity: _severity,
            description: _description.text.trim(),
            tripId: widget.tripId,
            evidencePaths: _evidence,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 40),
          title: const Text('Report received'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message ?? 'Our safety team will review it confidentially.', textAlign: TextAlign.center),
            if (incident.reference.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text('Reference ${incident.reference}', style: AppText.label),
            ],
          ]),
          actions: [AppButton(label: 'Done', height: 48, onPressed: () => Navigator.of(ctx).pop())],
        ),
      );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _description.text.trim().length >= 10;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a safety issue')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            const InfoBanner(
              tone: StatusTone.danger,
              icon: Icons.sos_rounded,
              title: 'In danger right now?',
              message: 'Use the SOS button on your trip screen or call emergency services (15). This form is reviewed by our safety team, not monitored live.',
            ),
            if (widget.tripId != null) ...[
              const SizedBox(height: AppSpace.sm),
              const InfoBanner(message: 'This report will be linked to your trip.', icon: Icons.link_rounded),
            ],
            const SectionHeader('What happened?', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
            RadioGroup<String>(
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v ?? _type),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final t in SafetyRepository.types)
                    RadioListTile<String>(
                      value: t,
                      activeColor: AppColors.crimson,
                      secondary: Icon(_typeLabels[t]?.$2 ?? Icons.label_outline),
                      title: Text(_typeLabels[t]?.$1 ?? t, style: AppText.title),
                    ),
                ]),
              ),
            ),
            const SectionHeader('How serious is it?', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
            SegmentedButton<String>(
              segments: [for (final s in SafetyRepository.severities) ButtonSegment(value: s, label: Text(_severityLabels[s] ?? s))],
              selected: {_severity},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _severity = v.first),
            ),
            const SectionHeader('Details', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
            TextField(
              controller: _description,
              maxLines: 6,
              maxLength: 3000,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Describe what happened, when and where (at least 10 characters).'),
            ),
            const SectionHeader('Evidence (optional)', padding: EdgeInsets.fromLTRB(0, AppSpace.sm, 0, AppSpace.xs)),
            Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
              for (final p in _evidence)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(File(p), width: 84, height: 84, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 84, height: 84, color: AppColors.field, child: const Icon(Icons.insert_drive_file_outlined))),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _evidence.remove(p)),
                      child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
              if (_evidence.length < 5)
                Semantics(
                  button: true,
                  label: 'Add evidence photos',
                  child: InkWell(
                    onTap: _addEvidence,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.line)),
                      child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.muted),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: AppSpace.xs),
            Text('Up to 5 photos. Reports are confidential.', style: AppText.caption),
          ]),
        ),
        BottomActionBar(child: AppButton(label: 'Submit report', loading: _busy, onPressed: valid ? _submit : null)),
      ]),
    );
  }
}
