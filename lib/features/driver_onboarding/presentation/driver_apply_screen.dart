import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';

/// Driver application hub: progress across the four steps, then review & submit.
class DriverApplyScreen extends ConsumerWidget {
  const DriverApplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(driverProfileProvider.future),
        child: AsyncView<DriverProfile>(
          value: profile,
          onRetry: () => ref.invalidate(driverProfileProvider),
          loading: const Center(child: CircularProgressIndicator()),
          data: (p) => _Hub(profile: p),
        ),
      ),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final prog = ApplicationProgress(profile);
    final locked = !profile.canEdit;
    return ListView(padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(), children: [
      GradientHeader(
        driver: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Back',
            ),
            const Spacer(),
            StatusChip(label: profile.statusLabel, tone: StatusChip.toneFor(profile.status)),
          ]),
          const SizedBox(height: AppSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DRIVE WITH FEMALERIDER', style: AppText.overline.copyWith(color: AppColors.roseAccent)),
              const SizedBox(height: 4),
              Text('Earn on your schedule, driving women only.', style: AppText.h2.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpace.md),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: prog.done / 4, minHeight: 8, backgroundColor: AppColors.nightLine, color: AppColors.crimson),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text('${prog.done}/4 done', style: AppText.label.copyWith(color: Colors.white)),
              ]),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (locked) ...[
            InfoBanner(
              tone: StatusTone.warning,
              icon: Icons.lock_clock_outlined,
              title: 'Application ${profile.statusLabel.toLowerCase()}',
              message: 'Your application can\'t be edited right now. Check its status for details.',
              action: 'View status',
              onAction: () => context.push(Routes.driverApplicationStatus),
            ),
            const SizedBox(height: AppSpace.sm),
          ] else if (profile.reason != null && profile.reason!.isNotEmpty) ...[
            InfoBanner(tone: StatusTone.danger, title: 'Reviewer note', message: profile.reason!),
            const SizedBox(height: AppSpace.sm),
          ],
          _StepTile(
            index: 1,
            title: 'Personal details',
            subtitle: prog.personal ? (profile.fullName ?? 'Completed') : 'Name, CNIC, date of birth, licence, emergency contact',
            done: prog.personal,
            enabled: !locked,
            onTap: () => context.push(Routes.driverApplyPersonal),
          ),
          _StepTile(
            index: 2,
            title: 'Vehicle',
            subtitle: profile.vehicle != null ? '${profile.vehicle!.title} · ${profile.vehicle!.plateNumber ?? ''}' : 'Category, make, model, plate',
            done: prog.vehicle,
            enabled: !locked,
            onTap: () => context.push(Routes.driverApplyVehicle),
          ),
          _StepTile(
            index: 3,
            title: 'Documents',
            subtitle: prog.documents
                ? 'All required documents uploaded'
                : '${profile.missingRequiredDocuments.length} required document${profile.missingRequiredDocuments.length == 1 ? '' : 's'} missing',
            done: prog.documents,
            enabled: true,
            onTap: () => context.push(Routes.driverApplyDocuments),
          ),
          _StepTile(
            index: 4,
            title: 'Payout account',
            subtitle: prog.payout ? '${profile.payout.accountTitle ?? ''} · ${profile.payout.accountNumberMasked ?? ''}' : 'Required — where we send your earnings',
            done: prog.payout,
            enabled: true,
            onTap: () => context.push(Routes.driverApplyPayout),
          ),
          const SizedBox(height: AppSpace.md),
          if (!locked)
            AppButton(
              label: prog.readyToSubmit ? 'Review & submit' : 'Complete the steps above',
              icon: Icons.task_alt_rounded,
              onPressed: prog.readyToSubmit ? () => context.push(Routes.driverApplyReview) : null,
            )
          else
            AppButton(variant: AppButtonVariant.dark, label: 'View application status', onPressed: () => context.push(Routes.driverApplicationStatus)),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            const Icon(Icons.shield_moon_outlined, size: 18, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(child: Text('Your documents are stored privately and reviewed only by authorised FemaleRider staff.', style: AppText.caption)),
          ]),
        ]),
      ),
    ]);
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.title, required this.subtitle, required this.done, required this.enabled, required this.onTap});
  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: AppCard(
        onTap: enabled ? onTap : null,
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.success : AppColors.field),
            child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : Text('$index', style: AppText.title),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.title),
              Text(subtitle, style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
