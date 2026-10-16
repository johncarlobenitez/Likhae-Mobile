import 'package:flutter/material.dart';

import '../../features/buyer/ai/buyer_ai_assistant.dart';
import '../../features/buyer/settings/buyer_system_settings_controller.dart';
import 'glass_navigation.dart';

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
    super.key, required this.child, required this.currentIndex,
    required this.onHome,
    required this.onOrders,
    required this.onMessages,
    required this.onProfile,
    this.aiPage = 'buyer',
    this.aiPageTitle = 'Buyer portal',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BuyerSystemSettingsController.instance,
      child: GlassNavigationFrame(child: child, navigation: BuyerBottomNavigation(currentIndex: currentIndex,
          onHome: onHome,
          onOrders: onOrders,
          onMessages: onMessages,
          onProfile: onProfile,
        )),
      builder: (context, page) => Stack(fit: StackFit.expand, children: [
        page!,
        if (BuyerSystemSettingsController.instance.showAiAssistant && MediaQuery.viewInsetsOf(context).bottom == 0)
          Positioned.fill(child: BuyerAiAssistant(page: aiPage, pageTitle: aiPageTitle)),
      ]),
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
    super.key, required this.currentIndex,
    required this.onHome,
    required this.onOrders,
    required this.onMessages,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) => GlassNavigationBar(
    currentIndex: currentIndex,
    destinations: [
      GlassNavigationDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', onTap: onHome),
      GlassNavigationDestination(icon: Icons.shopping_bag_outlined, selectedIcon: Icons.shopping_bag_rounded, label: 'Orders', onTap: onOrders),
      GlassNavigationDestination(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: 'Messages', onTap: onMessages),
      GlassNavigationDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Me', onTap: onProfile),
    ],
  );
}
