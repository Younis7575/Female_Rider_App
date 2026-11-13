import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/account_repository.dart';
import 'widgets/validators.dart';

/// First-run profile completion (name, optional email, emergency contact).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _ecName;
  late final TextEditingController _ecPhone;
  bool _saving = false;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _ecName = TextEditingController(text: u?.emergencyContactName ?? '');
    _ecPhone = TextEditingController(text: u?.emergencyContactPhone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = {});
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = await ref.read(accountRepositoryProvider).updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'emergency_contact_name': _ecName.text.trim().isEmpty ? null : _ecName.text.trim(),
        'emergency_contact_phone': _ecPhone.text.trim().isEmpty ? null : _ecPhone.text.trim(),
      });
      final session = ref.read(sessionProvider.notifier);
      session.updateUser(user);
      await session.refreshMe();
      final me = session.me;
      if (mounted && me != null) context.go(homeFor(me));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isValidation) {
        setState(() => _fieldErrors = {
              for (final f in ['name', 'email', 'emergency_contact_name', 'emergency_contact_phone'])
                if (e.fieldError(f) != null) f: e.fieldError(f)!,
            });
      }
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context, title: 'Log out?', message: 'You can finish setting up your profile next time you sign in.', confirmLabel: 'Log out');
              if (ok) await ref.read(sessionProvider.notifier).logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
            const Text('Tell us about you', style: AppText.h1),
            const SizedBox(height: AppSpace.xs),
            Text('Drivers see only your first name. Your emergency contact is only used if you trigger SOS or share a trip.',
                style: AppText.body.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSpace.xl),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(labelText: 'Full name', errorText: _fieldErrors['name']),
              validator: Validators.name,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: 'Email (optional)', helperText: 'For receipts and account recovery', errorText: _fieldErrors['email']),
              validator: Validators.optionalEmail,
            ),
            const SectionHeader('Emergency contact', padding: EdgeInsets.fromLTRB(0, AppSpace.xl, 0, AppSpace.xs)),
            TextFormField(
              controller: _ecName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Contact name (optional)', errorText: _fieldErrors['emergency_contact_name']),
              validator: (v) => Validators.optionalText(v),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _ecPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Contact phone (optional)', hintText: '+92 300 0000000', errorText: _fieldErrors['emergency_contact_phone']),
              validator: Validators.optionalPhone,
            ),
            const SizedBox(height: AppSpace.xxl),
            AppButton(label: 'Continue', loading: _saving, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
