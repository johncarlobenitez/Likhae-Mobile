import 'package:flutter/material.dart';
import '../../shared/widgets/glass_navigation.dart';

class RiderNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onAssignments;
  final VoidCallback onHistory;
  final VoidCallback onEarnings;
  final VoidCallback onProfile;


  const RiderNavigationFrame({
    super.key, required this.child, required this.currentIndex,
    required this.onDashboard,
    required this.onAssignments,
    required this.onHistory,
    required this.onEarnings,
    required this.onProfile,

  });

  @override
  Widget build(BuildContext context) {
    return GlassNavigationFrame(child: child, navigation: RiderBottomNavigation(currentIndex: currentIndex,
          onDashboard: onDashboard,
          onAssignments: onAssignments,
          onHistory: onHistory,
          onEarnings: onEarnings,
          onProfile: onProfile,
        ));
  }
}

class RiderBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onAssignments;
  final VoidCallback onHistory;
  final VoidCallback onEarnings;
  final VoidCallback onProfile;

  const RiderBottomNavigation({
    super.key, required this.currentIndex,
    required this.onDashboard,
    required this.onAssignments,
    required this.onHistory,
    required this.onEarnings,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) => GlassNavigationBar(
    currentIndex: currentIndex,
    destinations: [
      GlassNavigationDestination(icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded, label: 'Dashboard', onTap: onDashboard),
      GlassNavigationDestination(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Tasks', onTap: onAssignments),
      GlassNavigationDestination(icon: Icons.history_rounded, selectedIcon: Icons.history_rounded, label: 'History', onTap: onHistory),
      GlassNavigationDestination(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Earnings', onTap: onEarnings),
      GlassNavigationDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile', onTap: onProfile),
    ],
  );
}
