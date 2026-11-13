import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'buttons.dart';

/// Fare proposal control: −/+ stepper and slider, always clamped to [min, max]
/// and rounded to [step] (the backend rounds proposals to 5).
class FareStepper extends StatefulWidget {
  const FareStepper({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.suggested,
    this.currency = 'PKR',
    this.step = 5,
    this.bigStep = 50,
    this.dark = false,
  });

  final double min;
  final double max;
  final double value;
  final double? suggested;
  final ValueChanged<double> onChanged;
  final String currency;
  final int step;
  final int bigStep;
  final bool dark;

  @override
  State<FareStepper> createState() => _FareStepperState();
}

class _FareStepperState extends State<FareStepper> {
  void _set(double v) {
    final c = clampFare(v, widget.min, widget.max, step: widget.step);
    if (c != widget.value) widget.onChanged(c);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value.clamp(widget.min, widget.max).toDouble();
    final canDec = v > widget.min;
    final canInc = v < widget.max;
    final fg = widget.dark ? Colors.white : AppColors.ink;
    final sub = widget.dark ? Colors.white60 : AppColors.muted;
    final hasRange = widget.max > widget.min;
    String hint;
    if (widget.suggested != null && widget.suggested! > 0) {
      final diff = v - widget.suggested!;
      hint = diff.abs() < 1
          ? 'Recommended fare'
          : diff > 0
              ? '${formatMoney(diff, currency: widget.currency)} above recommended · faster pickup'
              : '${formatMoney(-diff, currency: widget.currency)} below recommended · may take longer';
    } else {
      hint = 'Offer a fair price for your trip';
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _StepBtn(key: const ValueKey('fare-dec'), icon: Icons.remove_rounded, enabled: canDec, dark: widget.dark, onTap: () => _set(v - widget.step), onLong: () => _set(v - widget.bigStep)),
        Expanded(
          child: Column(children: [
            Text(
              formatMoney(v, currency: widget.currency),
              key: const ValueKey('fare-value'),
              style: AppText.money.copyWith(color: fg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(hint, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: sub), maxLines: 2),
          ]),
        ),
        _StepBtn(key: const ValueKey('fare-inc'), icon: Icons.add_rounded, enabled: canInc, dark: widget.dark, onTap: () => _set(v + widget.step), onLong: () => _set(v + widget.bigStep)),
      ]),
      if (hasRange) ...[
        const SizedBox(height: AppSpace.xs),
        Slider(
          key: const ValueKey('fare-slider'),
          min: widget.min,
          max: widget.max,
          value: v,
          divisions: ((widget.max - widget.min) / widget.step).round().clamp(1, 1000),
          onChanged: _set,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Row(children: [
            Text('Min ${formatMoney(widget.min, currency: widget.currency)}', style: AppText.caption.copyWith(color: sub)),
            const Spacer(),
            Text('Max ${formatMoney(widget.max, currency: widget.currency)}', style: AppText.caption.copyWith(color: sub)),
          ]),
        ),
      ],
    ]);
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({super.key, required this.icon, required this.enabled, required this.onTap, required this.onLong, required this.dark});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Colors.white.withValues(alpha: enabled ? 0.14 : 0.05) : (enabled ? AppColors.roseSoft : AppColors.field);
    final fg = dark ? (enabled ? Colors.white : Colors.white30) : (enabled ? AppColors.crimson : AppColors.subtle);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLong : null,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, color: fg, size: 26)),
        ),
      ),
    );
  }
}

/// Bottom sheet asking for an amount within bounds. Returns the amount or null.
Future<double?> showFareSheet(
  BuildContext context, {
  required String title,
  required double min,
  required double max,
  required double initial,
  double? suggested,
  String currency = 'PKR',
  String confirmLabel = 'Send offer',
  String? subtitle,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _FareSheet(title: title, subtitle: subtitle, min: min, max: max, initial: initial, suggested: suggested, currency: currency, confirmLabel: confirmLabel),
  );
}

class _FareSheet extends StatefulWidget {
  const _FareSheet({required this.title, this.subtitle, required this.min, required this.max, required this.initial, this.suggested, required this.currency, required this.confirmLabel});
  final String title;
  final String? subtitle;
  final double min;
  final double max;
  final double initial;
  final double? suggested;
  final String currency;
  final String confirmLabel;

  @override
  State<_FareSheet> createState() => _FareSheetState();
}

class _FareSheetState extends State<_FareSheet> {
  late double _v = clampFare(widget.initial, widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: AppText.h2),
          if (widget.subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.subtitle!, style: AppText.bodySm)),
          const SizedBox(height: AppSpace.lg),
          FareStepper(min: widget.min, max: widget.max, value: _v, suggested: widget.suggested, currency: widget.currency, onChanged: (v) => setState(() => _v = v)),
          const SizedBox(height: AppSpace.lg),
          AppButton(key: const ValueKey('fare-sheet-confirm'), label: '${widget.confirmLabel} · ${formatMoney(_v, currency: widget.currency)}', onPressed: () => Navigator.of(context).pop(_v)),
        ]),
      ),
    );
  }
}
