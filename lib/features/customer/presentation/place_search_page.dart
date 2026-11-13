import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../rides/data/ride_repository.dart';
import '../../rides/domain/ride_models.dart';
import 'customer_providers.dart';

enum PlaceSearchMode { pickup, destination, save }

/// What the user picked on the search page.
class PlaceSearchResult {
  const PlaceSearchResult.place(Place this.place)
      : setOnMap = false,
        useCurrentLocation = false;
  const PlaceSearchResult.setOnMap()
      : place = null,
        setOnMap = true,
        useCurrentLocation = false;
  const PlaceSearchResult.currentLocation()
      : place = null,
        setOnMap = false,
        useCurrentLocation = true;

  final Place? place;
  final bool setOnMap;
  final bool useCurrentLocation;
}

/// Opens the full-screen place search.
Future<PlaceSearchResult?> openPlaceSearch(
  BuildContext context, {
  required PlaceSearchMode mode,
  double? lat,
  double? lng,
  bool allowSetOnMap = true,
  String? initialQuery,
}) {
  return Navigator.of(context).push<PlaceSearchResult>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PlaceSearchPage(mode: mode, lat: lat, lng: lng, allowSetOnMap: allowSetOnMap, initialQuery: initialQuery),
  ));
}

class PlaceSearchPage extends ConsumerStatefulWidget {
  const PlaceSearchPage({super.key, required this.mode, this.lat, this.lng, this.allowSetOnMap = true, this.initialQuery});
  final PlaceSearchMode mode;
  final double? lat;
  final double? lng;
  final bool allowSetOnMap;
  final String? initialQuery;

  @override
  ConsumerState<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends ConsumerState<PlaceSearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;
  Object? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    if ((widget.initialQuery ?? '').length >= 2) _search(widget.initialQuery!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {});
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await ref.read(rideRepositoryProvider).searchPlaces(q, lat: widget.lat, lng: widget.lng);
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _searching = false;
      });
    }
  }

  void _pick(Place p) => Navigator.of(context).pop(PlaceSearchResult.place(p));

  Future<void> _save(Place p, String label) async {
    String? name;
    if (label == 'other') {
      name = await _askName(p.name);
      if (name == null) return;
    }
    if (!mounted) return;
    final saved = await runGuarded(context, () => ref.read(rideRepositoryProvider).savePlace(label: label, place: p, name: name), successMessage: 'Place saved');
    if (saved != null) ref.invalidate(savedPlacesProvider);
  }

  Future<String?> _askName(String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this place'),
        content: TextField(controller: c, autofocus: true, maxLength: 120, decoration: const InputDecoration(hintText: 'e.g. Gym, Mum\'s house')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim().isEmpty ? initial : c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  String get _title => switch (widget.mode) {
        PlaceSearchMode.pickup => 'Pickup location',
        PlaceSearchMode.destination => 'Where to?',
        PlaceSearchMode.save => 'Find a place to save',
      };

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_title),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => v.trim().length >= 2 ? _search(v.trim()) : null,
            decoration: InputDecoration(
              hintText: widget.mode == PlaceSearchMode.pickup ? 'Search pickup point' : 'Search destination',
              prefixIcon: Icon(widget.mode == PlaceSearchMode.pickup ? Icons.trip_origin_rounded : Icons.search_rounded,
                  color: widget.mode == PlaceSearchMode.pickup ? AppColors.ink : AppColors.crimson),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: AppColors.subtle),
                      tooltip: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: q.length < 2 ? _suggestions() : _resultsList()),
      ]),
    );
  }

  Widget _resultsList() {
    if (_error != null) return ErrorState(error: _error!, onRetry: () => _search(_controller.text.trim()));
    if (!_searching && _results.isEmpty) {
      return const EmptyState(icon: Icons.location_searching_rounded, title: 'No places found', message: 'Try a different spelling or a nearby landmark.');
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(indent: 72),
      itemBuilder: (_, i) => _PlaceTile(
        place: _results[i],
        icon: Icons.place_outlined,
        onTap: () => _pick(_results[i]),
        onSave: widget.mode == PlaceSearchMode.save ? null : (label) => _save(_results[i], label),
      ),
    );
  }

  Widget _suggestions() {
    final saved = ref.watch(savedPlacesProvider);
    final recent = ref.watch(recentPlacesProvider);
    return ListView(children: [
      if (widget.mode == PlaceSearchMode.pickup) ...[
        ListTile(
          leading: const _LeadingIcon(icon: Icons.my_location_rounded, color: AppColors.info),
          title: const Text('Use current location'),
          onTap: () => Navigator.of(context).pop(const PlaceSearchResult.currentLocation()),
        ),
        if (widget.allowSetOnMap)
          ListTile(
            leading: const _LeadingIcon(icon: Icons.push_pin_outlined, color: AppColors.crimson),
            title: const Text('Set location on map'),
            onTap: () => Navigator.of(context).pop(const PlaceSearchResult.setOnMap()),
          ),
      ],
      if (widget.mode != PlaceSearchMode.save) ...[
        const SectionHeader('Saved places'),
        saved.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpace.md), child: Skeleton(height: 40)),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(savedPlacesProvider)),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                  child: Text('Tap the bookmark on a search result to save Home or Work.', style: AppText.bodySm),
                )
              : Column(children: [
                  for (final s in list)
                    _PlaceTile(
                      place: s.place,
                      title: s.label == 'other' ? s.name : '${_labelName(s.label)} · ${s.name}',
                      icon: _labelIcon(s.label),
                      onTap: () => _pick(s.place),
                    ),
                ]),
        ),
        const SectionHeader('Recent'),
        recent.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpace.md), child: Skeleton(height: 40)),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(recentPlacesProvider)),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                  child: Text('Your recent destinations will appear here.', style: AppText.bodySm),
                )
              : Column(children: [
                  for (final p in list)
                    _PlaceTile(place: p, icon: Icons.history_rounded, onTap: () => _pick(p), onSave: (label) => _save(p, label)),
                ]),
        ),
      ] else
        const EmptyState(icon: Icons.search_rounded, title: 'Search for a place', message: 'Type at least 2 characters to search.'),
      const SizedBox(height: AppSpace.xl),
    ]);
  }
}

String _labelName(String label) => switch (label) {
      'home' => 'Home',
      'work' => 'Work',
      _ => 'Saved',
    };

IconData _labelIcon(String label) => switch (label) {
      'home' => Icons.home_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.bookmark_rounded,
    };

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, this.color = AppColors.inkSoft});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.icon, required this.onTap, this.onSave, this.title});
  final Place place;
  final IconData icon;
  final VoidCallback onTap;
  final void Function(String label)? onSave;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(icon: icon),
      title: Text(title ?? place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: place.address.isNotEmpty && place.address != place.name ? Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      onTap: onTap,
      trailing: onSave == null
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Save place',
              icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.muted),
              onSelected: onSave,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'home', child: Text('Save as Home')),
                PopupMenuItem(value: 'work', child: Text('Save as Work')),
                PopupMenuItem(value: 'other', child: Text('Save as other…')),
              ],
            ),
    );
  }
}

/// Human message for estimate/ride errors.
String placeErrorMessage(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';
