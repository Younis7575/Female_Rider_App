import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/widgets/paged_list.dart';
import '../data/support_repository.dart';

/// Help center hub: contact options, quick links and the user's tickets.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _listKey = GlobalKey<PagedListViewState<SupportTicket>>();

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok && mounted) showSnack(context, 'No app available to open this.', error: true);
  }

  Future<void> _newTicket() async {
    final created = await context.push<bool>(Routes.newTicket);
    if (created == true) _listKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(appConfigProvider).support;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        color: AppColors.roseSoft,
        border: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How can we help?', style: AppText.h3),
          const SizedBox(height: 4),
          Text(support.hours.isEmpty ? 'Our team usually replies within a few hours.' : 'Support hours: ${support.hours}', style: AppText.bodySm),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            if (support.phone.isNotEmpty)
              Expanded(
                child: AppButton.secondary(
                  label: 'Call',
                  icon: Icons.call_outlined,
                  height: 46,
                  onPressed: () => _launch(Uri(scheme: 'tel', path: support.phone.replaceAll(RegExp(r'[^\d+]'), ''))),
                ),
              ),
            if (support.phone.isNotEmpty && support.email.isNotEmpty) const SizedBox(width: AppSpace.sm),
            if (support.email.isNotEmpty)
              Expanded(
                child: AppButton.secondary(
                  label: 'Email',
                  icon: Icons.mail_outline_rounded,
                  height: 46,
                  onPressed: () => _launch(Uri(scheme: 'mailto', path: support.email, queryParameters: {'subject': 'FemaleRider support'})),
                ),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: AppSpace.md),
      Row(children: [
        Expanded(child: _QuickLink(icon: Icons.quiz_outlined, label: 'FAQs', onTap: () => context.push(Routes.faqs))),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: _QuickLink(icon: Icons.shield_outlined, label: 'Safety', onTap: () => context.push(Routes.safetyReportBase))),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: _QuickLink(icon: Icons.gavel_rounded, label: 'Legal', onTap: () => _legalSheet(context))),
      ]),
      const SizedBox(height: AppSpace.md),
      AppButton(label: 'Create a support ticket', icon: Icons.add_comment_outlined, onPressed: _newTicket),
      const SectionHeader('Your tickets', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Support & help')),
      body: PagedListView<SupportTicket>(
        key: _listKey,
        header: header,
        fetch: (page) => ref.read(supportRepositoryProvider).tickets(page: page),
        empty: const EmptyState(
          icon: Icons.forum_outlined,
          title: 'No tickets yet',
          message: 'Questions about a trip, payment or lost item? Create a ticket and we’ll get back to you.',
        ),
        itemBuilder: (ctx, t, _) => _TicketTile(
          ticket: t,
          onTap: () async {
            await context.push(Routes.ticket(t.reference));
            _listKey.currentState?.refresh();
          },
        ),
      ),
    );
  }

  void _legalSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (slug, label) in const [('terms', 'Terms of service'), ('privacy', 'Privacy policy'), ('eligibility-policy', 'Eligibility policy')])
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(Routes.legal(slug));
              },
            ),
        ]),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Column(children: [
        Icon(icon, color: AppColors.crimson),
        const SizedBox(height: 6),
        Text(label, style: AppText.label),
      ]),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});
  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ticket.subject, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${ticket.reference} · ${humanize(ticket.category)} · ${formatRelative(ticket.updatedAt ?? ticket.createdAt)}', style: AppText.caption),
          ]),
        ),
        const SizedBox(width: AppSpace.xs),
        StatusChip(label: humanize(ticket.status), tone: ticketTone(ticket.status), dense: true),
      ]),
    );
  }
}

StatusTone ticketTone(String status) => switch (status) {
      'open' => StatusTone.warning,
      'pending' || 'awaiting_user' => StatusTone.info,
      'resolved' || 'closed' => StatusTone.success,
      _ => StatusTone.neutral,
    };
