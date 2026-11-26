import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';

class ReceivedRating {
  const ReceivedRating({required this.score, required this.tags, this.comment, required this.from, this.fromName, this.createdAt});
  final int score;
  final List<String> tags;
  final String? comment;

  /// "customer" or "driver" – who gave the rating.
  final String from;
  final String? fromName;
  final DateTime? createdAt;

  factory ReceivedRating.fromJson(Json j) => ReceivedRating(
    score: asInt(j['score']),
    tags: asStringList(j['tags']),
    comment: asStringOrNull(j['comment']),
    from: asString(j['from'], 'customer'),
    fromName: asStringOrNull(j['from_name']),
    createdAt: asDate(j['created_at']),
  );
}

class RatingsSummary {
  const RatingsSummary({this.average, required this.count, required this.breakdown, required this.items});
  final double? average;
  final int count;
  final Map<int, int> breakdown;
  final List<ReceivedRating> items;

  factory RatingsSummary.fromJson(Json j) {
    final b = asMap(j['breakdown']);
    return RatingsSummary(
      average: asDoubleOrNull(j['average']),
      count: asInt(j['count']),
      breakdown: {for (var s = 5; s >= 1; s--) s: asInt(b['$s'])},
      items: asListOf(j['items'], ReceivedRating.fromJson),
    );
  }
}

/// `GET /me/ratings?as=driver|customer` – ratings received in the current mode.
final myRatingsProvider = FutureProvider.autoDispose.family<RatingsSummary, String>((ref, as) async {
  final env = await ref.watch(apiClientProvider).get('/me/ratings', query: {'as': as});
  return RatingsSummary.fromJson(env.dataMap);
});

/// Ratings you have received from riders (driver mode) or drivers (rider mode).
class MyRatingsScreen extends ConsumerWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDriver = ref.watch(sessionProvider.select((s) => s is SessionSignedIn && s.me.user.isDriverMode));
    final as = isDriver ? 'driver' : 'customer';
    final data = ref.watch(myRatingsProvider(as));
    return Scaffold(
      appBar: AppBar(title: const Text('My ratings')),
      body: AsyncView<RatingsSummary>(
        value: data,
        onRetry: () => ref.invalidate(myRatingsProvider(as)),
        data: (r) => RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.refresh(myRatingsProvider(as).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(r.average == null ? '—' : r.average!.toStringAsFixed(1), style: AppText.money),
                        _Stars(score: (r.average ?? 0).round()),
                        const SizedBox(height: 4),
                        Text('${r.count} rating${r.count == 1 ? '' : 's'}', style: AppText.caption),
                      ],
                    ),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Column(
                        children: [
                          for (final e in r.breakdown.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(width: 14, child: Text('${e.key}', style: AppText.caption)),
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: r.count == 0 ? 0 : e.value / r.count,
                                        minHeight: 6,
                                        backgroundColor: AppColors.line,
                                        color: const Color(0xFFF5A623),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.end, style: AppText.caption)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              SectionHeader(isDriver ? 'From your riders' : 'From your drivers'),
              if (r.items.isEmpty)
                const EmptyState(
                  icon: Icons.star_outline_rounded,
                  title: 'No ratings yet',
                  message: 'Ratings appear here after completed trips.',
                )
              else
                for (final item in r.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Stars(score: item.score),
                              const Spacer(),
                              Text(formatDate(item.createdAt), style: AppText.caption),
                            ],
                          ),
                          if (item.fromName != null) ...[
                            const SizedBox(height: 4),
                            Text(item.fromName!, style: AppText.label),
                          ],
                          if (item.tags.isNotEmpty) ...[
                            const SizedBox(height: AppSpace.xs),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final t in item.tags) StatusChip(label: t, tone: StatusTone.success, dense: true)],
                            ),
                          ],
                          if (item.comment != null && item.comment!.isNotEmpty) ...[
                            const SizedBox(height: AppSpace.xs),
                            Text('“${item.comment!}”', style: AppText.body),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(i <= score ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: const Color(0xFFF5A623)),
    ],
  );
}
