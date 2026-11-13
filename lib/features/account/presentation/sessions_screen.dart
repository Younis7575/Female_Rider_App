import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) => ref.watch(accountRepositoryProvider).sessions());

/// Signed-in devices (Sanctum tokens) with revoke actions.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Active sessions')),
      body: AsyncView<List<SessionInfo>>(
        value: sessions,
        onRetry: () => ref.invalidate(sessionsProvider),
        data: (list) {
          final others = list.where((s) => !s.current).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(sessionsProvider.future),
            child: ListView(padding: const EdgeInsets.all(AppSpace.md), physics: const AlwaysScrollableScrollPhysics(), children: [
              Text('These devices are signed in to your account. Revoke any you don’t recognise.', style: AppText.bodySm),
              const SizedBox(height: AppSpace.md),
              for (final s in list) ...[
                AppCard(
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: s.current ? AppColors.successSoft : AppColors.field, shape: BoxShape.circle),
                      child: Icon(Icons.smartphone_rounded, color: s.current ? AppColors.success : AppColors.inkSoft),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.device, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          s.lastUsedAt != null ? 'Last active ${formatRelative(s.lastUsedAt)}' : 'Signed in ${formatDate(s.createdAt)}',
                          style: AppText.caption,
                        ),
                      ]),
                    ),
                    if (s.current)
                      const StatusChip(label: 'This device', tone: StatusTone.success, dense: true)
                    else
                      TextButton(
                        onPressed: () async {
                          final ok = await showConfirmDialog(context, title: 'Revoke session?', message: '“${s.device}” will be signed out.', confirmLabel: 'Revoke', destructive: true);
                          if (!ok || !context.mounted) return;
                          final done = await runGuarded(context, () async {
                            await ref.read(accountRepositoryProvider).revokeSession(s.id);
                            return true;
                          }, successMessage: 'Session revoked');
                          if (done == true) ref.invalidate(sessionsProvider);
                        },
                        child: const Text('Revoke'),
                      ),
                  ]),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              if (others.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                AppButton.danger(
                  label: 'Sign out all other devices',
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    final ok = await showConfirmDialog(context, title: 'Sign out other devices?', message: '${others.length} other session(s) will be signed out.', confirmLabel: 'Sign out', destructive: true);
                    if (!ok || !context.mounted) return;
                    final done = await runGuarded(context, () async {
                      await ref.read(accountRepositoryProvider).revokeOtherSessions();
                      return true;
                    }, successMessage: 'Other sessions signed out');
                    if (done == true) ref.invalidate(sessionsProvider);
                  },
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}
