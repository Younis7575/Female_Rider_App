import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/location/driver_tracker.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/json.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Large online/offline availability switch for drivers.
class DriverOnlineToggle extends ConsumerWidget {
  const DriverOnlineToggle({super.key, this.onChanged});

  /// Called after a successful toggle with the new online state.
  final ValueChanged<bool>? onChanged;

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool online) async {
    final tracker = ref.read(driverTrackerProvider.notifier);
    try {
      if (online) {
        await tracker.goOffline();
      } else {
        await tracker.goOnline();
      }
      onChanged?.call(!online);
    } catch (e) {
      if (!context.mounted) return;
      if (e is ApiException && e.code == 'driver_not_compliant') {
        final issues = asStringList(e.detailsMap['issues']);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.rule_rounded, color: AppColors.warning, size: 32),
            title: const Text('You can\'t go online yet'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.message, style: AppText.body),
              if (issues.length > 1) ...[
                const SizedBox(height: AppSpace.sm),
                for (final i in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  '),
                      Expanded(child: Text(i, style: AppText.bodySm)),
                    ]),
                  ),
              ],
            ]),
            actions: [AppButton(label: 'OK', height: 46, onPressed: () => Navigator.of(ctx).pop())],
          ),
        );
      } else {
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverTrackerProvider);
    final online = state.online;
    return Semantics(
      button: true,
      toggled: online,
      label: online ? 'You are online. Tap to go offline' : 'You are offline. Tap to go online',
      child: Material(
        key: const ValueKey('online-toggle'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: state.busy ? null : () => _toggle(context, ref, online),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              gradient: online
                  ? const LinearGradient(colors: [Color(0xFF1E8E5A), Color(0xFF136B43)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: online ? null : AppColors.nightSoft,
              border: Border.all(color: online ? Colors.transparent : AppColors.nightLine),
              boxShadow: online ? const [BoxShadow(color: Color(0x401E8E5A), blurRadius: 18, offset: Offset(0, 8))] : null,
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? Colors.white.withValues(alpha: 0.18) : AppColors.crimson.withValues(alpha: 0.18),
                ),
                child: Icon(online ? Icons.wifi_tethering_rounded : Icons.power_settings_new_rounded,
                    color: online ? Colors.white : AppColors.roseAccent),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(online ? 'You\'re online' : 'You\'re offline', style: AppText.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Looking for ride requests near you' : 'Go online to receive ride requests',
                    style: AppText.bodySm.copyWith(color: Colors.white70),
                  ),
                ]),
              ),
              const SizedBox(width: AppSpace.xs),
              if (state.busy)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
              else
                _Knob(on: online),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Knob extends StatelessWidget {
  const _Knob({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 56,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: on ? Colors.white.withValues(alpha: 0.3) : AppColors.nightLine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white : AppColors.crimson),
      ),
    );
  }
}
