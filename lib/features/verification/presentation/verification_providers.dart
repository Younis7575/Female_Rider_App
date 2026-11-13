import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../../auth/presentation/session_controller.dart';

final verificationProvider = FutureProvider.autoDispose<VerificationState>((ref) {
  return ref.watch(accountRepositoryProvider).verification();
});

/// Visual tone + icon for an eligibility status.
(StatusTone, IconData) eligibilityVisual(String status) => switch (status) {
      'approved' => (StatusTone.success, Icons.verified_rounded),
      'submitted' || 'under_review' || 'appealed' => (StatusTone.warning, Icons.hourglass_top_rounded),
      'rejected' || 'suspended' => (StatusTone.danger, Icons.gpp_bad_rounded),
      'more_info_required' => (StatusTone.danger, Icons.assignment_late_rounded),
      _ => (StatusTone.brand, Icons.badge_outlined),
    };

String eligibilityExplainer(String status) => switch (status) {
      'draft' => 'To keep FemaleRider women-only, we ask every member to verify her identity once. It takes about 2 minutes.',
      'submitted' => 'Thanks! Your documents were received and are waiting for a reviewer. We usually respond within 24 hours.',
      'under_review' => 'A trained reviewer is checking your documents right now. We’ll notify you as soon as there’s a decision.',
      'approved' => 'You’re verified. Welcome to FemaleRider!',
      'rejected' => 'We couldn’t approve your verification. You can submit new documents or appeal the decision.',
      'more_info_required' => 'We need a little more information. Please re-submit clearer or additional documents.',
      'suspended' => 'Your verification has been suspended. You can appeal this decision or contact support.',
      'appealed' => 'Your appeal has been received and will be reviewed by a senior reviewer.',
      _ => 'Verify your account to start riding.',
    };

/// Bottom sheet to appeal an eligibility decision. Returns true when submitted.
Future<bool> showAppealSheet(BuildContext context, WidgetRef ref) async {
  final res = await showAppSheet<bool>(context, builder: (ctx) => const _AppealSheet());
  if (res == true) {
    ref.invalidate(verificationProvider);
    await ref.read(sessionProvider.notifier).refreshMe();
  }
  return res ?? false;
}

class _AppealSheet extends ConsumerStatefulWidget {
  const _AppealSheet();

  @override
  ConsumerState<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends ConsumerState<_AppealSheet> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final msg = await runGuarded(context, () async {
      final m = await ref.read(accountRepositoryProvider).appealVerification(_reason.text.trim());
      return m ?? 'Appeal submitted.';
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (msg != null) {
      showSnack(context, msg, success: true);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final len = _reason.text.trim().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Appeal decision', style: AppText.h2),
        const SizedBox(height: AppSpace.xs),
        Text('Explain why you believe the decision should be reviewed. A senior reviewer will look at your case.', style: AppText.bodySm),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _reason,
          maxLines: 5,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Your explanation (at least 10 characters)'),
        ),
        const SizedBox(height: AppSpace.sm),
        AppButton(label: 'Submit appeal', loading: _busy, onPressed: len >= 10 ? _submit : null),
      ]),
    );
  }
}
