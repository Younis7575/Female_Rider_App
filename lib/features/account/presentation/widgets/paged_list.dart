import 'package:material_ui/material_ui.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Infinite-scrolling list over a paginated endpoint with skeleton, empty,
/// error, pull-to-refresh and load-more states.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.separator = const SizedBox(height: AppSpace.sm),
    this.onLoaded,
  });

  final Future<Paged<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget empty;
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final Widget separator;
  final void Function(List<T> items)? onLoaded;

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;
  final _scroll = ScrollController();

  List<T> get items => List.unmodifiable(_items);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Replace an item in place (e.g. after marking read).
  void updateWhere(bool Function(T) test, T Function(T) update) {
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (test(_items[i])) _items[i] = update(_items[i]);
      }
    });
  }

  void mapAll(T Function(T) update) => setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = update(_items[i]);
        }
      });

  Future<void> refresh() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final p = await widget.fetch(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _page = 1;
        _hasMore = p.hasMore;
        _initialLoaded = true;
      });
      widget.onLoaded?.call(_items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_initialLoaded) return;
    setState(() => _loading = true);
    try {
      final p = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _page = p.page;
        _hasMore = p.hasMore && p.items.isNotEmpty;
      });
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoaded) {
      if (_error != null) return ErrorState(error: _error!, onRetry: refresh);
      return const SkeletonList();
    }
    final hasHeader = widget.header != null;
    return RefreshIndicator(
      onRefresh: refresh,
      child: _items.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              ?widget.header,
              SizedBox(height: MediaQuery.of(context).size.height * 0.55, child: widget.empty),
            ])
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: _items.length + (hasHeader ? 1 : 0) + 1,
              separatorBuilder: (_, i) => (hasHeader && i == 0) ? const SizedBox.shrink() : widget.separator,
              itemBuilder: (ctx, i) {
                if (hasHeader && i == 0) return widget.header!;
                final idx = i - (hasHeader ? 1 : 0);
                if (idx == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Center(
                      child: _hasMore
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_items.length > 5 ? 'You’re all caught up' : '', style: AppText.caption),
                    ),
                  );
                }
                return widget.itemBuilder(ctx, _items[idx], idx);
              },
            ),
    );
  }
}
