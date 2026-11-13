import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';

final _ymd = DateFormat('yyyy-MM-dd');

String toYmd(DateTime d) => _ymd.format(d);

DateTime? parseYmd(String? s) => s == null || s.isEmpty ? null : DateTime.tryParse(s);

/// Read-only field that opens a date picker; stores yyyy-MM-dd.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.initialDate,
    this.errorText,
    this.optional = false,
    this.validator,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialDate;
  final String? errorText;
  final bool optional;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final d = parseYmd(value);
    return FormField<String>(
      initialValue: value,
      validator: validator ?? (v) => !optional && (value == null || value!.isEmpty) ? 'Required' : null,
      builder: (state) => InkWell(
        borderRadius: AppRadius.input,
        onTap: () async {
          final init = d ?? initialDate ?? firstDate;
          final picked = await showDatePicker(
            context: context,
            firstDate: firstDate,
            lastDate: lastDate,
            initialDate: init.isBefore(firstDate) ? firstDate : (init.isAfter(lastDate) ? lastDate : init),
            helpText: label,
          );
          if (picked != null) {
            final s = toYmd(picked);
            state.didChange(s);
            onChanged(s);
          }
        },
        child: InputDecorator(
          isEmpty: d == null,
          decoration: InputDecoration(
            labelText: optional ? '$label (optional)' : label,
            errorText: errorText ?? state.errorText,
            suffixIcon: d != null && optional
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      state.didChange(null);
                      onChanged(null);
                    },
                  )
                : const Icon(Icons.calendar_today_rounded, size: 20),
          ),
          child: Text(d == null ? '' : DateFormat('d MMM y').format(d), style: AppText.body.copyWith(color: AppColors.ink)),
        ),
      ),
    );
  }
}

/// Section label inside forms.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.xs),
        child: Text(text.toUpperCase(), style: AppText.overline),
      );
}
