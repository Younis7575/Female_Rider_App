import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/apply_scaffold.dart';
import 'widgets/form_helpers.dart';

/// Application step 1: personal & licence details (`PUT /driver/profile`).
class ApplyPersonalScreen extends ConsumerWidget {
  const ApplyPersonalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return ApplyScaffold(
      step: 1,
      title: 'Personal details',
      child: AsyncView<DriverProfile>(
        value: profile,
        onRetry: () => ref.invalidate(driverProfileProvider),
        data: (p) => _PersonalForm(profile: p),
      ),
    );
  }
}

class _PersonalForm extends ConsumerStatefulWidget {
  const _PersonalForm({required this.profile});
  final DriverProfile profile;

  @override
  ConsumerState<_PersonalForm> createState() => _PersonalFormState();
}

class _PersonalFormState extends ConsumerState<_PersonalForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName ?? ref.read(currentUserProvider)?.name ?? '');
  final _cnic = TextEditingController();
  final _license = TextEditingController();
  late final _address = TextEditingController(text: widget.profile.address ?? '');
  late final _ecName = TextEditingController(text: widget.profile.emergencyContactName ?? ref.read(currentUserProvider)?.emergencyContactName ?? '');
  // When a phone is already stored, start blank ("leave blank to keep current").
  late final _ecPhone = TextEditingController(text: widget.profile.hasEmergencyContactPhone ? '' : (ref.read(currentUserProvider)?.emergencyContactPhone ?? ''));
  late String? _dob = widget.profile.dateOfBirth;
  late String? _licenseExpiry = widget.profile.licenseExpiry;
  ApiException? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _cnic, _license, _address, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _fe(String field) => _error?.fieldError(field);

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(driverRepositoryProvider).updateProfile(
            fullName: _name.text.trim(),
            cnicNumber: _cnic.text.trim(),
            dateOfBirth: _dob!,
            licenseNumber: _license.text.trim(),
            licenseExpiry: _licenseExpiry!,
            address: _address.text.trim(),
            emergencyContactName: _ecName.text.trim(),
            emergencyContactPhone: _ecPhone.text.trim(),
          );
      ref.invalidate(driverProfileProvider);
      if (!mounted) return;
      showSnack(context, 'Driver details saved', success: true);
      context.pushReplacement(Routes.driverApplyVehicle);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _req(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final now = DateTime.now();
    final editable = p.canEdit;
    return Column(children: [
      Expanded(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            if (!editable)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: InfoBanner(tone: StatusTone.warning, message: 'Your application is ${p.statusLabel.toLowerCase()} and cannot be edited right now.'),
              ),
            Text('Tell us about yourself. Details must match your CNIC and driving licence.', style: AppText.bodySm),
            const FormSectionLabel('Identity'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Full name (as on CNIC)', errorText: _fe('full_name')),
              validator: _req,
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _cnic,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]')), LengthLimitingTextInputFormatter(15)],
              decoration: InputDecoration(
                labelText: 'CNIC number',
                hintText: '12345-1234567-1',
                helperText: p.cnicNumberMasked != null ? 'On file: ${p.cnicNumberMasked}. Leave blank to keep current' : null,
                errorText: _fe('cnic_number'),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty && p.cnicNumberMasked != null) return null;
                return !RegExp(r'^\d{5}-?\d{7}-?\d$').hasMatch(t) ? 'Enter a valid CNIC (12345-1234567-1)' : null;
              },
            ),
            const SizedBox(height: AppSpace.sm),
            DateField(
              label: 'Date of birth',
              value: _dob,
              errorText: _fe('date_of_birth'),
              firstDate: DateTime(now.year - 80),
              lastDate: DateTime(now.year - 18, now.month, now.day),
              initialDate: DateTime(now.year - 25),
              onChanged: (v) => setState(() => _dob = v),
            ),
            const FormSectionLabel('Driving licence'),
            TextFormField(
              controller: _license,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Licence number',
                helperText: p.licenseNumberMasked != null ? 'On file: ${p.licenseNumberMasked}. Leave blank to keep current' : null,
                errorText: _fe('license_number'),
              ),
              validator: (v) => p.licenseNumberMasked != null ? null : _req(v),
            ),
            const SizedBox(height: AppSpace.sm),
            DateField(
              label: 'Licence expiry',
              value: _licenseExpiry,
              errorText: _fe('license_expiry'),
              firstDate: now.add(const Duration(days: 1)),
              lastDate: DateTime(now.year + 20),
              initialDate: DateTime(now.year + 2),
              onChanged: (v) => setState(() => _licenseExpiry = v),
            ),
            const FormSectionLabel('Address'),
            TextFormField(
              controller: _address,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Home address', errorText: _fe('address')),
              validator: _req,
            ),
            const FormSectionLabel('Emergency contact'),
            TextFormField(
              controller: _ecName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Contact name', errorText: _fe('emergency_contact_name')),
              validator: _req,
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _ecPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact phone',
                hintText: '+92 300 0000000',
                helperText: p.hasEmergencyContactPhone ? 'A phone number is on file. Leave blank to keep current' : null,
                errorText: _fe('emergency_contact_phone'),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty && p.hasEmergencyContactPhone) return null;
                return !RegExp(r'^\+?[\d\s\-]{7,16}$').hasMatch(t) ? 'Enter a valid phone number' : null;
              },
            ),
            const SizedBox(height: AppSpace.xl),
          ]),
        ),
      ),
      BottomActionBar(child: AppButton(label: 'Save & continue', loading: _saving, onPressed: editable ? _save : null)),
    ]);
  }
}
