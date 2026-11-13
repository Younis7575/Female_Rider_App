import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Shared chrome for driver application steps: dark app bar with step progress.
class ApplyScaffold extends StatelessWidget {
  const ApplyScaffold({super.key, required this.step, required this.title, required this.child, this.bottom, this.totalSteps = 4});
  final int step;
  final int totalSteps;
  final String title;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(step <= totalSteps ? 'STEP $step OF $totalSteps' : 'FINAL STEP', style: AppText.overline.copyWith(color: AppColors.roseAccent)),
          Text(title, style: AppText.h3.copyWith(color: Colors.white)),
        ]),
        toolbarHeight: 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (step / (totalSteps + 1)).clamp(0, 1).toDouble(),
            minHeight: 4,
            backgroundColor: AppColors.nightLine,
            color: AppColors.crimson,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: bottom == null ? null : BottomActionBar(child: bottom!),
    );
  }
}
