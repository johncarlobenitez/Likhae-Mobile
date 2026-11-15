import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../buyer/settings/buyer_system_settings_controller.dart';
import '../../shared/widgets/glass_navigation.dart';

class RiderNavigationFrame extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final int mobileCurrentIndex;
  final bool isInterLogistics;
  final VoidCallback onDashboard;
  final VoidCallback onPickups;
  final VoidCallback onDeliveries;
  final VoidCallback onScanner;
  final VoidCallback onTransfers;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;
  final VoidCallback? onReturns;
  final VoidCallback? onHistory;
  final VoidCallback? onRemittances;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onPayouts;
  final VoidCallback? onAttendance;
  final Future<void> Function()? onLogout;

  const RiderNavigationFrame({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.mobileCurrentIndex,
    required this.isInterLogistics,
    required this.onDashboard,
    required this.onPickups,
    required this.onDeliveries,
    required this.onScanner,
    required this.onTransfers,
    required this.onEarnings,
    required this.onMessages,
    required this.onProfile,
    this.onReturns,
    this.onHistory,
    this.onRemittances,
    this.onNotifications,
    this.onSettings,
    this.onPayouts,
    this.onAttendance,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth > 700) {
          return GlassNavigationFrame(
            navigation: RiderBottomNavigation(
              currentIndex: currentIndex,
              isInterLogistics: isInterLogistics,
              onDashboard: onDashboard,
              onPickups: onPickups,
              onDeliveries: onDeliveries,
              onScanner: onScanner,
              onTransfers: onTransfers,
              onEarnings: onEarnings,
              onMessages: onMessages,
              onProfile: onProfile,
            ),
            child: child,
          );
        }

        return _RiderMobileNavigationFrame(
          mobileCurrentIndex: mobileCurrentIndex,
          isInterLogistics: isInterLogistics,
          onDashboard: onDashboard,
          onPickups: onPickups,
          onDeliveries: onDeliveries,
          onScanner: onScanner,
          onTransfers: onTransfers,
          onEarnings: onEarnings,
          onMessages: onMessages,
          onProfile: onProfile,
          onReturns: onReturns,
          onHistory: onHistory,
          onRemittances: onRemittances,
          onNotifications: onNotifications,
          onSettings: onSettings,
          onPayouts: onPayouts,
          onAttendance: onAttendance,
          onLogout: onLogout,
          child: child,
        );
      },
    );
  }
}

class _RiderMobileNavigationFrame extends StatefulWidget {
  final Widget child;
  final int mobileCurrentIndex;
  final bool isInterLogistics;
  final VoidCallback onDashboard;
  final VoidCallback onPickups;
  final VoidCallback onDeliveries;
  final VoidCallback onScanner;
  final VoidCallback onTransfers;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;
  final VoidCallback? onReturns;
  final VoidCallback? onHistory;
  final VoidCallback? onRemittances;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onPayouts;
  final VoidCallback? onAttendance;
  final Future<void> Function()? onLogout;

  const _RiderMobileNavigationFrame({
    required this.child,
    required this.mobileCurrentIndex,
    required this.isInterLogistics,
    required this.onDashboard,
    required this.onPickups,
    required this.onDeliveries,
    required this.onScanner,
    required this.onTransfers,
    required this.onEarnings,
    required this.onMessages,
    required this.onProfile,
    required this.onReturns,
    required this.onHistory,
    required this.onRemittances,
    required this.onNotifications,
    required this.onSettings,
    required this.onPayouts,
    required this.onAttendance,
    required this.onLogout,
  });

  @override
  State<_RiderMobileNavigationFrame> createState() =>
      _RiderMobileNavigationFrameState();
}

class _RiderMobileNavigationFrameState
    extends State<_RiderMobileNavigationFrame> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      drawer: _RiderMobileDrawer(
        isInterLogistics: widget.isInterLogistics,
        onDashboard: widget.onDashboard,
        onPickups: widget.onPickups,
        onDeliveries: widget.onDeliveries,
        onTransfers: widget.onTransfers,
        onEarnings: widget.onEarnings,
        onMessages: widget.onMessages,
        onProfile: widget.onProfile,
        onReturns: widget.onReturns,
        onHistory: widget.onHistory,
        onRemittances: widget.onRemittances,
        onNotifications: widget.onNotifications,
        onSettings: widget.onSettings,
        onPayouts: widget.onPayouts,
        onAttendance: widget.onAttendance,
        onLogout: widget.onLogout,
      ),
      body: _RiderMenuScope(
        openMenu: () => _scaffoldKey.currentState?.openDrawer(),
        child: widget.child,
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: RiderBottomNavigation(
                    currentIndex: widget.mobileCurrentIndex,
                    isInterLogistics: widget.isInterLogistics,
                    isMobile: true,
                    onDashboard: widget.onDashboard,
                    onPickups: widget.onPickups,
                    onDeliveries: widget.onDeliveries,
                    onScanner: widget.onScanner,
                    onTransfers: widget.onTransfers,
                    onEarnings: widget.onEarnings,
                    onMessages: widget.onMessages,
                    onProfile: widget.onProfile,
                  ),
                ),
              ),
            ),
    );
  }
}

