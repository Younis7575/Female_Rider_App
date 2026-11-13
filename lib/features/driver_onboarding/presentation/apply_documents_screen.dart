import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/apply_scaffold.dart';
import 'widgets/documents_list.dart';

/// Application step 3: documents.
class ApplyDocumentsScreen extends ConsumerWidget {
  const ApplyDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return ApplyScaffold(
      step: 3,
      title: 'Documents',
      bottom: profile.hasValue
          ? AppButton(
              label: ApplicationProgress(profile.requireValue).documents ? 'Continue' : 'Continue later',
              onPressed: () => context.push(Routes.driverApplyPayout),
            )
          : null,
      child: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(driverProfileProvider.future),
        child: AsyncView<DriverProfile>(
          value: profile,
          onRetry: () => ref.invalidate(driverProfileProvider),
          data: (p) => DriverDocumentsList(profile: p),
        ),
      ),
    );
  }
}
