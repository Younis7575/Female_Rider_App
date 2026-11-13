import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../driver/domain/driver_models.dart';
import 'onboarding_providers.dart';
import 'widgets/documents_list.dart';

/// Driver documents & expiry management (also reachable after approval).
class DriverDocumentsScreen extends ConsumerWidget {
  const DriverDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Text('Documents', style: AppText.h3.copyWith(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(driverProfileProvider.future),
        child: AsyncView<DriverProfile>(
          value: profile,
          onRetry: () => ref.invalidate(driverProfileProvider),
          data: (p) => Column(children: [
            if (p.complianceIssues.isNotEmpty && p.status == 'approved')
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 0),
                child: InfoBanner(tone: StatusTone.danger, icon: Icons.gpp_maybe_rounded, title: 'Compliance issues', message: p.complianceIssues.join('\n')),
              ),
            Expanded(child: DriverDocumentsList(profile: p)),
          ]),
        ),
      ),
    );
  }
}
