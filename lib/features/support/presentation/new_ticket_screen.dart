import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/support_repository.dart';

const _categoryLabels = {
  'general': ('General question', Icons.help_outline_rounded),
  'lost_item': ('Lost item', Icons.backpack_outlined),
  'complaint': ('Complaint', Icons.report_outlined),
  'payment': ('Payment', Icons.payments_outlined),
  'fare_dispute': ('Fare dispute', Icons.price_change_outlined),
  'refund': ('Refund', Icons.currency_exchange_rounded),
  'account': ('Account', Icons.manage_accounts_outlined),
  'driver': ('Driving with us', Icons.drive_eta_outlined),
  'safety': ('Safety', Icons.shield_outlined),
};

/// Create a support ticket (optionally about a trip, with an attachment).
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.tripId});
  final String? tripId;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  String? _attachment;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) _category = 'lost_item';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final (ticket, message) = await ref.read(supportRepositoryProvider).createTicket(
            category: _category,
            subject: _subject.text.trim(),
            message: _message.text.trim(),
            tripId: widget.tripId,
            attachmentPath: _attachment,
          );
      if (!mounted) return;
      showSnack(context, message ?? 'Ticket ${ticket.reference} created', success: true);
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New ticket')),
      body: Form(
        key: _form,
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
              if (widget.tripId != null) ...[
                InfoBanner(message: 'This ticket will be linked to your trip so our team can see the details.', icon: Icons.link_rounded),
                const SizedBox(height: AppSpace.md),
              ],
              const Text('What do you need help with?', style: AppText.h3),
              const SizedBox(height: AppSpace.sm),
              Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                for (final c in SupportRepository.categories)
                  ChoiceChip(
                    avatar: Icon(_categoryLabels[c]?.$2 ?? Icons.label_outline, size: 18, color: _category == c ? AppColors.crimson : AppColors.muted),
                    label: Text(_categoryLabels[c]?.$1 ?? c),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ]),
              if (_category == 'safety') ...[
                const SizedBox(height: AppSpace.sm),
                const InfoBanner(
                  tone: StatusTone.danger,
                  icon: Icons.sos_rounded,
                  message: 'If you are in danger right now, use the SOS button on your trip screen or call emergency services.',
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _subject,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Please add a subject' : null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _message,
                maxLines: 6,
                maxLength: 3000,
                decoration: InputDecoration(
                  labelText: 'Describe the issue',
                  alignLabelWithHint: true,
                  hintText: _category == 'lost_item' ? 'What did you leave behind? Where in the vehicle?' : null,
                ),
                validator: (v) => (v ?? '').trim().length < 5 ? 'Please add a few more details' : null,
              ),
              const SizedBox(height: AppSpace.sm),
              AppCard(
                onTap: () async {
                  final p = await pickImagePath(context, title: 'Attach a photo');
                  if (p != null) setState(() => _attachment = p);
                },
                child: Row(children: [
                  const Icon(Icons.attach_file_rounded, color: AppColors.inkSoft),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(_attachment == null ? 'Attach a photo (optional)' : 'Photo attached', style: AppText.title)),
                  if (_attachment != null) IconButton(tooltip: 'Remove attachment', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _attachment = null)),
                ]),
              ),
            ]),
          ),
          BottomActionBar(child: AppButton(label: 'Submit ticket', loading: _busy, onPressed: _submit)),
        ]),
      ),
    );
  }
}
