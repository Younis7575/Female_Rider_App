import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/account_repository.dart';
import 'widgets/validators.dart';

/// Edit name, email, emergency contact and profile photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _ecName;
  late final TextEditingController _ecPhone;
  bool _saving = false;
  bool _uploading = false;
  Map<String, String> _errors = {};

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

  Future<void> _changePhoto() async {
    final path = await pickImagePath(context, title: 'Profile photo', maxWidth: 1200);
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    final user = await runGuarded(context, () => ref.read(accountRepositoryProvider).uploadPhoto(path), successMessage: 'Photo updated');
    if (user != null) ref.read(sessionProvider.notifier).updateUser(user);
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = await ref.read(accountRepositoryProvider).updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'emergency_contact_name': _ecName.text.trim().isEmpty ? null : _ecName.text.trim(),
        'emergency_contact_phone': _ecPhone.text.trim().isEmpty ? null : _ecPhone.text.trim(),
      });
      ref.read(sessionProvider.notifier).updateUser(user);
      if (!mounted) return;
      showSnack(context, 'Profile updated', success: true);
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = {
            for (final f in ['name', 'email', 'emergency_contact_name', 'emergency_contact_phone'])
              if (e.fieldError(f) != null) f: e.fieldError(f)!,
          });
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _form,
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Change profile photo',
                  child: GestureDetector(
                    onTap: _uploading ? null : _changePhoto,
                    child: Stack(children: [
                      AppAvatar(url: user?.photoUrl, name: user?.name, size: 104),
                      if (_uploading)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                            child: Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                          child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Center(child: Text('JPG or PNG, at least 200×200 px', style: AppText.caption)),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Full name', errorText: _errors['name']),
                validator: Validators.name,
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email (optional)', errorText: _errors['email']),
                validator: Validators.optionalEmail,
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                initialValue: user?.phone,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Phone number', helperText: 'Contact support to change your phone number'),
              ),
              const SectionHeader('Emergency contact', padding: EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xs)),
              TextFormField(
                controller: _ecName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Contact name', errorText: _errors['emergency_contact_name']),
                validator: (v) => Validators.optionalText(v),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _ecPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Contact phone', errorText: _errors['emergency_contact_phone']),
                validator: Validators.optionalPhone,
              ),
            ]),
          ),
          BottomActionBar(child: AppButton(label: 'Save changes', loading: _saving, onPressed: _save)),
        ]),
      ),
    );
  }
}
