import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import 'simple_html.dart';

final cmsPageProvider = FutureProvider.autoDispose.family<CmsPage, String>((ref, slug) {
  return ref.watch(accountRepositoryProvider).page(slug);
});

/// Legal / CMS page (`GET /pages/{slug}`) with a browser fallback to the config legal URLs.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.slug});
  final String slug;

  String? _fallbackUrl(WidgetRef ref) {
    final cfg = ref.read(appConfigProvider);
    return switch (slug) {
      'terms' => cfg.termsUrl,
      'privacy' => cfg.privacyUrl,
      'eligibility-policy' => cfg.eligibilityPolicyUrl,
      _ => null,
    };
  }

  String get _defaultTitle => switch (slug) {
        'terms' => 'Terms of service',
        'privacy' => 'Privacy policy',
        'eligibility-policy' => 'Eligibility policy',
        _ => humanize(slug.replaceAll('-', '_')),
      };

  Future<void> _openBrowser(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView).catchError((_) => false);
    if (!ok && context.mounted) showSnack(context, 'Could not open the page.', error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(cmsPageProvider(slug));
    final fallback = _fallbackUrl(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(page.value?.title ?? _defaultTitle),
        actions: [
          if (fallback != null)
            IconButton(tooltip: 'Open in browser', icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _openBrowser(context, fallback)),
        ],
      ),
      body: page.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 220, height: 22),
            SizedBox(height: AppSpace.md),
            Skeleton(height: 14),
            SizedBox(height: 8),
            Skeleton(height: 14),
            SizedBox(height: 8),
            Skeleton(width: 260, height: 14),
          ]),
        ),
        error: (e, _) => fallback != null
            ? EmptyState(
                icon: Icons.description_outlined,
                title: _defaultTitle,
                message: 'This page could not be loaded in the app. You can read it in your browser.',
                actionLabel: 'Open in browser',
                onAction: () => _openBrowser(context, fallback),
              )
            : ErrorState(error: e, onRetry: () => ref.invalidate(cmsPageProvider(slug))),
        data: (p) => ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
          Text(p.title, style: AppText.h1),
          const SizedBox(height: 4),
          Text(
            [if (p.version != null) 'Version ${p.version}', if (p.updatedAt != null) 'Updated ${formatDate(p.updatedAt)}'].join(' · '),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpace.lg),
          SimpleHtml(p.body),
          const SizedBox(height: AppSpace.xxl),
        ]),
      ),
    );
  }
}