class RiderMenuButton extends StatelessWidget {
  const RiderMenuButton({
    super.key,
    this.tooltip = 'Open menu',
    this.fallbackToBack = false,
  });

  final String tooltip;
  final bool fallbackToBack;

  @override
  Widget build(BuildContext context) {
    final _RiderMenuScope? scope =
        context.dependOnInheritedWidgetOfExactType<_RiderMenuScope>();
    if (scope == null) {
      if (fallbackToBack && Navigator.of(context).canPop()) {
        return const BackButton();
      }
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: scope.openMenu,
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.resolve(context, const Color(0xFF561C17)),
        backgroundColor: AppTheme.resolve(
          context,
          const Color(0xFFFFFDF9),
          fill: true,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: AppTheme.resolve(context, const Color(0xFFEADCCC)),
          ),
        ),
        fixedSize: const Size(42, 42),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.menu_rounded, size: 22),
    );
  }
}

class _RiderMenuScope extends InheritedWidget {
  final VoidCallback openMenu;

  const _RiderMenuScope({required this.openMenu, required super.child});

  @override
  bool updateShouldNotify(_RiderMenuScope oldWidget) =>
      openMenu != oldWidget.openMenu;
}

class _RiderMenuEntry {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _RiderMenuEntry(this.title, this.icon, this.onTap);
}

class _RiderMobileDrawer extends StatelessWidget {
  final bool isInterLogistics;
  final VoidCallback onDashboard;
  final VoidCallback onPickups;
  final VoidCallback onDeliveries;
  final VoidCallback onTransfers;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;
  final VoidCallback? onReturns;
  final VoidCallback? onHistory;
  final VoidCallback? onRemittances;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onPayouts;
  final VoidCallback? onAttendance;
  final Future<void> Function()? onLogout;

  const _RiderMobileDrawer({
    required this.isInterLogistics,
    required this.onDashboard,
    required this.onPickups,
    required this.onDeliveries,
    required this.onTransfers,
    required this.onEarnings,
    required this.onMessages,
    required this.onProfile,
    required this.onReturns,
    required this.onHistory,
    required this.onRemittances,
    required this.onNotifications,
    required this.onSettings,
    required this.onPayouts,
    required this.onAttendance,
    required this.onLogout,
  });

  void _navigate(BuildContext context, VoidCallback? action) {
    if (action == null) return;
    Navigator.of(context).pop();
    action();
  }

  Widget _section(
    BuildContext context,
    String title,
    List<_RiderMenuEntry> entries, {
    bool collapsible = true,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final Color text = AppTheme.resolve(context, const Color(0xFF3B211B));
    final Color maroon = AppTheme.resolve(context, const Color(0xFF561C17));
    final Color muted = AppTheme.resolve(context, const Color(0xFF795D52));
    final Text sectionTitle = Text(
      title.toUpperCase(),
      style: TextStyle(
        color: muted,
        fontSize: 10.5,
        height: 1.2,
        letterSpacing: 1.35,
        fontWeight: FontWeight.w800,
      ),
    );
    final List<Widget> entryTiles = <Widget>[
      for (final _RiderMenuEntry entry in entries)
        ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          minVerticalPadding: 7,
          minLeadingWidth: 30,
          horizontalTitleGap: 12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(entry.icon, size: 20, color: maroon),
          title: Text(
            entry.title,
            style: TextStyle(
              color: text,
              fontSize: 14,
              height: 1.25,
              letterSpacing: .1,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: entry.onTap == null
              ? null
              : () => _navigate(context, entry.onTap),
        ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: maroon.withValues(alpha: .06),
        highlightColor: Colors.transparent,
      ),
      child: collapsible
          ? ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 18),
              childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 7),
              visualDensity: const VisualDensity(vertical: -3),
              shape: const Border(),
              collapsedShape: const Border(),
              title: sectionTitle,
              iconColor: maroon,
              collapsedIconColor: muted,
              children: entryTiles,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: sectionTitle,
                  ),
                ),
                ...entryTiles,
                const SizedBox(height: 7),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double drawerWidth = (MediaQuery.sizeOf(context).width * .70)
        .clamp(250.0, 320.0)
        .toDouble();
    final Color surface = AppTheme.resolve(
      context,
      const Color(0xFFFBF7F2),
      fill: true,
    );
    final Color maroon = AppTheme.resolve(context, const Color(0xFF561C17));
    final Color text = AppTheme.resolve(context, const Color(0xFF3B211B));
    final Color muted = AppTheme.resolve(context, const Color(0xFF795D52));
    final Color card = AppTheme.resolve(context, const Color(0xFFFFFDF9), fill: true);

