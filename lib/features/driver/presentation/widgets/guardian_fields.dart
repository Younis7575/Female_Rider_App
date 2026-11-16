import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/driver_models.dart';

/// State for the guardian form (shared by the driver application and the Guardian screen).
class GuardianFieldsController {
  GuardianFieldsController({String? name, this.relationship})
    : name = TextEditingController(text: name ?? '');

  factory GuardianFieldsController.fromInfo(GuardianInfo g) =>
      GuardianFieldsController(name: g.name, relationship: g.relationship);

  final TextEditingController name;
  final TextEditingController whatsapp = TextEditingController();
  String? relationship;
  bool consent = false;

  void dispose() {
    name.dispose();
    whatsapp.dispose();
  }
}

class GuardianFields extends StatelessWidget {
  const GuardianFields({
    super.key,
    required this.controller,
    this.error,
    this.hasNumberOnFile = false,
    this.numberOnFile,
    this.onChanged,
  });
  final GuardianFieldsController controller;
  final ApiException? error;
  final bool hasNumberOnFile;
  final String? numberOnFile;
  final VoidCallback? onChanged;

  static const relationships = [
    'Mother',
    'Father',
    'Husband',
    'Sister',
    'Brother',
    'Daughter',
    'Son',
    'Other',
  ];

  /// Pakistani mobile in any common format (0300 1234567, +92 300 1234567, 3001234567).
  static bool validNumber(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^(0?3\d{9}|923\d{9}|00923\d{9})$').hasMatch(d) ||
        RegExp(r'^[1-9]\d{9,14}$').hasMatch(d) && v.trim().startsWith('+');
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: c.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Guardian name',
            errorText: error?.fieldError('guardian_name'),
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: AppSpace.sm),
        DropdownButtonFormField<String>(
          initialValue: relationships.contains(c.relationship)
              ? c.relationship
              : null,
          decoration: InputDecoration(
            labelText: 'Relationship',
            errorText: error?.fieldError('guardian_relationship'),
          ),
          items: [
            for (final r in relationships)
              DropdownMenuItem(value: r, child: Text(r)),
          ],
          onChanged: (v) {
            c.relationship = v;
            onChanged?.call();
          },
        ),
        const SizedBox(height: AppSpace.sm),
        TextFormField(
          controller: c.whatsapp,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
            LengthLimitingTextInputFormatter(17),
          ],
          decoration: InputDecoration(
            labelText: 'Guardian WhatsApp number',
            hintText: '0300 1234567',
            prefixIcon: const Icon(
              Icons.chat_rounded,
              color: Color(0xFF25D366),
            ),
            helperText: hasNumberOnFile
                ? 'On file: $numberOnFile. Leave blank to keep it'
                : 'This number must be on WhatsApp',
            errorText: error?.fieldError('guardian_whatsapp'),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return hasNumberOnFile ? null : 'Required';
            return validNumber(t)
                ? null
                : 'Enter a valid mobile number, e.g. 0300 1234567';
          },
        ),
        const SizedBox(height: AppSpace.xs),
        FormField<bool>(
          initialValue: c.consent,
          validator: (_) =>
              !hasNumberOnFile && !c.consent ? 'Please confirm' : null,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: c.consent,
                onChanged: (v) {
                  c.consent = v ?? false;
                  state.didChange(c.consent);
                  onChanged?.call();
                },
                title: Text(
                  'My guardian agreed to receive my location on WhatsApp when I pick up and drop off riders.',
                  style: AppText.bodySm,
                ),
              ),
              if (state.hasError ||
                  error?.fieldError('guardian_consent') != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    state.errorText ?? error!.fieldError('guardian_consent')!,
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
