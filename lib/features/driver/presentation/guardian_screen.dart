import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver_onboarding/presentation/onboarding_providers.dart';
import '../data/driver_repository.dart';
import '../domain/driver_models.dart';
import 'widgets/guardian_fields.dart';

/// Driver's guardian: receives her live location on WhatsApp when she picks up a rider and
/// when she completes the ride.
class GuardianScreen extends ConsumerWidget {
  const GuardianScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian alerts')),
      body: AsyncView<DriverProfile>(
        value: profile,
        onRetry: () => ref.invalidate(driverProfileProvider),
        data: (p) => _GuardianForm(guardian: p.guardian),
      ),
    );
  }
}

class _GuardianForm extends ConsumerStatefulWidget {
  const _GuardianForm({required this.guardian});
  final GuardianInfo guardian;

  @override
  ConsumerState<_GuardianForm> createState() => _GuardianFormState();
}

class _GuardianFormState extends ConsumerState<_GuardianForm> {
  final _form = GlobalKey<FormState>();
  late final _fields = GuardianFieldsController.fromInfo(widget.guardian);
  late bool _enabled = widget.guardian.alertsEnabled;
  bool _saving = false;
  bool _testing = false;
  ApiException? _error;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  DriverRepository get _repo => ref.read(driverRepositoryProvider);

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final (_, message) = await _repo.updateGuardian(
        name: _fields.name.text,
        relationship: _fields.relationship,
        whatsapp: _fields.whatsapp.text,
        alertsEnabled: _enabled,
        consent: _fields.consent,
      );
      ref.invalidate(driverProfileProvider);
      if (mounted) {
        showSnack(context, message ?? 'Guardian saved', success: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final message = await _repo.testGuardian();
      if (mounted) {
        showSnack(context, message ?? 'Test message sent', success: true);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guardian;
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                const InfoBanner(
                  tone: StatusTone.info,
                  icon: Icons.verified_user_outlined,
                  title: 'How it works',
                  message: 'When you pick up a rider (trip PIN) and when you complete the ride, FemaleRider sends your guardian your current location on WhatsApp. Only your name, vehicle, time and location are shared — never your rider\'s details.',
                ),
                const SizedBox(height: AppSpace.md),
                if (!g.configured)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.md),
                    child: InfoBanner(
                      tone: StatusTone.warning,
                      message: 'Add a guardian so a family member can follow your trips.',
                    ),
                  ),
                GuardianFields(
                  controller: _fields,
                  error: _error,
                  hasNumberOnFile: g.whatsappMasked != null,
                  numberOnFile: g.whatsappMasked,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: AppSpace.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Send location alerts'),
                  subtitle: const Text(
                    'Pickup and drop-off messages on WhatsApp',
                  ),
                ),
                if (g.configured) ...[
                  const SizedBox(height: AppSpace.sm),
                  AppButton.secondary(
                    label: 'Send a test message',
                    icon: Icons.send_rounded,
                    loading: _testing,
                    onPressed: _testing ? null : _test,
                  ),
                ],
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: AppButton(
            label: 'Save guardian',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}
