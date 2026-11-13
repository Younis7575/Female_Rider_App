import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_models.dart';
import '../data/payment_repository.dart';

/// Trip + receipt (the receipt's `refundable_amount` caps the request; null if unavailable).
final _refundTripProvider = FutureProvider.autoDispose.family<(Trip, Receipt?), String>((ref, id) async {
  final repo = ref.watch(tripRepositoryProvider);
  final trip = await repo.trip(id);
  Receipt? receipt;
  if (trip.isCompleted) {
    try {
      receipt = await repo.receipt(id);
    } catch (_) {}
  }
  return (trip, receipt);
});

/// Request a refund for a paid trip.
class RefundScreen extends ConsumerWidget {
  const RefundScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(_refundTripProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Request a refund')),
      body: AsyncView<(Trip, Receipt?)>(
        value: trip,
        onRetry: () => ref.invalidate(_refundTripProvider(tripId)),
        data: (d) => _RefundForm(trip: d.$1, receipt: d.$2),
      ),
    );
  }
}

class _RefundForm extends ConsumerStatefulWidget {
  const _RefundForm({required this.trip, this.receipt});
  final Trip trip;
  final Receipt? receipt;

  @override
  ConsumerState<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends ConsumerState<_RefundForm> {
  late final TextEditingController _amount;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  double get _paid => widget.receipt?.amountPaid ?? widget.trip.amountDue ?? widget.trip.displayFare;

  /// Server-computed refundable balance (excludes earlier refunds); falls back to the amount paid.
  double get _max => widget.receipt?.refundableAmount ?? _paid;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _max > 0 ? _max.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.trim());

  bool get _valid {
    final v = _value;
    return v != null && v >= 1 && v <= _max && _reason.text.trim().length >= 5;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (refund, message) = await ref.read(paymentRepositoryProvider).requestRefund(tripId: widget.trip.id, amount: _value!, reason: _reason.text.trim());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
          title: const Text('Refund requested'),
          content: Text('${message ?? 'Refund request submitted.'}\n\nAmount: ${formatMoney(refund.amount, currency: widget.trip.currency)}', textAlign: TextAlign.center),
          actions: [AppButton(label: 'Done', height: 48, onPressed: () => Navigator.of(ctx).pop())],
        ),
      );
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final paid = t.paymentStatus == 'paid';
    final v = _value;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatDateTime(t.timeline.completedAt ?? t.createdAt), style: AppText.caption),
              const SizedBox(height: 4),
              Text(t.dropoff.address ?? 'Trip', style: AppText.title, maxLines: 2),
              const SizedBox(height: AppSpace.sm),
              KeyValueRow('Amount paid', formatMoney(_paid, currency: t.currency), bold: true),
              if (widget.receipt?.refundableAmount != null) KeyValueRow('Refundable', formatMoney(_max, currency: t.currency)),
              KeyValueRow('Payment', '${humanize(t.paymentMethod)} · ${humanize(t.paymentStatus ?? '—')}'),
            ]),
          ),
          if (!paid) ...[
            const SizedBox(height: AppSpace.sm),
            const InfoBanner(tone: StatusTone.warning, message: 'Only paid trips can be refunded. If you have a problem with this trip, please contact support.'),
          ],
          if (paid && _max <= 0) ...[
            const SizedBox(height: AppSpace.sm),
            const InfoBanner(tone: StatusTone.info, message: 'This trip has already been fully refunded.'),
          ],
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Refund amount (${t.currency})',
              helperText: 'Up to ${formatMoney(_max, currency: t.currency)}',
              errorText: v != null && v > _max ? 'Amount exceeds the refundable balance' : null,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _reason,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true, hintText: 'e.g. I was overcharged, the trip was not completed…'),
          ),
          if (_error != null) InfoBanner(message: _error!, tone: StatusTone.danger, icon: Icons.error_outline_rounded),
        ]),
      ),
      BottomActionBar(child: AppButton(label: 'Submit refund request', loading: _busy, onPressed: _valid && paid ? _submit : null)),
    ]);
  }
}
