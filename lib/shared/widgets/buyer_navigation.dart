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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelHeight = MediaQuery.textScalerOf(context).scale(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07),
            blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: colors.primary,
            elevation: 0,
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800 : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? colors.primary : colors.onSurfaceVariant,
            )),
            iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? colors.onPrimary : colors.onSurfaceVariant,
            )),
          ),
          child: NavigationBar(
            height: 76 + (labelHeight - 12).clamp(0, 30),
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              if (index == currentIndex) return;
              [onHome, onOrders, onMessages, onProfile][index]();
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
