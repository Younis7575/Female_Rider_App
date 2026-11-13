import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, dark }

/// Primary call-to-action button with built-in loading state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.height = 54,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 54,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 54,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final AppButtonVariant variant;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.crimson, Colors.white, null),
      AppButtonVariant.secondary => (AppColors.surface, AppColors.ink, AppColors.line),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.crimson, null),
      AppButtonVariant.danger => (AppColors.danger, Colors.white, null),
      AppButtonVariant.dark => (AppColors.night, Colors.white, null),
    };
    final disabled = onPressed == null || loading;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20, color: disabled ? AppColors.subtle : fg), const SizedBox(width: 8)],
                Flexible(
                  // Scale down rather than truncate in narrow (e.g. 3-up) button rows.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: disabled && !loading ? AppColors.subtle : fg),
                    ),
                  ),
                ),
              ],
            ),
    );

    final button = Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Material(
        color: disabled && !loading && variant != AppButtonVariant.ghost ? AppColors.line : bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
          side: border != null ? BorderSide(color: border, width: 1.4) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Round icon button used on map overlays.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.color, this.background, this.size = 48});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background ?? AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.card),
          child: Icon(icon, color: color ?? AppColors.ink, size: size * 0.46),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Large circular SOS button.
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.onPressed, this.size = 56});
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS emergency',
      child: Material(
        color: AppColors.danger,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}
