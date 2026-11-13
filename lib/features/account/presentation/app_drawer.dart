import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../auth/presentation/session_controller.dart';
import 'mode_switcher.dart';

/// Side menu shared by both modes (charcoal header in driver mode).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);
    final unread = session is SessionSignedIn ? session.me.unreadNotifications : 0;
    final driver = user?.isDriverMode ?? false;

    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    final items = <Widget>[
      // The only place to switch modes.
      const ModeSwitchTile(),
      const SizedBox(height: AppSpace.xs),
      if (driver) ...[
        _Item(icon: Icons.dashboard_rounded, label: 'Dashboard', onTap: () {
          Navigator.of(context).pop();
          context.go(Routes.driverHome);
        }),
        _Item(icon: Icons.notifications_active_outlined, label: 'Ride requests', onTap: () => go(Routes.driverRequests)),
        _Item(icon: Icons.account_balance_wallet_outlined, label: 'Earnings', onTap: () => go(Routes.driverEarnings)),
        _Item(icon: Icons.receipt_long_outlined, label: 'Ledger', onTap: () => go(Routes.driverLedger)),
        _Item(icon: Icons.payments_outlined, label: 'Payouts', onTap: () => go(Routes.driverPayouts)),
        _Item(icon: Icons.summarize_outlined, label: 'Statements', onTap: () => go(Routes.driverStatements)),
        _Item(icon: Icons.history_rounded, label: 'Ride history', onTap: () => go(Routes.history(as: 'driver'))),
        _Item(icon: Icons.folder_open_rounded, label: 'Documents', onTap: () => go(Routes.driverDocuments)),
        _Item(icon: Icons.badge_outlined, label: 'Driver profile', onTap: () => go(Routes.driverApplicationStatus)),
      ] else ...[
        _Item(icon: Icons.history_rounded, label: 'Your rides', onTap: () => go(Routes.history())),
        _Item(icon: Icons.payments_outlined, label: 'Payments', onTap: () => go(Routes.payments)),
        _Item(icon: Icons.local_offer_outlined, label: 'Coupons', onTap: () => go(Routes.coupons)),
        _Item(icon: Icons.bookmark_border_rounded, label: 'Saved places', onTap: () => go(Routes.savedPlaces)),
      ],
      _Item(icon: Icons.notifications_none_rounded, label: 'Notifications', badge: unread, onTap: () => go(Routes.notifications)),
      const Divider(height: 24),
      _Item(icon: Icons.support_agent_rounded, label: 'Support & help', onTap: () => go(Routes.support)),
      _Item(icon: Icons.shield_outlined, label: 'Report a safety issue', onTap: () => go(Routes.safetyReportBase)),
      _Item(icon: Icons.settings_outlined, label: 'Settings', onTap: () => go(Routes.settings)),
      _Item(
        icon: Icons.logout_rounded,
        label: 'Log out',
        danger: true,
        onTap: () async {
          final ok = await showConfirmDialog(context, title: 'Log out?', message: 'You will need to verify your phone number to sign in again.', confirmLabel: 'Log out', destructive: true);
          if (ok) await ref.read(sessionProvider.notifier).logout();
        },
      ),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(children: [
        GestureDetector(
          onTap: () => go(Routes.profile),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: driver ? AppColors.driverGradient : AppColors.brandGradient),
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
            child: SafeArea(
              bottom: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AppAvatar(url: user?.photoUrl, name: user?.name, size: 56),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.name ?? 'FemaleRider', style: AppText.h3.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        RatingBadge(rating: user?.rating, light: true),
                        const SizedBox(width: 8),
                        Flexible(child: Text(user?.phone ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: Colors.white70))),
                      ]),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ]),
                const SizedBox(height: AppSpace.sm),
                const ModeBadge(onDark: true),
              ]),
            ),
          ),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: AppSpace.xs), children: items)),
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text('FemaleRider · women-only rides', style: AppText.caption.copyWith(color: AppColors.subtle)),
        ),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap, this.badge = 0, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : AppColors.inkSoft),
      title: Text(label, style: AppText.title.copyWith(color: color)),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Bell with unread badge for app bars.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final unread = session is SessionSignedIn ? session.me.unreadNotifications : 0;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.crimson,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(Icons.notifications_none_rounded, color: onDark ? Colors.white : AppColors.ink),
      ),
    );
  }
}

String modeLabel(bool driver) => driver ? 'Driver mode' : 'Customer mode';
String greeting(String? name) {
  final h = DateTime.now().hour;
  final part = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  final f = firstName(name);
  return f.isEmpty ? part : '$part, $f';
}
