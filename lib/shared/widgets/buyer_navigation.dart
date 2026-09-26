import 'package:flutter/material.dart';

class BuyerNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  const BuyerNavigationFrame({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onHome,
    required this.onOrders,
    required this.onMessages,
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
          child: BuyerBottomNavigation(
            currentIndex: currentIndex,
            onHome: onHome,
            onOrders: onOrders,
            onMessages: onMessages,
            onProfile: onProfile,
          ),
        ),
      ],
    );
  }
}

class BuyerBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  const BuyerBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onHome,
    required this.onOrders,
    required this.onMessages,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavigationItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
                onTap: onHome,
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.shopping_bag_outlined,
                label: 'My Orders',
                active: currentIndex == 1,
                onTap: onOrders,
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                active: currentIndex == 2,
                onTap: onMessages,
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.person_rounded,
                label: 'Me',
                active: currentIndex == 3,
                onTap: onProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFF561C17);
    const Color inactiveColor = Color(0xFF8A7A72);

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
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
