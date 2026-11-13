import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../rides/data/ride_repository.dart';
import '../../rides/domain/ride_models.dart';
import 'customer_providers.dart';
import 'place_search_page.dart';

/// Manage Home / Work / other saved places.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, String label) async {
    final r = await openPlaceSearch(context, mode: PlaceSearchMode.save);
    final place = r?.place;
    if (place == null || !context.mounted) return;
    String? name;
    if (label == 'other') {
      final c = TextEditingController(text: place.name);
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Name this place'),
          content: TextField(controller: c, autofocus: true, maxLength: 120),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim().isEmpty ? place.name : c.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (name == null || !context.mounted) return;
    }
    final saved = await runGuarded(context, () => ref.read(rideRepositoryProvider).savePlace(label: label, place: place, name: name), successMessage: 'Place saved');
    if (saved != null) ref.invalidate(savedPlacesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedPlace p) async {
    final ok = await showConfirmDialog(context, title: 'Remove saved place?', message: '"${p.name}" will be removed from your saved places.', confirmLabel: 'Remove', destructive: true);
    if (!ok || !context.mounted) return;
    await runGuarded(context, () => ref.read(rideRepositoryProvider).deleteSavedPlace(p.id), successMessage: 'Place removed');
    ref.invalidate(savedPlacesProvider);
  }

  Future<void> _chooseLabel(BuildContext context, WidgetRef ref) async {
    final label = await showAppSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add a place', style: AppText.h2),
          ListTile(leading: const Icon(Icons.home_rounded), title: const Text('Home'), onTap: () => Navigator.of(ctx).pop('home')),
          ListTile(leading: const Icon(Icons.work_rounded), title: const Text('Work'), onTap: () => Navigator.of(ctx).pop('work')),
          ListTile(leading: const Icon(Icons.bookmark_rounded), title: const Text('Other'), onTap: () => Navigator.of(ctx).pop('other')),
        ]),
      ),
    );
    if (label != null && context.mounted) await _add(context, ref, label);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        onPressed: () => _chooseLabel(context, ref),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add place'),
      ),
      body: AsyncView<List<SavedPlace>>(
        value: places,
        onRetry: () => ref.invalidate(savedPlacesProvider),
        data: (list) {
          final hasHome = list.any((p) => p.label == 'home');
          final hasWork = list.any((p) => p.label == 'work');
          return RefreshIndicator(
            onRefresh: () => ref.refresh(savedPlacesProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 100), children: [
              if (!hasHome) _AddTile(icon: Icons.home_outlined, label: 'Add Home', onTap: () => _add(context, ref, 'home')),
              if (!hasWork) _AddTile(icon: Icons.work_outline_rounded, label: 'Add Work', onTap: () => _add(context, ref, 'work')),
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.roseSoft,
                        child: Icon(p.label == 'home' ? Icons.home_rounded : (p.label == 'work' ? Icons.work_rounded : Icons.bookmark_rounded), color: AppColors.crimson),
                      ),
                      title: Text(p.label == 'other' ? p.name : '${p.label == 'home' ? 'Home' : 'Work'} · ${p.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _delete(context, ref, p)),
                    ),
                  ),
                ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpace.xl),
                  child: EmptyState(icon: Icons.bookmark_border_rounded, title: 'No saved places yet', message: 'Save Home, Work and favourite spots for one-tap booking.'),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(children: [
          Icon(icon, color: AppColors.crimson),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(label, style: AppText.title.copyWith(color: AppColors.crimson))),
          const Icon(Icons.add_rounded, color: AppColors.crimson),
        ]),
      ),
    );
  }
}
