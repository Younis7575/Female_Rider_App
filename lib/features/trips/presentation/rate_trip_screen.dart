import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_repository.dart';
import '../data/trip_repository.dart';
import '../domain/trip_models.dart';
import 'trip_providers.dart';

/// Rate the other party after a completed trip (customer ↔ driver).
class RateTripScreen extends ConsumerStatefulWidget {
  const RateTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<RateTripScreen> createState() => _RateTripScreenState();
}

class _RateTripScreenState extends ConsumerState<RateTripScreen> {
  int _score = 0;
  final Set<String> _tags = {};
  final _comment = TextEditingController();
  bool _block = false;
  bool _submitting = false;

  static const _labels = ['', 'Very poor', 'Poor', 'Okay', 'Good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _finish(Trip t) {
    context.go(t.isDriverView ? Routes.driverHome : Routes.home);
  }

  Future<void> _submit(Trip t) async {
    setState(() => _submitting = true);
    try {
      final msg = await ref.read(tripRepositoryProvider).rate(t.id, score: _score, tags: _tags.toList(), comment: _comment.text);
      if (_block) {
        try {
          await ref.read(accountRepositoryProvider).blockUser(tripId: t.id, reason: 'Blocked after rating');
        } catch (_) {}
      }
      if (!mounted) return;
      showSnack(context, msg ?? 'Thanks for your feedback.', success: true);
      _finish(t);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: e.code != 'already_rated');
      if (e.code == 'already_rated' || e.code == 'rating_window_closed') _finish(t);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripDetailProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate your trip'),
        actions: [
          if (trip.hasValue) TextButton(onPressed: () => _finish(trip.value!), child: const Text('Skip')),
        ],
      ),
      body: AsyncView<Trip>(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(widget.tripId)),
        data: _body,
      ),
    );
  }

  Widget _body(Trip t) {
    final cfg = ref.watch(appConfigProvider);
    final driverView = t.isDriverView;
    final other = driverView ? t.customer : t.driver;
    final tags = driverView ? cfg.driverRatingTags : cfg.customerRatingTags;
    if (t.myRating != null) {
      return EmptyState(
        icon: Icons.star_rounded,
        title: 'You rated this trip ${t.myRating}★',
        message: 'Thanks for helping keep FemaleRider safe and friendly.',
        actionLabel: 'Done',
        onAction: () => _finish(t),
      );
    }
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
          Center(child: AppAvatar(url: other.photoUrl, name: other.firstName, size: 84, dark: driverView)),
          const SizedBox(height: AppSpace.sm),
          Text('How was your trip with ${other.firstName.isEmpty ? (driverView ? 'your passenger' : 'your driver') : other.firstName}?', style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.lg),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: ValueKey('star-$i'),
                iconSize: 44,
                tooltip: '$i star${i == 1 ? '' : 's'}',
                onPressed: () => setState(() => _score = i),
                icon: AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: i <= _score ? 1.1 : 1,
                  child: Icon(i <= _score ? Icons.star_rounded : Icons.star_outline_rounded, color: i <= _score ? const Color(0xFFF5A623) : AppColors.subtle),
                ),
              ),
          ]),
          Text(_labels[_score], textAlign: TextAlign.center, style: AppText.title.copyWith(color: AppColors.muted)),
          if (_score > 0 && tags.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text(_score >= 4 ? 'What went well?' : 'What could be better?', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (v) => setState(() {
                    if (v && _tags.length < 6) {
                      _tags.add(tag);
                    } else {
                      _tags.remove(tag);
                    }
                  }),
                ),
            ]),
          ],
          if (_score > 0) ...[
            const SizedBox(height: AppSpace.lg),
            TextField(controller: _comment, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'Add a comment (optional)')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _block,
              onChanged: (v) => setState(() => _block = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Don\'t match me with ${other.firstName.isEmpty ? 'this person' : other.firstName} again', style: AppText.title),
              subtitle: const Text('They will not be notified.'),
            ),
            if (_score <= 2)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: InfoBanner(
                  tone: StatusTone.warning,
                  icon: Icons.shield_outlined,
                  message: 'Did something make you feel unsafe? You can report it confidentially to our safety team.',
                  action: 'Report a safety issue',
                  onAction: () => context.push(Routes.safetyReport(tripId: t.id)),
                ),
              ),
          ],
        ]),
      ),
      BottomActionBar(
        child: AppButton(key: const ValueKey('submit-rating'), label: 'Submit rating', loading: _submitting, onPressed: _score == 0 || _submitting ? null : () => _submit(t)),
      ),
    ]);
  }
}
