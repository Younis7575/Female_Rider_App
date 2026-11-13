import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../../auth/presentation/session_controller.dart';

/// FAQs filtered to the current mode's audience (customer/driver).
final faqsProvider = FutureProvider.autoDispose.family<List<Faq>, String>((ref, audience) {
  return ref.watch(accountRepositoryProvider).faqs(audience: audience);
});

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentUserProvider)?.isDriverMode ?? false;
    final audience = driver ? 'driver' : 'customer';
    final faqs = ref.watch(faqsProvider(audience));
    return Scaffold(
      appBar: AppBar(title: const Text('Help center')),
      body: AsyncView<List<Faq>>(
        value: faqs,
        onRetry: () => ref.invalidate(faqsProvider(audience)),
        data: (all) {
          final q = _query.toLowerCase();
          final list = q.isEmpty ? all : all.where((f) => f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q)).toList();
          final groups = <String, List<Faq>>{};
          for (final f in list) {
            groups.putIfAbsent(f.category, () => []).add(f);
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(faqsProvider(audience).future),
            child: ListView(padding: const EdgeInsets.all(AppSpace.md), physics: const AlwaysScrollableScrollPhysics(), children: [
              TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(hintText: 'Search help articles', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: AppSpace.sm),
              if (list.isEmpty)
                const SizedBox(
                  height: 320,
                  child: EmptyState(icon: Icons.search_off_rounded, title: 'No matching articles', message: 'Try different words, or contact our support team.'),
                ),
              for (final entry in groups.entries) ...[
                SectionHeader(entry.key, padding: const EdgeInsets.fromLTRB(0, AppSpace.md, 0, AppSpace.xs)),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) const Divider(),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(entry.value[i].question, style: AppText.title),
                          iconColor: AppColors.crimson,
                          childrenPadding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
                          expandedAlignment: Alignment.centerLeft,
                          children: [Text(entry.value[i].answer, style: AppText.body)],
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              AppCard(
                onTap: () => context.push(Routes.newTicket),
                child: const Row(children: [
                  Icon(Icons.support_agent_rounded, color: AppColors.crimson),
                  SizedBox(width: AppSpace.sm),
                  Expanded(child: Text('Still need help? Contact support', style: AppText.title)),
                  Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
