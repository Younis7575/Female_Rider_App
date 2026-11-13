import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../network/api_envelope.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';

/// Confirmation dialog. Returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon != null ? Icon(icon, color: destructive ? AppColors.danger : AppColors.crimson, size: 32) : null,
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      actions: [
        Row(children: [
          Expanded(child: AppButton.secondary(label: cancelLabel, height: 48, onPressed: () => Navigator.of(ctx).pop(false))),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: destructive
                ? AppButton.danger(label: confirmLabel, height: 48, onPressed: () => Navigator.of(ctx).pop(true))
                : AppButton(label: confirmLabel, height: 48, onPressed: () => Navigator.of(ctx).pop(true)),
          ),
        ]),
      ],
    ),
  );
  return res ?? false;
}

/// Standard modal bottom sheet with brand styling.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollControlled = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: builder(ctx),
    ),
  );
}

/// Pick one reason from a list (cancel reasons, etc.). Returns the chosen text.
Future<String?> showReasonPicker(
  BuildContext context, {
  required String title,
  required List<String> reasons,
  String? warning,
  String confirmLabel = 'Confirm',
  bool destructive = true,
}) {
  return showAppSheet<String>(context, builder: (ctx) => _ReasonSheet(title: title, reasons: reasons, warning: warning, confirmLabel: confirmLabel, destructive: destructive));
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.reasons, this.warning, required this.confirmLabel, required this.destructive});
  final String title;
  final List<String> reasons;
  final String? warning;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _selected;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.reasons.isEmpty ? const ['Other'] : widget.reasons;
    final isOther = _selected == 'Other';
    final value = isOther && _other.text.trim().isNotEmpty ? 'Other: ${_other.text.trim()}' : _selected;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.title, style: AppText.h2),
        if (widget.warning != null) ...[
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: AppSpace.xs),
              Expanded(child: Text(widget.warning!, style: AppText.bodySm.copyWith(color: AppColors.inkSoft))),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        RadioGroup<String>(
          groupValue: _selected,
          onChanged: (v) => setState(() => _selected = v),
          child: Column(children: [
            for (final r in reasons)
              RadioListTile<String>(
                value: r,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.crimson,
                title: Text(r, style: AppText.title),
              ),
          ]),
        ),
        if (isOther)
          TextField(
            controller: _other,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Tell us more (optional)'),
          ),
        const SizedBox(height: AppSpace.sm),
        widget.destructive
            ? AppButton.danger(label: widget.confirmLabel, onPressed: value == null ? null : () => Navigator.of(context).pop(value))
            : AppButton(label: widget.confirmLabel, onPressed: value == null ? null : () => Navigator.of(context).pop(value)),
      ]),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false, bool success = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline_rounded : (success ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded),
          color: error ? const Color(0xFFFF8A80) : (success ? const Color(0xFF7BE0AE) : Colors.white),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(message)),
      ]),
    ));
}

void showErrorSnack(BuildContext context, Object error) => showSnack(context, errorMessage(error), error: true);

/// Runs [action] showing errors as snackbars. Returns the result or null on failure.
Future<T?> runGuarded<T>(BuildContext context, Future<T> Function() action, {String? successMessage}) async {
  try {
    final r = await action();
    if (successMessage != null && context.mounted) showSnack(context, successMessage, success: true);
    return r;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return null;
  }
}

/// Text that counts down to [deadline] once per second.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.deadline, required this.builder, this.onExpired});
  final DateTime? deadline;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onExpired;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _t;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_fired && widget.deadline != null && widget.deadline!.isBefore(DateTime.now())) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void didUpdateWidget(covariant CountdownText old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _fired = false;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deadline == null ? Duration.zero : widget.deadline!.difference(DateTime.now());
    return widget.builder(context, d.isNegative ? Duration.zero : d);
  }
}
