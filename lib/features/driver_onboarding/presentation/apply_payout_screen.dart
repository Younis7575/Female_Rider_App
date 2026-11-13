import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/apply_scaffold.dart';
import 'widgets/form_helpers.dart';

/// Application step 4 (also used later to update the account): payout account.
class ApplyPayoutScreen extends ConsumerWidget {
  const ApplyPayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return ApplyScaffold(
      step: 4,
      title: 'Payout account',
      child: AsyncView<DriverProfile>(
        value: profile,
        onRetry: () => ref.invalidate(driverProfileProvider),
        data: (p) => _PayoutForm(profile: p),
      ),
    );
  }
}

class _PayoutForm extends ConsumerStatefulWidget {
  const _PayoutForm({required this.profile});
  final DriverProfile profile;

  @override
  ConsumerState<_PayoutForm> createState() => _PayoutFormState();
}

class _PayoutFormState extends ConsumerState<_PayoutForm> {
  static const _methods = {
    'bank_transfer': ('Bank transfer', Icons.account_balance_rounded, 'IBAN or account number'),
    'jazzcash': ('JazzCash', Icons.phone_android_rounded, 'JazzCash mobile account number'),
    'easypaisa': ('Easypaisa', Icons.phone_iphone_rounded, 'Easypaisa mobile account number'),
  };

  final _form = GlobalKey<FormState>();
  late String _method = widget.profile.payout.method ?? 'bank_transfer';
  late final _title = TextEditingController(text: widget.profile.payout.accountTitle ?? widget.profile.fullName ?? '');
  final _number = TextEditingController();
  ApiException? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(driverRepositoryProvider).updatePayoutAccount(method: _method, title: _title.text.trim(), number: _number.text.trim());
      ref.invalidate(driverProfileProvider);
      if (!mounted) return;
      showSnack(context, 'Payout account saved', success: true);
      final p = widget.profile;
      if (p.status == 'approved' || !p.canEdit) {
        context.pop();
      } else {
        context.pushReplacement(Routes.driverApplyReview);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.profile.payout;
    return Column(children: [
      Expanded(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            Text('Where should we send your earnings? The account title must match your name.', style: AppText.bodySm),
            if (current.isSet) ...[
              const SizedBox(height: AppSpace.sm),
              InfoBanner(
                tone: StatusTone.success,
                icon: Icons.check_circle_outline_rounded,
                message: 'Current: ${_methods[current.method]?.$1 ?? current.method} · ${current.accountTitle ?? ''} · ${current.accountNumberMasked ?? ''}',
              ),
            ],
            const FormSectionLabel('Method'),
            RadioGroup<String>(
              groupValue: _method,
              onChanged: (m) => setState(() => _method = m ?? _method),
              child: Column(children: [
                for (final e in _methods.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      onTap: () => setState(() => _method = e.key),
                      color: _method == e.key ? AppColors.roseSoft : null,
                      child: RadioListTile<String>(
                        value: e.key,
                        activeColor: AppColors.crimson,
                        secondary: Icon(e.value.$2, color: _method == e.key ? AppColors.crimson : AppColors.inkSoft),
                        title: Text(e.value.$1, style: AppText.title),
                      ),
                    ),
                  ),
              ]),
            ),
            const FormSectionLabel('Account'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Account title', errorText: _error?.fieldError('payout_account_title')),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _number,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(34)],
              decoration: InputDecoration(
                labelText: 'Account number',
                hintText: _methods[_method]!.$3,
                helperText: current.isSet ? 'Re-enter the full number to update' : '8–34 letters or digits, no spaces',
                errorText: _error?.fieldError('payout_account_number'),
              ),
              validator: (v) => v == null || !RegExp(r'^[A-Za-z0-9]{8,34}$').hasMatch(v.trim()) ? 'Enter 8–34 letters or digits' : null,
            ),
            const SizedBox(height: AppSpace.md),
            Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text('Account details are encrypted and only shown masked.', style: AppText.caption)),
            ]),
            const SizedBox(height: AppSpace.xl),
          ]),
        ),
      ),
      BottomActionBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppButton(label: 'Save payout account', loading: _saving, onPressed: _save),
          if (widget.profile.canEdit && widget.profile.status != 'approved')
            TextButton(onPressed: () => context.pushReplacement(Routes.driverApplyReview), child: const Text('Skip for now')),
        ]),
      ),
    ]);
  }
}
