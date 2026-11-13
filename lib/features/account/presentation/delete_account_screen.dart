import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/account_repository.dart';

/// Account deletion request (soft delete with retention period).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _reason = TextEditingController();
  bool _understood = false;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message: 'You will be signed out on all devices. Signing in again within 30 days cancels the request; after that your data is removed once the legal retention period ends.',
      confirmLabel: 'Delete account',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final message = await runGuarded(context, () async {
      final m = await ref.read(accountRepositoryProvider).requestDeletion(reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
      return m ?? 'Your deletion request has been received.';
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Request received'),
        content: Text(message),
        actions: [AppButton(label: 'OK', height: 48, onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
    await ref.read(sessionProvider.notifier).clearLocal();
  }

  @override
  Widget build(BuildContext context) {
    const points = [
      'Your profile, saved places and ride history will be scheduled for deletion.',
      'Pending payouts or refunds may be lost — settle them first.',
      'Some records (payments, safety reports) are kept as required by law.',
      'Signing in again within 30 days cancels the request.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            const InfoBanner(
              title: 'This is permanent after 30 days',
              message: 'Please read what happens before you continue.',
              tone: StatusTone.danger,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: AppSpace.md),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.circle, size: 8, color: AppColors.crimson)),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(p, style: AppText.body)),
                ]),
              ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Why are you leaving? (optional)', alignLabelWithHint: true),
            ),
            CheckboxListTile(
              value: _understood,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: const Text('I understand my account will be deleted', style: AppText.body),
            ),
          ]),
        ),
        BottomActionBar(child: AppButton.danger(label: 'Delete my account', loading: _busy, onPressed: _understood ? _delete : null)),
      ]),
    );
  }
}
