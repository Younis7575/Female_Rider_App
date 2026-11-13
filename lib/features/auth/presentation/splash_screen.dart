import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_repository.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'session_controller.dart';

enum _SplashPhase { loading, error, maintenance, updateRequired }

/// Boots the app: loads `/config`, restores the token and `/me`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  _SplashPhase _phase = _SplashPhase.loading;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    setState(() {
      _phase = _SplashPhase.loading;
      _message = null;
    });
    AppConfig? cfg;
    try {
      cfg = await ref.read(appConfigProvider.notifier).load();
    } catch (_) {
      // Keep defaults; the session bootstrap below decides whether we are offline.
    }
    if (!mounted) return;
    if (cfg != null && cfg.maintenanceMode) {
      setState(() {
        _phase = _SplashPhase.maintenance;
        _message = cfg!.maintenanceMessage ?? 'FemaleRider is undergoing maintenance. Please try again shortly.';
      });
      return;
    }
    if (cfg != null && compareVersions(Env.current.appVersion, cfg.minSupportedVersion) < 0) {
      setState(() => _phase = _SplashPhase.updateRequired);
      return;
    }
    try {
      final state = await ref.read(sessionProvider.notifier).bootstrap();
      if (!mounted) return;
      if (state is SessionSignedIn) context.go(homeFor(state.me));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SplashPhase.error;
        _message = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(children: [
              const Spacer(flex: 3),
              const BrandLogo(size: 112),
              const SizedBox(height: AppSpace.lg),
              Text('FemaleRider', style: AppText.display.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpace.xs),
              Text('Rides by women, for women', style: AppText.body.copyWith(color: Colors.white70)),
              const Spacer(flex: 2),
              _buildStatus(),
              const SizedBox(height: AppSpace.xl),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    switch (_phase) {
      case _SplashPhase.loading:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
        );
      case _SplashPhase.error:
        return _StatusCard(
          icon: Icons.wifi_off_rounded,
          title: 'We can’t reach FemaleRider',
          message: _message ?? 'Check your internet connection and try again.',
          action: 'Try again',
          onAction: _boot,
        );
      case _SplashPhase.maintenance:
        return _StatusCard(
          icon: Icons.construction_rounded,
          title: 'Scheduled maintenance',
          message: _message ?? '',
          action: 'Retry',
          onAction: _boot,
        );
      case _SplashPhase.updateRequired:
        return _StatusCard(
          icon: Icons.system_update_rounded,
          title: 'Update required',
          message: 'A newer version of FemaleRider is required to continue. Please update the app from your app store.',
          action: 'Check again',
          onAction: _boot,
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.message, required this.action, required this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.card, boxShadow: AppShadows.floating),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.crimson, size: 32),
        const SizedBox(height: AppSpace.sm),
        Text(title, style: AppText.h3, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.xs),
        Text(message, style: AppText.bodySm, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.md),
        AppButton(label: action, onPressed: onAction, height: 48),
      ]),
    );
  }
}
