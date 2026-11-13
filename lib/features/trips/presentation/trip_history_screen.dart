import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/trip_repository.dart';
import '../domain/trip_models.dart';
import 'widgets/trip_widgets.dart';

/// Paged ride history for customer (`as=customer`) or driver (`as=driver`).
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key, required this.as});
  final String as;

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  final _scroll = ScrollController();
  final List<Trip> _items = [];
  String? _status; // null | completed | cancelled
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _gen++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _gen;
    setState(() => _loading = true);
    try {
      final res = await ref.read(tripRepositoryProvider).trips(as: widget.as, page: _page + 1, status: _status);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.as == 'driver';
    return Scaffold(
      appBar: AppBar(title: Text(driver ? 'Ride history' : 'Your rides')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
            children: [
              for (final (label, value) in const [('All', null), ('Completed', 'completed'), ('Cancelled', 'cancelled')])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xs),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _status == value,
                    onSelected: (_) {
                      if (_status == value) return;
                      _status = value;
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _list(driver)),
      ]),
    );
  }

  Widget _list(bool driver) {
    if (_items.isEmpty) {
      if (_loading) return const SkeletonList();
      if (_error != null) return ErrorState(error: _error!, onRetry: _reload);
      return EmptyState(
        icon: Icons.route_rounded,
        title: 'No rides yet',
        message: driver ? 'Completed and cancelled trips will appear here.' : 'Your trips will appear here once you take your first ride.',
        actionLabel: driver ? null : 'Book a ride',
        onAction: driver ? null : () => context.go(Routes.home),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xl),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            if (_error != null) return ErrorState(error: _error!, compact: true, onRetry: _loadMore);
            if (_hasMore) return const Padding(padding: EdgeInsets.all(AppSpace.md), child: Center(child: CircularProgressIndicator()));
            return Padding(padding: const EdgeInsets.all(AppSpace.md), child: Center(child: Text('That\'s all your rides', style: AppText.caption)));
          }
          final t = _items[i];
          return TripListCard(trip: t, onTap: () => context.push(Routes.tripDetail(t.id)));
        },
      ),
    );
  }
}
