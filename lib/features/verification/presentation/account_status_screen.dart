import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/redirect.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/session_controller.dart';
import 'verification_providers.dart';

/// Landing screen for customers whose eligibility is not yet approved.
class AccountStatusScreen extends ConsumerStatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  ConsumerState<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen> {
  Future<void> _refresh() async {
    ref.invalidate(verificationProvider);
    final me = await ref.read(sessionProvider.notifier).refreshMe();
    if (!mounted || me == null) return;
    final home = homeFor(me);
    if (home != Routes.accountStatus) context.go(home);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final e = user.eligibility;
    final (tone, icon) = eligibilityVisual(e.status);
    final verification = ref.watch(verificationProvider);
    final submittedAt = verification.value?.submittedAt;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandLogo(size: 44),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push(Routes.settings),
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: AppSpace.lg),
                Text('Hi ${user.firstName.isEmpty ? 'there' : user.firstName}', style: AppText.h1.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('Account status', style: AppText.body.copyWith(color: Colors.white70)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppCard(
                  shadow: true,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(color: AppColors.roseSoft, shape: BoxShape.circle),
                        child: Icon(icon, color: AppColors.crimson),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      const Expanded(child: Text('Identity verification', style: AppText.h3)),
                      StatusChip(label: e.label, tone: tone),
                    ]),
                    const SizedBox(height: AppSpace.md),
                    Text(eligibilityExplainer(e.status), style: AppText.body),
                    if (e.reason != null && e.reason!.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      InfoBanner(title: 'Reviewer note', message: e.reason!, tone: StatusTone.warning, icon: Icons.feedback_outlined),
                    ],
                    if (submittedAt != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text('Submitted ${formatDateTime(submittedAt)}', style: AppText.caption),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    ..._actions(user),
                  ]),
                ),
                if (e.isPendingReview) ...[
                  const SizedBox(height: AppSpace.md),
                  const InfoBanner(message: 'Pull down to refresh your status. We’ll also send you a notification when the review is complete.'),
                ],
                if (e.isApproved) ...[
                  const SizedBox(height: AppSpace.md),
                  AppCard(
                    onTap: () => context.push(user.driver.hasApplied ? Routes.driverApplicationStatus : Routes.driverApply),
                    child: const Row(children: [
                      Icon(Icons.drive_eta_rounded, color: AppColors.crimson),
                      SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Drive with FemaleRider', style: AppText.title),
                          Text('Earn on your schedule driving women passengers', style: AppText.bodySm),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ]),
                  ),
                ],
                const SectionHeader('Need help?', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: const Text('Eligibility policy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(Routes.legal('eligibility-policy')),
                    ),
                    const Divider(indent: 56),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded),
                      title: const Text('Contact support'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(Routes.support),
                    ),
                    const Divider(indent: 56),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      title: Text('Log out', style: AppText.title.copyWith(color: AppColors.danger)),
                      onTap: () async {
                        final ok = await showConfirmDialog(context, title: 'Log out?', message: 'You can sign in again any time with your phone number.', confirmLabel: 'Log out', destructive: true);
                        if (ok) await ref.read(sessionProvider.notifier).logout();
                      },
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(AppUser user) {
    final e = user.eligibility;
    final widgets = <Widget>[];
    if (e.isApproved) {
      widgets.add(AppButton(
        label: 'Continue',
        onPressed: () {
          final me = ref.read(sessionProvider.notifier).me;
          if (me != null) context.go(homeFor(me));
        },
      ));
    } else if (e.canSubmit || const ['draft', 'rejected', 'more_info_required'].contains(e.status)) {
      widgets.add(AppButton(
        label: e.status == 'draft' ? 'Verify your account' : 'Submit documents again',
        icon: Icons.upload_file_rounded,
        onPressed: () => context.push(Routes.verification),
      ));
    } else if (e.isPendingReview) {
      widgets.add(AppButton.secondary(label: 'Refresh status', icon: Icons.refresh_rounded, onPressed: _refresh));
    }
    if (e.canAppeal) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: AppSpace.sm));
      widgets.add(AppButton.secondary(label: 'Appeal decision', icon: Icons.gavel_rounded, onPressed: () => showAppealSheet(context, ref)));
    }
    return widgets;
  }
}
