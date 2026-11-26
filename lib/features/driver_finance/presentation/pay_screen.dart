import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/manual_payment_repository.dart';

/// Manual JazzCash payment: send money to FemaleRider's account from your phone, then
/// submit the TID and a screenshot. An admin verifies it and credits your balance.
class PayScreen extends ConsumerWidget {
  const PayScreen({super.key, this.embedded = false});

  /// Shown as the Wallet tab of the driver bottom bar (no back button).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(paymentInfoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(embedded ? 'Wallet' : 'Pay FemaleRider'),
        automaticallyImplyLeading: !embedded,
        actions: [
          if (embedded)
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(paymentInfoProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: AsyncView<PaymentInfo>(
        value: info,
        onRetry: () => ref.invalidate(paymentInfoProvider),
        data: (p) => _PayForm(info: p),
      ),
    );
  }
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({required this.info});
  final PaymentInfo info;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.info.amountDue > 0 ? widget.info.amountDue.ceil().toString() : '',
  );
  final _tid = TextEditingController();
  final _sender = TextEditingController();
  String? _screenshot;
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _amount.dispose();
    _tid.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickImagePath(context, title: 'Payment screenshot', allowCamera: false);
    if (path != null) setState(() => _screenshot = path);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_screenshot == null) {
      showSnack(context, 'Please attach the payment screenshot', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final (_, message) = await ref.read(manualPaymentRepositoryProvider).submit(
        amount: double.parse(_amount.text.trim()),
        transactionRef: _tid.text,
        screenshotPath: _screenshot!,
        senderNumber: _sender.text,
      );
      if (!mounted) return;
      showSnack(context, message ?? 'Submitted. We will verify it shortly.', success: true);
      _tid.clear();
      setState(() => _screenshot = null);
      ref.invalidate(paymentInfoProvider);
      ref.invalidate(depositsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showSnack(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.info;
    if (!p.enabled) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payments unavailable',
        message: 'The payment account is not set up yet. Please contact support.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your balance', style: AppText.caption),
                      Text(
                        formatMoney(p.balance),
                        style: AppText.money.copyWith(color: p.balance < 0 ? AppColors.danger : AppColors.success),
                      ),
                      const SizedBox(height: 4),
                      Text('5% commission is deducted from this balance after every ride.', style: AppText.caption),
                      const Divider(height: AppSpace.lg),
                      Row(
                        children: [
                          Expanded(child: _stat('Amount due', formatMoney(p.amountDue))),
                          Expanded(child: _stat('Awaiting verification', formatMoney(p.pendingAmount))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Send to JazzCash', style: AppText.h3),
                      const SizedBox(height: AppSpace.sm),
                      _copyRow('Account title', p.accountTitle),
                      _copyRow('JazzCash number', p.accountNumber),
                      if (p.instructions.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.sm),
                        Text(p.instructions, style: AppText.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                const InfoBanner(
                  tone: StatusTone.info,
                  icon: Icons.info_outline,
                  message: '1. Send the amount from your JazzCash / bank app.\n2. Enter the TID (transaction ID) and attach the screenshot.\n3. Admin verifies it and your balance is updated.',
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Amount sent (PKR)', errorText: _error?.fieldError('amount')),
                  validator: (v) {
                    final a = double.tryParse((v ?? '').trim());
                    if (a == null) return 'Enter the amount you sent';
                    if (a < p.minAmount || a > p.maxAmount) {
                      return 'Between ${formatMoney(p.minAmount)} and ${formatMoney(p.maxAmount)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _tid,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: 'TID / Transaction ID', errorText: _error?.fieldError('transaction_ref')),
                  validator: (v) => RegExp(r'^[A-Za-z0-9]{6,40}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 6–40 character TID',
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _sender,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Sent from number (optional)', errorText: _error?.fieldError('sender_number')),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  onTap: _pick,
                  child: _screenshot == null
                      ? const Row(children: [Icon(Icons.add_photo_alternate_outlined), SizedBox(width: AppSpace.sm), Text('Attach payment screenshot')])
                      : Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_screenshot!), width: 64, height: 64, fit: BoxFit.cover)),
                          const SizedBox(width: AppSpace.sm),
                          const Expanded(child: Text('Screenshot attached · tap to change')),
                        ]),
                ),
                if (_error?.fieldError('screenshot') != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!.fieldError('screenshot')!, style: const TextStyle(color: AppColors.crimson))),
                const SizedBox(height: AppSpace.lg),
                Text('Payment history', style: AppText.h3),
                const SizedBox(height: AppSpace.sm),
                const _History(),
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: AppButton(label: 'Submit for verification', loading: _saving, onPressed: _saving ? null : _submit),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label, style: AppText.caption), Text(value, style: AppText.h3)],
  );

  Widget _copyRow(String label, String value) => Row(
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppText.caption), Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w700))])),
      IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy_rounded, size: 20),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          showSnack(context, '$label copied');
        },
      ),
    ],
  );
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(depositsProvider);
    return list.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpace.md), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => TextButton(onPressed: () => ref.invalidate(depositsProvider), child: const Text('Could not load history · Retry')),
      data: (items) => items.isEmpty
          ? Text('No payments yet', style: AppText.caption)
          : Column(
              children: [
                for (final d in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatMoney(d.approvedAmount ?? d.amount), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                                Text('TID ${d.transactionRef}', style: AppText.caption),
                                if (d.rejectionReason != null) Text(d.rejectionReason!, style: AppText.caption.copyWith(color: AppColors.crimson)),
                              ],
                            ),
                          ),
                          StatusChip(label: d.status, tone: StatusChip.toneFor(d.status), dense: true),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
