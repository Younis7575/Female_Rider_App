import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/driver_tracker.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/redirect.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dialogs.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/account_repository.dart';

enum AppMode { customer, driver }

/// Outcome of a mode switch attempt (used by the UI and tests).
enum ModeSwitchOutcome { switched, needsApplication, applicationPending, blocked, unchanged }

/// CUSTOMER ⇄ DRIVER switching rules on the client side.
/// The server stays authoritative (`POST /me/mode`); its errors are surfaced verbatim.
class ModeSwitchController {
  ModeSwitchController(this.ref);
  final WidgetRef ref;

  Future<(ModeSwitchOutcome, String?)> switchTo(AppMode target) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return (ModeSwitchOutcome.blocked, null);
    final targetName = target == AppMode.driver ? 'driver' : 'customer';
    if (user.activeMode == targetName) return (ModeSwitchOutcome.unchanged, null);

    if (target == AppMode.driver && !user.canUseDriverMode) {
      return user.driver.hasApplied ? (ModeSwitchOutcome.applicationPending, null) : (ModeSwitchOutcome.needsApplication, null);
    }
    try {
      final (updated, message) = await ref.read(accountRepositoryProvider).switchMode(targetName);
      ref.read(sessionProvider.notifier).updateUser(updated);
      return (ModeSwitchOutcome.switched, message);
    } on ApiException catch (e) {
      if (e.code == 'driver_not_approved') return (ModeSwitchOutcome.applicationPending, e.message);
      return (ModeSwitchOutcome.blocked, e.message);
    }
  }
}

/// Full switch UX: go-offline prompt, server call, navigation and snackbar errors.
///
/// * Customer → driver: not-approved drivers are sent to the application / status flow;
///   approved drivers call `POST /me/mode {mode: driver}` and land on the driver dashboard.
/// * Driver → customer: an online driver is asked to go offline first, then
///   `POST /me/mode {mode: customer}`.
Future<void> performModeSwitch(BuildContext context, WidgetRef ref, AppMode target) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  if (target == AppMode.customer && (user.driver.isOnline || ref.read(driverTrackerProvider).online)) {
    final goOffline = await showConfirmDialog(
      context,
      title: 'Go offline first?',
      message: 'You are online and may receive ride requests. Go offline to switch to Customer mode.',
      confirmLabel: 'Go offline & switch',
      icon: Icons.power_settings_new_rounded,
    );
    if (!goOffline || !context.mounted) return;
    final ok = await runGuarded(context, () async {
      await ref.read(driverTrackerProvider.notifier).goOffline();
      return true;
    });
    if (ok != true || !context.mounted) return;
  }

  final (outcome, message) = await ModeSwitchController(ref).switchTo(target);
  if (!context.mounted) return;
  switch (outcome) {
    case ModeSwitchOutcome.switched:
      showSnack(context, message ?? 'Mode switched', success: true);
      final me = ref.read(sessionProvider.notifier).me;
      if (me != null) context.go(homeFor(me));
    case ModeSwitchOutcome.needsApplication:
      context.push(user.eligibility.isApproved ? Routes.driverApply : Routes.accountStatus);
    case ModeSwitchOutcome.applicationPending:
      if (message != null) showSnack(context, message);
      context.push(Routes.driverApplicationStatus);
    case ModeSwitchOutcome.blocked:
      if (message != null) showSnack(context, message, error: true);
    case ModeSwitchOutcome.unchanged:
      break;
  }
}

/// The single place to switch modes: an item in the navigation drawer.
/// Customer mode → "Drive with FemaleRider"; driver mode → "Switch to Customer mode".
class ModeSwitchTile extends ConsumerStatefulWidget {
  const ModeSwitchTile({super.key});

  @override
  ConsumerState<ModeSwitchTile> createState() => _ModeSwitchTileState();
}

class _ModeSwitchTileState extends ConsumerState<ModeSwitchTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final driver = user?.isDriverMode ?? false;
    final approved = user?.canUseDriverMode ?? false;
    final title = driver ? 'Switch to Customer mode' : 'Drive with FemaleRider';
    final subtitle = driver
        ? 'Book rides as a passenger'
        : approved
            ? 'Go to your driver dashboard'
            : (user?.driver.hasApplied ?? false)
                ? 'View your driver application'
                : 'Earn on your schedule — apply to drive';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
      child: Material(
        color: driver ? AppColors.roseSoft : AppColors.night,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ListTile(
          key: const ValueKey('mode-switch-tile'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          leading: Icon(driver ? Icons.person_pin_circle_rounded : Icons.drive_eta_rounded, color: driver ? AppColors.crimson : Colors.white),
          title: Text(title, style: AppText.title.copyWith(color: driver ? AppColors.crimson : Colors.white)),
          subtitle: Text(subtitle, style: AppText.caption.copyWith(color: driver ? AppColors.inkSoft : Colors.white70)),
          trailing: _busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: driver ? AppColors.crimson : Colors.white))
              : Icon(Icons.swap_horiz_rounded, color: driver ? AppColors.crimson : Colors.white),
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await performModeSwitch(context, ref, driver ? AppMode.customer : AppMode.driver);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ),
    );
  }
}

/// Small, non-interactive badge showing the current mode (e.g. in the driver header).
class ModeBadge extends ConsumerWidget {
  const ModeBadge({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentUserProvider)?.isDriverMode ?? false;
    final bg = onDark ? Colors.white.withValues(alpha: 0.14) : AppColors.roseSoft;
    final fg = onDark ? Colors.white : AppColors.crimson;
    return Semantics(
      label: driver ? 'Driver mode' : 'Customer mode',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(driver ? Icons.drive_eta_rounded : Icons.person_pin_circle_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(driver ? 'DRIVER MODE' : 'CUSTOMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: fg)),
        ]),
      ),
    );
  }
}
