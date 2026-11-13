import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../driver/data/driver_repository.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/apply_scaffold.dart';

/// Final step: summary + driver agreement + submit.
class ApplyReviewScreen extends ConsumerStatefulWidget {
  const ApplyReviewScreen({super.key});

  @override
  ConsumerState<ApplyReviewScreen> createState() => _ApplyReviewScreenState();
}

class _ApplyReviewScreenState extends ConsumerState<ApplyReviewScreen> {
  bool _agreed = false;
  bool _submitting = false;
  List<String> _missing = const [];

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _missing = const [];
    });
    try {
      final (_, message) = await ref.read(driverRepositoryProvider).submit();
      ref.invalidate(driverProfileProvider);
      await ref.read(sessionProvider.notifier).refreshMe();
      if (!mounted) return;
      showSnack(context, message ?? 'Application submitted for review.', success: true);
      context.go(Routes.driverApplicationStatus);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'application_incomplete') setState(() => _missing = asStringList(e.detailsMap['missing']));
      showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(driverProfileProvider);
    return ApplyScaffold(
      step: 5,
      title: 'Review & submit',
      bottom: AppButton(
        label: 'Submit application',
        icon: Icons.send_rounded,
        loading: _submitting,
        onPressed: _agreed && profile.hasValue && profile.requireValue.canEdit && ApplicationProgress(profile.requireValue).readyToSubmit ? _submit : null,
      ),
      child: AsyncView<DriverProfile>(
        value: profile,
        onRetry: () => ref.invalidate(driverProfileProvider),
        data: (p) {
          final prog = ApplicationProgress(p);
          final v = p.vehicle;
          return ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
            if (!prog.readyToSubmit && _missing.isEmpty) ...[
              InfoBanner(
                tone: StatusTone.warning,
                title: 'Complete all steps to submit',
                message: [
                  if (!prog.personal) 'Personal details',
                  if (!prog.vehicle) 'Vehicle',
                  if (!prog.documents) 'Required documents',
                  if (!prog.payout) 'Payout account',
                ].join('\n'),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            if (_missing.isNotEmpty) ...[
              InfoBanner(tone: StatusTone.danger, title: 'Please complete', message: _missing.map(humanize).join('\n')),
              const SizedBox(height: AppSpace.sm),
            ],
            _Section(
              title: 'Personal details',
              done: prog.personal,
              onEdit: () => context.push(Routes.driverApplyPersonal),
              rows: [
                ('Full name', p.fullName ?? '—'),
                ('CNIC', p.cnicNumberMasked ?? '—'),
                ('Date of birth', formatDate(DateTime.tryParse(p.dateOfBirth ?? ''))),
                ('Licence', p.licenseNumberMasked ?? '—'),
                ('Licence expiry', formatDate(DateTime.tryParse(p.licenseExpiry ?? ''))),
                ('Emergency contact', p.emergencyContactName ?? '—'),
              ],
            ),
            _Section(
              title: 'Vehicle',
              done: prog.vehicle,
              onEdit: () => context.push(Routes.driverApplyVehicle),
              rows: v == null
                  ? const [('Vehicle', 'Not added')]
                  : [
                      ('Category', v.categoryName ?? '—'),
                      ('Vehicle', '${v.title} ${v.year ?? ''}'.trim()),
                      ('Plate', v.plateNumber ?? '—'),
                    ],
            ),
            _Section(
              title: 'Documents',
              done: prog.documents,
              onEdit: () => context.push(Routes.driverApplyDocuments),
              rows: [
                ('Uploaded', '${p.documents.length}'),
                if (p.missingRequiredDocuments.isNotEmpty) ('Missing', p.missingRequiredDocuments.map(documentLabel).join(', ')),
              ],
            ),
            _Section(
              title: 'Payout account',
              done: prog.payout,
              onEdit: () => context.push(Routes.driverApplyPayout),
              rows: [
                ('Method', p.payout.method == null ? 'Required — not set' : humanize(p.payout.method)),
                if (p.payout.isSet) ('Account', '${p.payout.accountTitle ?? ''} · ${p.payout.accountNumberMasked ?? ''}'),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            AppCard(
              color: _agreed ? AppColors.roseSoft : null,
              onTap: () => setState(() => _agreed = !_agreed),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('I agree to the FemaleRider Driver Agreement', style: AppText.title),
                      const SizedBox(height: 2),
                      Text('I confirm the information is accurate and I will follow FemaleRider safety policies.', style: AppText.bodySm),
                      GestureDetector(
                        onTap: () => context.push(Routes.legal('driver-agreement')),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Read the Driver Agreement', style: AppText.label.copyWith(color: AppColors.crimson, decoration: TextDecoration.underline)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
          ]);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.done, required this.onEdit, required this.rows});
  final String title;
  final bool done;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(done ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: done ? AppColors.success : AppColors.warning, size: 20),
            const SizedBox(width: AppSpace.xs),
            Expanded(child: Text(title, style: AppText.h3)),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ]),
          for (final r in rows) KeyValueRow(r.$1, r.$2),
        ]),
      ),
    );
  }
}
