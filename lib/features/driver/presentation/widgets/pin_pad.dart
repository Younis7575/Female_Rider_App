import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';

/// PIN boxes + numeric keypad used to start a trip with the passenger's code.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.length, required this.onCompleted, this.busy = false, this.error});
  final int length;
  final ValueChanged<String> onCompleted;
  final bool busy;
  final String? error;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _pin = '';

  void clear() => setState(() => _pin = '');

  void _press(String d) {
    if (widget.busy || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == widget.length) widget.onCompleted(_pin);
  }

  void _back() {
    if (widget.busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 54,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: hasError ? AppColors.danger : (i == _pin.length ? AppColors.crimson : Colors.transparent),
                width: 1.8,
              ),
            ),
            child: Text(i < _pin.length ? _pin[i] : '', style: AppText.h1),
          ),
      ]),
      SizedBox(
        height: 28,
        child: Center(
          child: widget.busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : (hasError ? Text(widget.error!, style: AppText.caption.copyWith(color: AppColors.danger), textAlign: TextAlign.center) : null),
        ),
      ),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '<'],
      ])
        Row(children: [
          for (final k in row)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: k.isEmpty
                    ? const SizedBox(height: 52)
                    : Material(
                        color: k == '<' ? Colors.transparent : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          key: ValueKey('pin-key-$k'),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => k == '<' ? _back() : _press(k),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: k == '<'
                                ? null
                                : BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                            child: k == '<'
                                ? const Icon(Icons.backspace_outlined, color: AppColors.inkSoft, semanticLabel: 'Delete')
                                : Text(k, style: AppText.h2),
                          ),
                        ),
                      ),
              ),
            ),
        ]),
    ]);
  }
}
