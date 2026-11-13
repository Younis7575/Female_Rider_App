import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/apply_scaffold.dart';
import 'widgets/form_helpers.dart';

/// Application step 2: vehicle (`PUT /driver/vehicle`).
class ApplyVehicleScreen extends ConsumerWidget {
  const ApplyVehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return ApplyScaffold(
      step: 2,
      title: 'Your vehicle',
      child: AsyncView<DriverProfile>(
        value: profile,
        onRetry: () => ref.invalidate(driverProfileProvider),
        data: (p) => _VehicleForm(profile: p),
      ),
    );
  }
}

class _VehicleForm extends ConsumerStatefulWidget {
  const _VehicleForm({required this.profile});
  final DriverProfile profile;

  @override
  ConsumerState<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<_VehicleForm> {
  final _form = GlobalKey<FormState>();
  late final v = widget.profile.vehicle;
  late int? _categoryId = v?.categoryId;
  late final _make = TextEditingController(text: v?.make ?? '');
  late final _model = TextEditingController(text: v?.model ?? '');
  late final _color = TextEditingController(text: v?.color ?? '');
  late final _plate = TextEditingController(text: v?.plateNumber ?? '');
  late int? _year = v?.year;
  late String? _reg = v?.registrationExpiry;
  late String? _ins = v?.insuranceExpiry;
  ApiException? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_make, _model, _color, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _fe(String f) => _error?.fieldError(f);
  String? _req(String? s) => s == null || s.trim().isEmpty ? 'Required' : null;

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(driverRepositoryProvider).updateVehicle(
            categoryId: _categoryId!,
            make: _make.text.trim(),
            model: _model.text.trim(),
            color: _color.text.trim(),
            year: _year!,
            plateNumber: _plate.text.trim().toUpperCase(),
            registrationExpiry: _reg,
            insuranceExpiry: _ins,
          );
      ref.invalidate(driverProfileProvider);
      if (!mounted) return;
      showSnack(context, 'Vehicle saved', success: true);
      context.pushReplacement(Routes.driverApplyDocuments);
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

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(appConfigProvider).vehicleCategories;
    final now = DateTime.now();
    final years = [for (var y = now.year + 1; y >= now.year - 25; y--) y];
    final editable = widget.profile.canEdit;
    return Column(children: [
      Expanded(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            if (v?.status == 'rejected' && v?.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: InfoBanner(tone: StatusTone.danger, title: 'Vehicle rejected', message: v!.rejectionReason!),
              ),
            const FormSectionLabel('Category'),
            if (cats.isEmpty)
              Text('Vehicle categories are unavailable. Pull to refresh the app configuration.', style: AppText.bodySm)
            else
              FormField<int>(
                initialValue: _categoryId,
                validator: (_) => _categoryId == null ? 'Choose a category' : null,
                builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                    for (final c in cats)
                      ChoiceChip(
                        selected: _categoryId == c.id,
                        avatar: Icon(_iconFor(c.slug), size: 18, color: _categoryId == c.id ? AppColors.crimson : AppColors.inkSoft),
                        label: Text(c.name.replaceFirst('FemaleRider ', '')),
                        onSelected: (_) {
                          setState(() => _categoryId = c.id);
                          state.didChange(c.id);
                        },
                      ),
                  ]),
                  if (state.errorText != null || _fe('vehicle_category_id') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_fe('vehicle_category_id') ?? state.errorText!, style: AppText.caption.copyWith(color: AppColors.danger)),
                    ),
                ]),
              ),
            const FormSectionLabel('Details'),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _make,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Make', hintText: 'Toyota', errorText: _fe('make')),
                  validator: _req,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: TextFormField(
                  controller: _model,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Model', hintText: 'Yaris', errorText: _fe('model')),
                  validator: _req,
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _color,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Colour', errorText: _fe('color')),
                  validator: _req,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: years.contains(_year) ? _year : null,
                  decoration: InputDecoration(labelText: 'Year', errorText: _fe('year')),
                  items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y),
                  validator: (y) => y == null ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')), LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(labelText: 'Number plate', hintText: 'KHI-2026', errorText: _fe('plate_number') ?? (_error?.code == 'plate_taken' ? _error!.message : null)),
              validator: _req,
            ),
            const FormSectionLabel('Expiry dates'),
            DateField(
              label: 'Registration expiry',
              optional: true,
              value: _reg,
              errorText: _fe('registration_expiry'),
              firstDate: now.add(const Duration(days: 1)),
              lastDate: DateTime(now.year + 15),
              onChanged: (s) => setState(() => _reg = s),
            ),
            const SizedBox(height: AppSpace.sm),
            DateField(
              label: 'Insurance expiry',
              optional: true,
              value: _ins,
              errorText: _fe('insurance_expiry'),
              firstDate: now.add(const Duration(days: 1)),
              lastDate: DateTime(now.year + 15),
              onChanged: (s) => setState(() => _ins = s),
            ),
            const SizedBox(height: AppSpace.xl),
          ]),
        ),
      ),
      BottomActionBar(child: AppButton(label: 'Save & continue', loading: _saving, onPressed: editable ? _save : null)),
    ]);
  }

  IconData _iconFor(String slug) => switch (slug) {
        'bike' => Icons.two_wheeler_rounded,
        'rickshaw' => Icons.electric_rickshaw_rounded,
        _ => Icons.directions_car_rounded,
      };
}
