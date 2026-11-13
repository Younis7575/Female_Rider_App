import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/domain/account_models.dart';
import '../data/support_repository.dart';
import 'support_screen.dart' show ticketTone;

final ticketProvider = FutureProvider.autoDispose.family<SupportTicket, String>(
  (ref, reference) {
    return ref.watch(supportRepositoryProvider).ticket(reference);
  },
);

/// Support conversation thread with reply box.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.reference});
  final String reference;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _reply = TextEditingController();
  bool _sending = false;
  SupportTicket? _override;
  String? _attachment;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final updated = await runGuarded(
      context,
      () => ref
          .read(supportRepositoryProvider)
          .reply(widget.reference, text, attachmentPath: _attachment),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (updated != null) {
        _override = updated;
        _reply.clear();
        _attachment = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketProvider(widget.reference));
    return Scaffold(
      appBar: AppBar(title: Text(widget.reference)),
      body: AsyncView<SupportTicket>(
        value: async,
        onRetry: () => ref.invalidate(ticketProvider(widget.reference)),
        data: (fetched) {
          final t = _override ?? fetched;
          final closed = t.status == 'closed';
          final messages = t.messages.reversed.toList();
          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.subject, style: AppText.h3),
                          const SizedBox(height: 2),
                          Text(
                            '${humanize(t.category)} · opened ${formatDate(t.createdAt)}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: humanize(t.status),
                      tone: ticketTone(t.status),
                    ),
                  ],
                ),
              ),
              if (t.tripId != null)
                ListTile(
                  tileColor: AppColors.surface,
                  leading: const Icon(Icons.route_outlined),
                  title: const Text('Linked trip'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.tripDetail(t.tripId!)),
                ),
              const Divider(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _override = null;
                    return ref.refresh(ticketProvider(widget.reference).future);
                  },
                  child: ListView.builder(
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpace.md),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(message: messages[i]),
                  ),
                ),
              ),
              if (closed)
                const BottomActionBar(
                  child: Text(
                    'This ticket is closed. Please open a new one if you need more help.',
                    style: AppText.bodySm,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                BottomActionBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_attachment != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.xs),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 18,
                                color: AppColors.inkSoft,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _attachment!.split('/').last,
                                  style: AppText.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove attachment',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () =>
                                    setState(() => _attachment = null),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Attach photo',
                            icon: const Icon(Icons.attach_file_rounded),
                            onPressed: _sending
                                ? null
                                : () async {
                                    final path = await pickImagePath(
                                      context,
                                      title: 'Attach a photo',
                                    );
                                    if (path != null && mounted) {
                                      setState(() => _attachment = path);
                                    }
                                  },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _reply,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 3000,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Write a reply…',
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton.filled(
                                  tooltip: 'Send reply',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.crimson,
                                  ),
                                  onPressed: _send,
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = !message.fromSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.crimson : AppColors.surface,
            border: mine ? null : Border.all(color: AppColors.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(mine ? AppRadius.lg : 4),
              bottomRight: Radius.circular(mine ? 4 : AppRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  'FemaleRider Support',
                  style: AppText.caption.copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                message.body,
                style: AppText.body.copyWith(
                  color: mine ? Colors.white : AppColors.ink,
                ),
              ),
              if (message.hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                        color: mine ? Colors.white70 : AppColors.muted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Attachment',
                        style: AppText.caption.copyWith(
                          color: mine ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                formatDateTime(message.createdAt),
                style: AppText.caption.copyWith(
                  color: mine ? Colors.white70 : AppColors.subtle,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
