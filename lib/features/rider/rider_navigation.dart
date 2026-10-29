import 'package:flutter/material.dart';

import '../../shared/widgets/glass_navigation.dart';

class RiderNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final bool isInterLogistics;
  final VoidCallback onDashboard;
  final VoidCallback onAssignments;
  final VoidCallback onTransfers;
  final VoidCallback onHistory;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  const RiderNavigationFrame({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.isInterLogistics,
    required this.onDashboard,
    required this.onAssignments,
    required this.onTransfers,
    required this.onHistory,
    required this.onEarnings,
    required this.onMessages,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GlassNavigationFrame(
      navigation: RiderBottomNavigation(
        currentIndex: currentIndex,
        isInterLogistics: isInterLogistics,
        onDashboard: onDashboard,
        onAssignments: onAssignments,
        onTransfers: onTransfers,
        onHistory: onHistory,
        onEarnings: onEarnings,
        onMessages: onMessages,
        onProfile: onProfile,
      ),
      child: child,
    );
  }
}

class RiderBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final bool isInterLogistics;
  final VoidCallback onDashboard;
  final VoidCallback onAssignments;
  final VoidCallback onTransfers;
  final VoidCallback onHistory;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  const RiderBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.isInterLogistics,
    required this.onDashboard,
    required this.onAssignments,
    required this.onTransfers,
    required this.onHistory,
    required this.onEarnings,
    required this.onMessages,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final List<GlassNavigationDestination> destinations = isInterLogistics
        ? <GlassNavigationDestination>[
            GlassNavigationDestination(
              icon: Icons.swap_horiz_rounded,
              selectedIcon: Icons.swap_horiz_rounded,
              label: 'Transfers',
              onTap: onTransfers,
            ),
            GlassNavigationDestination(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: 'Earnings',
              onTap: onEarnings,
            ),
            GlassNavigationDestination(
              icon: Icons.chat_bubble_outline_rounded,
              selectedIcon: Icons.chat_bubble_rounded,
              label: 'Messages',
              onTap: onMessages,
            ),
            GlassNavigationDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
              onTap: onProfile,
            ),
          ]
        : <GlassNavigationDestination>[
            GlassNavigationDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: 'Dashboard',
              onTap: onDashboard,
            ),
            GlassNavigationDestination(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              label: 'Tasks',
              onTap: onAssignments,
            ),
            GlassNavigationDestination(
              icon: Icons.history_rounded,
              selectedIcon: Icons.history_rounded,
              label: 'History',
              onTap: onHistory,
            ),
            GlassNavigationDestination(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: 'Earnings',
              onTap: onEarnings,
            ),
            GlassNavigationDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
              onTap: onProfile,
            ),
          ];

    return GlassNavigationBar(
      currentIndex: currentIndex,
      destinations: destinations,
    );
  }
}
