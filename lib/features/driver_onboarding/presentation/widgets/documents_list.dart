import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/config_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../driver/data/driver_repository.dart';
import '../../../driver/domain/driver_models.dart';
import '../onboarding_providers.dart';

/// Required + optional driver documents with status, rejection reasons and (re-)upload.
class DriverDocumentsList extends ConsumerStatefulWidget {
  const DriverDocumentsList({super.key, required this.profile, this.onChanged, this.padding = const EdgeInsets.all(AppSpace.md)});
  final DriverProfile profile;
  final VoidCallback? onChanged;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<DriverDocumentsList> createState() => _DriverDocumentsListState();
}

class _DriverDocumentsListState extends ConsumerState<DriverDocumentsList> {
  final Map<String, double> _progress = {};

  Future<void> _upload(String type) async {
    final path = await pickImagePath(context, title: documentLabel(type));
    if (path == null || !mounted) return;
    String? expiry;
    if (expiringDocumentTypes.contains(type)) {
      final picked = await showDatePicker(
        context: context,
        helpText: 'Expiry date (optional)',
        cancelText: 'Skip',
        firstDate: DateTime.now().add(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
        initialDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) expiry = DateFormat('yyyy-MM-dd').format(picked);
    }
    if (!mounted) return;
    setState(() => _progress[type] = 0);
    try {
      await ref.read(driverRepositoryProvider).uploadDocument(
            type: type,
            path: path,
            expiryDate: expiry,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => _progress[type] = sent / total);
            },
          );
      if (mounted) showSnack(context, '${documentLabel(type)} uploaded for review', success: true);
      ref.invalidate(driverProfileProvider);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _progress.remove(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    final p = widget.profile;
    final required = p.requiredDocuments.isNotEmpty ? p.requiredDocuments : cfg.requiredDocuments;
    final optional = p.optionalDocuments.isNotEmpty ? p.optionalDocuments : cfg.optionalDocuments;
    final missing = required.where((t) => p.documentFor(t) == null || p.documentFor(t)!.status == 'rejected').length;
    return ListView(
      padding: widget.padding,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        InfoBanner(
          tone: missing == 0 ? StatusTone.success : StatusTone.info,
          icon: missing == 0 ? Icons.check_circle_outline_rounded : Icons.photo_camera_back_outlined,
          message: missing == 0
              ? 'All required documents are uploaded. Our team reviews them, usually within 24–48 hours.'
              : 'Upload clear, well-lit photos (JPG/PNG/PDF, max 8 MB). $missing required document${missing == 1 ? '' : 's'} still needed.',
        ),
        const SectionHeader('Required', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
        for (final t in required) _tile(t, p.documentFor(t), true),
        if (optional.isNotEmpty) ...[
          const SectionHeader('Optional', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
          for (final t in optional) _tile(t, p.documentFor(t), false),
        ],
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }

  Widget _tile(String type, DriverDocument? doc, bool required) {
    final progress = _progress[type];
    final status = doc == null ? 'missing' : (doc.isExpired ? 'expired' : doc.status);
    final (label, tone, icon) = switch (status) {
      'approved' => ('Approved', StatusTone.success, Icons.verified_rounded),
      'pending' => ('In review', StatusTone.warning, Icons.hourglass_top_rounded),
      'rejected' => ('Rejected', StatusTone.danger, Icons.error_outline_rounded),
      'expired' => ('Expired', StatusTone.danger, Icons.event_busy_rounded),
      _ => (required ? 'Required' : 'Optional', StatusTone.neutral, Icons.upload_file_rounded),
    };
    final needsAction = status == 'missing' || status == 'rejected' || status == 'expired';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: AppCard(
        onTap: progress != null ? null : () => _upload(type),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: needsAction ? AppColors.roseSoft : AppColors.field, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(icon, color: needsAction ? AppColors.crimson : AppColors.inkSoft, size: 20),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(documentLabel(type), style: AppText.title),
                if (doc?.expiryDate != null) Text('Expires ${formatDate(DateTime.tryParse(doc!.expiryDate!))}', style: AppText.caption),
                if (doc?.uploadedAt != null && doc?.expiryDate == null) Text('Uploaded ${formatRelative(doc!.uploadedAt)}', style: AppText.caption),
              ]),
            ),
            StatusChip(label: label, tone: tone, dense: true),
            const SizedBox(width: 4),
            Icon(doc == null ? Icons.add_circle_outline_rounded : Icons.refresh_rounded, color: AppColors.muted, size: 20, semanticLabel: doc == null ? 'Upload' : 'Re-upload'),
          ]),
          if (doc?.rejectionReason != null && status == 'rejected')
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text('Reason: ${doc!.rejectionReason}', style: AppText.caption.copyWith(color: AppColors.danger)),
            ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress > 0 ? progress : null, minHeight: 6),
              ),
            ),
        ]),
      ),
    );
  }
}
