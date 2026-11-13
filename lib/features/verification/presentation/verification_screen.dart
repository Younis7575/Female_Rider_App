import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../../auth/presentation/session_controller.dart';
import 'verification_providers.dart';

/// Women-only eligibility verification (document upload + declaration).
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your account')),
      body: AsyncView<VerificationState>(
        value: state,
        onRetry: () => ref.invalidate(verificationProvider),
        data: (v) => v.canSubmit ? _VerificationForm(state: v) : _StatusView(state: v),
      ),
    );
  }
}

class _StatusView extends ConsumerWidget {
  const _StatusView({required this.state});
  final VerificationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, icon) = eligibilityVisual(state.status);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(verificationProvider);
        await ref.read(sessionProvider.notifier).refreshMe();
      },
      child: ListView(padding: const EdgeInsets.all(AppSpace.md), physics: const AlwaysScrollableScrollPhysics(), children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(children: [
            Icon(icon, size: 56, color: AppColors.crimson),
            const SizedBox(height: AppSpace.sm),
            StatusChip(label: state.label, tone: tone),
            const SizedBox(height: AppSpace.md),
            Text(eligibilityExplainer(state.status), style: AppText.body, textAlign: TextAlign.center),
            if (state.reason != null && state.reason!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              InfoBanner(title: 'Reviewer note', message: state.reason!, tone: StatusTone.warning),
            ],
            const SizedBox(height: AppSpace.md),
            if (state.documentType != null) KeyValueRow('Document', documentLabel(state.documentType!)),
            if (state.submittedAt != null) KeyValueRow('Submitted', formatDateTime(state.submittedAt)),
            if (state.reviewedAt != null) KeyValueRow('Reviewed', formatDateTime(state.reviewedAt)),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        if (state.canAppeal) AppButton(label: 'Appeal decision', icon: Icons.gavel_rounded, onPressed: () => showAppealSheet(context, ref)),
        const SizedBox(height: AppSpace.sm),
        AppButton.secondary(label: 'Contact support', icon: Icons.support_agent_rounded, onPressed: () => context.push(Routes.support)),
      ]),
    );
  }
}

class _VerificationForm extends ConsumerStatefulWidget {
  const _VerificationForm({required this.state});
  final VerificationState state;

  @override
  ConsumerState<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends ConsumerState<_VerificationForm> {
  late String _docType = widget.state.acceptedDocuments.isNotEmpty ? widget.state.acceptedDocuments.first : 'cnic';
  String? _front;
  String? _back;
  String? _selfie;
  bool _declaration = false;
  bool _consent = false;
  bool _submitting = false;

  bool get _ready => _front != null && (!widget.state.requireSelfie || _selfie != null) && _declaration && _consent;

  Future<void> _pick(void Function(String) set, String title) async {
    final path = await pickImagePath(context, title: title);
    if (path != null) setState(() => set(path));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final msg = await runGuarded(context, () async {
      final m = await ref.read(accountRepositoryProvider).submitVerification(
            documentType: _docType,
            frontPath: _front!,
            backPath: _back,
            selfiePath: _selfie,
          );
      return m ?? 'Submitted for review.';
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (msg == null) return;
    await ref.read(sessionProvider.notifier).refreshMe();
    ref.invalidate(verificationProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 40),
        title: const Text('Documents submitted'),
        content: Text(msg),
        actions: [AppButton(label: 'Done', height: 48, onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
    if (mounted) context.canPop() ? context.pop() : context.go(Routes.accountStatus);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
          AppCard(
            color: AppColors.roseSoft,
            border: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.shield_moon_outlined, color: AppColors.crimson),
                const SizedBox(width: AppSpace.xs),
                const Expanded(child: Text('Why we verify', style: AppText.title)),
                if (s.policyVersion != null) Text('Policy v${s.policyVersion}', style: AppText.caption),
              ]),
              const SizedBox(height: AppSpace.xs),
              Text(s.policySummary, style: AppText.bodySm.copyWith(color: AppColors.inkSoft)),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push(Routes.legal('eligibility-policy')),
                child: const Text('Read the full eligibility policy'),
              ),
            ]),
          ),
          if (s.reason != null && s.reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            InfoBanner(title: 'Reviewer note', message: s.reason!, tone: StatusTone.warning),
          ],
          const SectionHeader('Document type', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
          Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
            for (final t in s.acceptedDocuments)
              ChoiceChip(
                label: Text(documentLabel(t)),
                selected: _docType == t,
                onSelected: (_) => setState(() => _docType = t),
              ),
          ]),
          const SectionHeader('Upload photos', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
          _UploadTile(label: 'Front of document', required: true, path: _front, onTap: () => _pick((p) => _front = p, 'Front of document'), onClear: () => setState(() => _front = null)),
          const SizedBox(height: AppSpace.sm),
          _UploadTile(label: 'Back of document', path: _back, onTap: () => _pick((p) => _back = p, 'Back of document'), onClear: () => setState(() => _back = null)),
          const SizedBox(height: AppSpace.sm),
          _UploadTile(
            label: 'Selfie',
            required: s.requireSelfie,
            hint: 'A clear photo of your face in good light',
            path: _selfie,
            onTap: () => _pick((p) => _selfie = p, 'Take a selfie'),
            onClear: () => setState(() => _selfie = null),
          ),
          const SizedBox(height: AppSpace.lg),
          CheckboxListTile(
            value: _declaration,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _declaration = v ?? false),
            title: const Text('I confirm I meet the FemaleRider women-only eligibility policy.', style: AppText.body),
          ),
          CheckboxListTile(
            value: _consent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text('I consent to FemaleRider securely storing and reviewing these documents for verification.', style: AppText.body),
          ),
        ]),
      ),
      BottomActionBar(child: AppButton(label: 'Submit for review', loading: _submitting, onPressed: _ready ? _submit : null)),
    ]);
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.label, this.required = false, this.hint, required this.path, required this.onTap, required this.onClear});
  final String label;
  final bool required;
  final String? hint;
  final String? path;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 72,
            height: 56,
            color: AppColors.field,
            child: path == null ? const Icon(Icons.add_a_photo_outlined, color: AppColors.muted) : Image.file(File(path!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label${required ? ' *' : ' (optional)'}', style: AppText.title),
            Text(path == null ? (hint ?? 'Tap to take or choose a photo') : 'Ready to upload · tap to replace', style: AppText.caption),
          ]),
        ),
        if (path != null)
          IconButton(tooltip: 'Remove $label', icon: const Icon(Icons.close_rounded), onPressed: onClear)
        else
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}
