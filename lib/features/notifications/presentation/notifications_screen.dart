import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/widgets/paged_list.dart';
import '../../auth/presentation/session_controller.dart';

/// Notification inbox with paging, mark-read and deep links.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _listKey = GlobalKey<PagedListViewState<AppNotification>>();
  int _unread = 0;

  Future<Paged<AppNotification>> _fetch(int page) async {
    final (paged, unread) = await ref.read(accountRepositoryProvider).notifications(page: page);
    if (mounted) {
      setState(() => _unread = unread);
      ref.read(sessionProvider.notifier).setUnread(unread);
    }
    return paged;
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      _listKey.currentState?.updateWhere((x) => x.id == n.id, (x) => x.markRead());
      final unread = (_unread - 1).clamp(0, 1 << 30);
      setState(() => _unread = unread);
      ref.read(sessionProvider.notifier).setUnread(unread);
      try {
        await ref.read(accountRepositoryProvider).markNotificationRead(n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    if (n.data['screen'] != null) {
      final driver = ref.read(currentUserProvider)?.isDriverMode ?? false;
      context.push(routeForNotification(n.data, driverMode: driver));
    }
  }

  Future<void> _markAll() async {
    final ok = await runGuarded(context, () async {
      await ref.read(accountRepositoryProvider).markAllNotificationsRead();
      return true;
    }, successMessage: 'All caught up');
    if (ok == true) {
      _listKey.currentState?.mapAll((n) => n.markRead());
      setState(() => _unread = 0);
      ref.read(sessionProvider.notifier).setUnread(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unread > 0) TextButton(onPressed: _markAll, child: const Text('Mark all read')),
        ],
      ),
      body: PagedListView<AppNotification>(
        key: _listKey,
        fetch: _fetch,
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        separator: const Divider(indent: 72),
        empty: const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          message: 'Ride offers, trip updates and payment receipts will appear here.',
        ),
        itemBuilder: (ctx, n, _) => _NotificationTile(n: n, onTap: () => _open(n)),
      ),
    );
  }
}

IconData _iconFor(String type) {
  if (type.startsWith('trip')) return Icons.local_taxi_rounded;
  if (type.startsWith('ride')) return Icons.near_me_rounded;
  if (type.startsWith('payment') || type.startsWith('refund') || type.startsWith('payout')) return Icons.payments_rounded;
  if (type.startsWith('driver')) return Icons.badge_rounded;
  if (type.startsWith('verification') || type.startsWith('eligibility')) return Icons.verified_user_rounded;
  if (type.startsWith('safety') || type.startsWith('sos')) return Icons.shield_rounded;
  if (type.startsWith('support')) return Icons.support_agent_rounded;
  return Icons.notifications_rounded;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: n.read ? Colors.transparent : AppColors.roseSoft.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: n.read ? AppColors.field : AppColors.surface, shape: BoxShape.circle),
              child: Icon(_iconFor(n.type), color: n.read ? AppColors.muted : AppColors.crimson, size: 22),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.title, style: AppText.title.copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700))),
                  Text(formatRelative(n.createdAt), style: AppText.caption),
                ]),
                if (n.body != null && n.body!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.body!, style: AppText.bodySm),
                ],
              ]),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
