import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/presentation/app_drawer.dart';
import '../../driver_finance/presentation/pay_screen.dart';
import 'driver_home_screen.dart';
import 'driver_providers.dart';
import 'driver_requests_screen.dart';
import 'requests_controller.dart';

/// Driver mode with an inDrive-style bottom bar: Requests · Home · Wallet.
class DriverShell extends ConsumerWidget {
  const DriverShell({super.key});

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(driverTabProvider);
    final count = ref.watch(driverRequestsProvider.select((r) => r.value?.length ?? 0));
    return Scaffold(
      key: scaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: tab,
        children: const [
          DriverRequestsScreen(embedded: true),
          DriverHomeScreen(),
          PayScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.roseSoft,
        onDestinationSelected: (i) => ref.read(driverTabProvider.notifier).select(i),
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.list_alt_rounded)),
            selectedIcon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.list_alt_rounded, color: AppColors.crimson),
            ),
            label: 'Requests',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.crimson),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.crimson),
            label: 'Wallet',
          ),
        ],
      ),
    );
  }
}
