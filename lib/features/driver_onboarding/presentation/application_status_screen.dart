import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/presentation/mode_switcher.dart';
import '../../auth/presentation/session_controller.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';

/// Driver application status for every lifecycle state.
class DriverApplicationStatusScreen extends ConsumerWidget {
  const DriverApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Driver application', style: AppText.h3.copyWith(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () async {
          await ref.read(sessionProvider.notifier).refreshMe();
          ref.invalidate(driverProfileProvider);
          await ref.read(driverProfileProvider.future);
        },
        child: AsyncView<DriverProfile>(
          value: profile,
          onRetry: () => ref.invalidate(driverProfileProvider),
          data: (p) => _Body(p: p),
        ),
      ),
    );
  }
}

class _StatusSpec {
  const _StatusSpec(this.icon, this.color, this.bg, this.headline, this.message);
  final IconData icon;
  final Color color;
  final Color bg;
  final String headline;
  final String message;
}

_StatusSpec _spec(String status) => switch (status) {
      'not_submitted' => const _StatusSpec(Icons.edit_note_rounded, AppColors.inkSoft, AppColors.field, 'Application not submitted',
          'Complete your details, vehicle and documents, then submit your application for review.'),
      'pending' => const _StatusSpec(Icons.hourglass_top_rounded, AppColors.warning, AppColors.warningSoft, 'Application submitted',
          'Thanks for applying! Our team will start reviewing your application shortly.'),
      'under_review' => const _StatusSpec(Icons.manage_search_rounded, AppColors.info, AppColors.infoSoft, 'Under review',
          'We are verifying your documents and vehicle. This usually takes 24–48 hours.'),
      'more_info_required' => const _StatusSpec(Icons.feedback_outlined, AppColors.warning, AppColors.warningSoft, 'More information needed',
          'Please review the note below, update your application and resubmit.'),
      'approved' => const _StatusSpec(Icons.verified_rounded, AppColors.success, AppColors.successSoft, 'You\'re approved!',
          'Welcome to FemaleRider. Switch to Driver mode and go online to start earning.'),
      'rejected' => const _StatusSpec(Icons.cancel_outlined, AppColors.danger, AppColors.dangerSoft, 'Application not approved',
          'Unfortunately your application was not approved. You can fix the issues below and apply again.'),
      'suspended' => const _StatusSpec(Icons.block_rounded, AppColors.danger, AppColors.dangerSoft, 'Driver account suspended',
          'Your driver account is suspended. Contact support if you believe this is a mistake.'),
      'expired' => const _StatusSpec(Icons.event_busy_rounded, AppColors.danger, AppColors.dangerSoft, 'Documents expired',
          'Some of your documents have expired. Upload renewed documents to continue driving.'),
      _ => const _StatusSpec(Icons.info_outline_rounded, AppColors.inkSoft, AppColors.field, 'Application status', ''),
    };

class _Body extends ConsumerWidget {
  const _Body({required this.p});
  final DriverProfile p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _spec(p.status);
    final user = ref.watch(currentUserProvider);
    final rejectedDocs = p.documents.where((d) => d.status == 'rejected' || d.isExpired).toList();
    final issues = p.status == 'approved' ? p.complianceIssues : p.complianceIssues.where((i) => !i.startsWith('Driver application is')).toList();

    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpace.md), children: [
      AppCard(
        child: Column(children: [
          const SizedBox(height: AppSpace.sm),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle),
            child: Icon(s.icon, color: s.color, size: 42),
          ),
          const SizedBox(height: AppSpace.md),
          StatusChip(label: p.statusLabel, tone: StatusChip.toneFor(p.status)),
          const SizedBox(height: AppSpace.sm),
          Text(s.headline, style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(s.message, style: AppText.body, textAlign: TextAlign.center),
          if (p.submittedAt != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text('Submitted ${formatDateTime(p.submittedAt)}', style: AppText.caption),
          ],
          if (p.approvedAt != null) Text('Approved ${formatDateTime(p.approvedAt)}', style: AppText.caption),
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
      if (p.reason != null && p.reason!.isNotEmpty) ...[
        const SizedBox(height: AppSpace.sm),
        InfoBanner(tone: StatusTone.warning, icon: Icons.sticky_note_2_outlined, title: 'Note from our team', message: p.reason!),
      ],
      if (issues.isNotEmpty) ...[
        const SectionHeader('Outstanding items', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in issues)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.radio_button_unchecked_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(child: Text(i, style: AppText.bodySm.copyWith(color: AppColors.inkSoft))),
                ]),
              ),
          ]),
        ),
      ],
      if (rejectedDocs.isNotEmpty) ...[
        const SectionHeader('Documents to fix', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
        for (final d in rejectedDocs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: AppCard(
              onTap: () => context.push(Routes.driverDocuments),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(documentLabel(d.type), style: AppText.title),
                    Text(d.isExpired ? 'Expired ${d.expiryDate ?? ''}' : (d.rejectionReason ?? 'Rejected'), style: AppText.caption.copyWith(color: AppColors.danger)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
      ],
      const SizedBox(height: AppSpace.lg),
      ..._actions(context, ref, p, user?.isDriverMode ?? false),
    ]);
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, DriverProfile p, bool inDriverMode) {
    switch (p.status) {
      case 'approved':
        return [
          if (!inDriverMode)
            AppButton(
              variant: AppButtonVariant.dark,
              label: 'Switch to Driver mode',
              icon: Icons.drive_eta_rounded,
              onPressed: () => performModeSwitch(context, ref, AppMode.driver),
            )
          else
            AppButton(variant: AppButtonVariant.dark, label: 'Go to dashboard', onPressed: () => context.go(Routes.driverHome)),
          const SizedBox(height: AppSpace.xs),
          AppButton.secondary(label: 'Manage documents', icon: Icons.folder_open_rounded, onPressed: () => context.push(Routes.driverDocuments)),
        ];
      case 'not_submitted':
      case 'more_info_required':
      case 'rejected':
        return [
          AppButton(
            label: p.status == 'not_submitted' ? 'Continue application' : 'Update & resubmit',
            icon: Icons.edit_rounded,
            onPressed: () => context.push(Routes.driverApply),
          ),
          if (p.documents.any((d) => d.status == 'rejected')) ...[
            const SizedBox(height: AppSpace.xs),
            AppButton.secondary(label: 'Fix documents', onPressed: () => context.push(Routes.driverApplyDocuments)),
          ],
        ];
      case 'expired':
        return [AppButton(label: 'Upload renewed documents', icon: Icons.upload_file_rounded, onPressed: () => context.push(Routes.driverDocuments))];
      case 'suspended':
        return [AppButton.secondary(label: 'Contact support', icon: Icons.support_agent_rounded, onPressed: () => context.push(Routes.support))];
      default:
        return [
          AppButton.secondary(label: 'View documents', icon: Icons.folder_open_rounded, onPressed: () => context.push(Routes.driverDocuments)),
          const SizedBox(height: AppSpace.xs),
          TextButton(onPressed: () => context.push(Routes.support), child: const Text('Questions? Contact support')),
        ];
    }
  }
}
