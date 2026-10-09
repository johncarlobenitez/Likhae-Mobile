import 'package:flutter/material.dart';

class RiderNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onAssignments;
  final VoidCallback onHistory;
  final VoidCallback onEarnings;
  final VoidCallback onProfile;

  const RiderNavigationFrame({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDashboard,
    required this.onAssignments,
    required this.onHistory,
    required this.onEarnings,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: RiderBottomNavigation(
            currentIndex: currentIndex,
            onDashboard: onDashboard,
            onAssignments: onAssignments,
            onHistory: onHistory,
            onEarnings: onEarnings,
            onProfile: onProfile,
          ),
        ),
      ],
    );
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
    super.key,
    required this.currentIndex,
    required this.onDashboard,
    required this.onAssignments,
    required this.onHistory,
    required this.onEarnings,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _RiderNavigationItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                active: currentIndex == 0,
                onTap: onDashboard,
              ),
            ),
            Expanded(
              child: _RiderNavigationItem(
                icon: Icons.inventory_2_outlined,
                label: 'Assignments',
                active: currentIndex == 1,
                onTap: onAssignments,
              ),
            ),
            Expanded(
              child: _RiderNavigationItem(
                icon: Icons.history_rounded,
                label: 'History',
                active: currentIndex == 2,
                onTap: onHistory,
              ),
            ),
            Expanded(
              child: _RiderNavigationItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Earnings',
                active: currentIndex == 3,
                onTap: onEarnings,
              ),
            ),
            Expanded(
              child: _RiderNavigationItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                active: currentIndex == 4,
                onTap: onProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RiderNavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.62);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? activeColor : inactiveColor,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                color: active ? activeColor : inactiveColor,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
