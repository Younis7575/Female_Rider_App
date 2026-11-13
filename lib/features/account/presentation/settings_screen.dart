import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/account_repository.dart';

const _notificationLabels = {
  'push': ('Push notifications', 'Ride offers, trip updates and safety alerts'),
  'payment': ('Payment updates', 'Receipts, refunds and payouts'),
  'promotions': ('Promotions', 'Discounts and coupon codes'),
};

const _privacyLabels = {
  'share_trip_with_emergency_contact': ('Share trips with emergency contact', 'Automatically send your live trip link to your emergency contact'),
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Set<String> _saving = {};

  Future<void> _update(String key, Map<String, dynamic> body) async {
    setState(() => _saving.add(key));
    final user = await runGuarded<AppUser>(context, () => ref.read(accountRepositoryProvider).updateProfile(body));
    if (user != null) ref.read(sessionProvider.notifier).updateUser(user);
    if (mounted) setState(() => _saving.remove(key));
  }

  Future<void> _pickLanguage(AppUser user) async {
    final picked = await showAppSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Language', style: AppText.h3),
            const SizedBox(height: AppSpace.xs),
            RadioGroup<String>(
              groupValue: user.locale,
              onChanged: (v) => Navigator.of(ctx).pop(v),
              child: const Column(children: [
                RadioListTile<String>(value: 'en', title: Text('English'), activeColor: AppColors.crimson, contentPadding: EdgeInsets.zero),
                RadioListTile<String>(value: 'ur', title: Text('اردو (Urdu)'), activeColor: AppColors.crimson, contentPadding: EdgeInsets.zero),
              ]),
            ),
            Text('Notifications and receipts follow this language. In-app Urdu translations are coming soon.', style: AppText.caption),
          ]),
        ),
      ),
    );
    if (picked != null && picked != user.locale) await _update('locale', {'locale': picked});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final env = ref.watch(envProvider);
    if (user == null) return const Scaffold(body: LoadingView());

    Widget prefSwitch(String group, String key, (String, String) labels, Map<String, bool> current) {
      final value = current[key] ?? (group == 'notification_preferences');
      final id = '$group.$key';
      return SwitchListTile(
        value: value,
        title: Text(labels.$1, style: AppText.title),
        subtitle: Text(labels.$2, style: AppText.bodySm),
        secondary: _saving.contains(id) ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
        onChanged: _saving.contains(id)
            ? null
            : (v) => _update(id, {
                  group: {...current, key: v},
                }),
      );
    }

    final notif = {..._notificationLabels.map((k, _) => MapEntry(k, true)), ...user.notificationPreferences};
    final privacy = {..._privacyLabels.map((k, _) => MapEntry(k, false)), ...user.privacyPreferences};

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.only(bottom: AppSpace.xxl), children: [
        const SectionHeader('Account'),
        _Group(children: [
          ListTile(leading: const Icon(Icons.person_outline_rounded), title: const Text('Edit profile'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.editProfile)),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: const Text('Language'),
            subtitle: Text(user.locale == 'ur' ? 'اردو (Urdu)' : 'English'),
            trailing: _saving.contains('locale') ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickLanguage(user),
          ),
          ListTile(leading: const Icon(Icons.devices_rounded), title: const Text('Active sessions'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.sessions)),
        ]),
        const SectionHeader('Notifications'),
        _Group(children: [
          for (final e in _notificationLabels.entries) prefSwitch('notification_preferences', e.key, e.value, notif),
          for (final k in notif.keys.where((k) => !_notificationLabels.containsKey(k)))
            prefSwitch('notification_preferences', k, (k.replaceAll('_', ' '), ''), notif),
        ]),
        const SectionHeader('Privacy & safety'),
        _Group(children: [
          for (final e in _privacyLabels.entries) prefSwitch('privacy_preferences', e.key, e.value, privacy),
        ]),
        const SectionHeader('Help & legal'),
        _Group(children: [
          ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('Help center'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.support)),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Terms of service'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.legal('terms'))),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.legal('privacy'))),
          ListTile(leading: const Icon(Icons.policy_outlined), title: const Text('Eligibility policy'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(Routes.legal('eligibility-policy'))),
        ]),
        const SectionHeader('Danger zone'),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: Text('Log out', style: AppText.title.copyWith(color: AppColors.danger)),
            onTap: () async {
              final ok = await showConfirmDialog(context, title: 'Log out?', message: 'You will need to verify your phone number to sign in again.', confirmLabel: 'Log out', destructive: true);
              if (ok) await ref.read(sessionProvider.notifier).logout();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
            title: Text('Delete account', style: AppText.title.copyWith(color: AppColors.danger)),
            onTap: () => context.push(Routes.deleteAccount),
          ),
        ]),
        const SizedBox(height: AppSpace.lg),
        Center(
          child: Text(
            'FemaleRider v${env.appVersion}${env.isProduction ? '' : ' · ${env.appEnv}'}',
            style: AppText.caption.copyWith(color: AppColors.subtle),
          ),
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
    );
  }
}