    final List<Widget> sections = <Widget>[
      if (!isInterLogistics)
        _section(
          context,
          'History',
          <_RiderMenuEntry>[
            _RiderMenuEntry('Delivery history', Icons.history_rounded, onHistory),
          ],
          collapsible: false,
        ),
      _section(context, 'Wallet', <_RiderMenuEntry>[
        _RiderMenuEntry('Wallet & payouts', Icons.account_balance_wallet_outlined, onEarnings),
        if (!isInterLogistics && onPayouts != null)
          _RiderMenuEntry('Payout history', Icons.payments_outlined, onPayouts),
        if (!isInterLogistics && onRemittances != null)
          _RiderMenuEntry('COD remittances', Icons.receipt_long_outlined, onRemittances),
      ]),
      _section(context, 'Account', <_RiderMenuEntry>[
        _RiderMenuEntry('Messages', Icons.chat_bubble_outline_rounded, onMessages),
        if (onNotifications != null)
          _RiderMenuEntry('Notifications', Icons.notifications_none_rounded, onNotifications),
        if (isInterLogistics && onAttendance != null)
          _RiderMenuEntry('Attendance', Icons.event_available_outlined, onAttendance),
        _RiderMenuEntry('System settings', Icons.settings_outlined, onSettings),
      ]),
    ];

    return Drawer(
      width: drawerWidth,
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                children: <Widget>[
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/logistics/logistics-dark.png'
                        : 'assets/logistics/logistics-light.png',
                    width: 142,
                    height: 44,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    semanticLabel: 'LIKHAE Logistics',
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: card,
                      shape: BoxShape.circle,
                      border: Border.all(color: maroon.withValues(alpha: .13)),
                    ),
                    child: IconButton(
                      tooltip: 'Close menu',
                      onPressed: () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded, color: text, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: maroon.withValues(alpha: .12)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 5),
                children: sections,
              ),
            ),
            Divider(height: 1, color: maroon.withValues(alpha: .12)),
            if (onSettings != null)
              AnimatedBuilder(
                animation: BuyerSystemSettingsController.instance,
                builder: (BuildContext context, Widget? child) {
                  final BuyerSystemSettingsController settings =
                      BuyerSystemSettingsController.instance;
                  final bool isDark = switch (settings.themeMode) {
                    ThemeMode.dark => true,
                    ThemeMode.light => false,
                    ThemeMode.system =>
                      Theme.of(context).brightness == Brightness.dark,
                  };
                  return ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    minVerticalPadding: 8,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(
                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: maroon,
                      size: 21,
                    ),
                    title: Text(
                      'Appearance',
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      isDark ? 'Dark mode' : 'Light mode',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeTrackColor: maroon,
                      onChanged: (bool value) => settings.setTheme(
                        value ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                    onTap: () => settings.setTheme(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  );
                },
              ),
            if (onLogout != null)
              ListTile(
                visualDensity: const VisualDensity(vertical: -2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(Icons.logout_rounded, color: maroon, size: 21),
                title: Text(
                  'Log out',
                  style: TextStyle(
                    color: maroon,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await onLogout!.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class RiderBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final bool isInterLogistics;
  final bool isMobile;
  final VoidCallback onDashboard;
  final VoidCallback onPickups;
  final VoidCallback onDeliveries;
  final VoidCallback onScanner;
  final VoidCallback onTransfers;
  final VoidCallback onEarnings;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  const RiderBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.isInterLogistics,
    this.isMobile = false,
    required this.onDashboard,
    required this.onPickups,
    required this.onDeliveries,
    required this.onScanner,
    required this.onTransfers,
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
        : isMobile
        ? <GlassNavigationDestination>[
            GlassNavigationDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: 'Dashboard',
              onTap: onDashboard,
            ),
            GlassNavigationDestination(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              label: 'Pickup',
              onTap: onPickups,
            ),
            GlassNavigationDestination(
              icon: Icons.qr_code_scanner_outlined,
              selectedIcon: Icons.qr_code_scanner_rounded,
              label: 'Scan',
              prominent: true,
              onTap: onScanner,
            ),
            GlassNavigationDestination(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping_rounded,
              label: 'Delivery',
              onTap: onDeliveries,
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
              label: 'Pickup',
              onTap: onPickups,
            ),
            GlassNavigationDestination(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping_rounded,
              label: 'Delivery',
              onTap: onDeliveries,
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
