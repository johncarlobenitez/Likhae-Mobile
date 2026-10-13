import 'package:flutter/material.dart';

import '../../features/buyer/ai/buyer_ai_assistant.dart';
import '../../features/buyer/settings/buyer_system_settings_screen.dart';

class BuyerNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onProfile;
  final String aiPage;
  final String aiPageTitle;

  const BuyerNavigationFrame({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onHome,
    required this.onOrders,
    required this.onMessages,
    required this.onProfile,
    this.aiPage = 'buyer',
    this.aiPageTitle = 'Buyer portal',
  });

  @override
  Widget build(BuildContext context) {
    final Color background = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: background,
      child: AnimatedBuilder(
        animation: BuyerSystemSettingsController.instance,
        child: child,
        builder: (BuildContext context, Widget? childWidget) {
          final bool showAssistant =
              BuyerSystemSettingsController.instance.showAiAssistant;
          final double bottomNavigationSpace =
              72 + 18 + MediaQuery.of(context).padding.bottom;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                bottom: bottomNavigationSpace,
                child: childWidget ?? child,
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18 + MediaQuery.of(context).padding.bottom,
                child: RepaintBoundary(
                  child: BuyerBottomNavigation(
                    currentIndex: currentIndex,
                    onHome: onHome,
                    onOrders: onOrders,
                    onMessages: onMessages,
                    onProfile: onProfile,
                  ),
                ),
              ),
              if (showAssistant)
                Positioned.fill(
                  child: BuyerAiAssistant(page: aiPage, pageTitle: aiPageTitle),
                ),
            ],
          );
        },
      ),
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // An opaque surface avoids an expensive BackdropFilter during scrolling.
    final Color navigationSurface = (isDark ? Colors.black : Colors.white)
        .withValues(alpha: isDark ? 0.88 : 0.94);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: navigationSurface,
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: isDark ? 0.14 : 0.08),
            ),
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
                  child: Transform.translate(
                    offset: const Offset(-10, 0),
                    child: _NavigationItem(
                      icon: Icons.person_rounded,
                      label: 'Me',
                      active: currentIndex == 3,
                      onTap: onProfile,
                    ),
                  ),
                ),
            ],
          ),
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
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.62);

    return Semantics(
      button: true,
      label: label,
      child: Material(
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
      ),
    );
  }
}
