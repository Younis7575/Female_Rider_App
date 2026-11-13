import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../verification/presentation/verification_providers.dart';
import 'mode_switcher.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final driver = user.isDriverMode;
    final (tone, _) = eligibilityVisual(user.eligibility.status);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionProvider.notifier).refreshMe(),
        child: ListView(padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(), children: [
          GradientHeader(
            driver: driver,
            child: Column(children: [
              Row(children: [
                const BackButton(color: Colors.white),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push(Routes.editProfile),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  label: const Text('Edit', style: TextStyle(color: Colors.white)),
                ),
              ]),
              AppAvatar(url: user.photoUrl, name: user.name, size: 88),
              const SizedBox(height: AppSpace.sm),
              Text(user.name ?? 'Your name', style: AppText.h2.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                RatingBadge(rating: user.rating, light: true),
                Text('  ·  ${user.ratingCount} ratings', style: AppText.caption.copyWith(color: Colors.white70)),
              ]),
              const SizedBox(height: AppSpace.md),
              const ModeBadge(onDark: true),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(children: [
              AppCard(
                child: Column(children: [
                  KeyValueRow('Phone', user.phone),
                  KeyValueRow('Email', (user.email ?? '').isEmpty ? 'Not added' : user.email!),
                  KeyValueRow('Language', user.locale == 'ur' ? 'اردو (Urdu)' : 'English'),
                ]),
              ),
              const SizedBox(height: AppSpace.sm),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Emergency contact', style: AppText.title),
                  const SizedBox(height: 4),
                  Text(
                    (user.emergencyContactName ?? '').isEmpty ? 'Add someone we can reach if you trigger SOS.' : '${user.emergencyContactName} · ${user.emergencyContactPhone ?? ''}',
                    style: AppText.bodySm,
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.sm),
              AppCard(
                onTap: () => context.push(user.eligibility.isApproved ? Routes.verification : Routes.accountStatus),
                child: Row(children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.crimson),
                  const SizedBox(width: AppSpace.sm),
                  const Expanded(child: Text('Identity verification', style: AppText.title)),
                  StatusChip(label: user.eligibility.label, tone: tone, dense: true),
                ]),
              ),
              const SizedBox(height: AppSpace.sm),
              AppCard(
                onTap: () => context.push(user.driver.hasApplied ? Routes.driverApplicationStatus : Routes.driverApply),
                child: Row(children: [
                  const Icon(Icons.drive_eta_outlined, color: AppColors.crimson),
                  const SizedBox(width: AppSpace.sm),
                  const Expanded(child: Text('Driver account', style: AppText.title)),
                  StatusChip(label: humanize(user.driver.status), tone: StatusChip.toneFor(user.driver.status), dense: true),
                ]),
              ),
              const SizedBox(height: AppSpace.lg),
              AppButton.secondary(label: 'Settings', icon: Icons.settings_outlined, onPressed: () => context.push(Routes.settings)),
            ]),
          ),
        ]),
      ),
    );
  }
}
