import 'package:likhae/core/theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/app_config.dart';
import '../../../features/rider/profile/rider_profile_screen.dart';
import '../../../features/rider/rider_navigation.dart';
import '../../../services/notification_sound_service.dart';
import '../../../services/rider_mobile_service.dart';
import '../../../shared/widgets/buyer_navigation_badges.dart';
import 'buyer_system_settings_controller.dart';

class BuyerSystemSettingsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onMyAccount;
  final VoidCallback? onMyAddresses;
  final VoidCallback? onWallet;
  final VoidCallback? onMessages;
  final VoidCallback? onRewards;
  final VoidCallback? onVouchers;
  final VoidCallback? onReviewHistory;
  final VoidCallback? onFollowingStores;
  final VoidCallback? onRecentlyViewed;
  final VoidCallback? onDangerZone;
  final bool riderMode;

  const BuyerSystemSettingsScreen({
    super.key,
    this.onBack,
    this.onMyAccount,
    this.onMyAddresses,
    this.onWallet,
    this.onMessages,
    this.onRewards,
    this.onVouchers,
    this.onReviewHistory,
    this.onFollowingStores,
    this.onRecentlyViewed,
    this.onDangerZone,
    this.riderMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BuyerSystemSettingsController.instance,
      builder: (BuildContext context, Widget? child) {
        final BuyerSystemSettingsController settings =
            BuyerSystemSettingsController.instance;
        final ColorScheme colors = Theme.of(context).colorScheme;

        if (!riderMode) {
          return _buildBuyerSettingsPage(context, settings, colors);
        }

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            leading: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
            title: const Text('System Settings'),
            actions: [
              const RiderMenuButton(),
              if (onMyAccount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: onMyAccount,
                    child: const Text('My Account'),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                Text(
                  riderMode
                      ? 'Manage how LIKHAE looks, sounds, and keeps you updated on the road.'
                      : 'Fine-tune how LIKHAE looks, sounds, and keeps you informed.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (riderMode) ...<Widget>[
                  const _RiderAvailabilityCard(),
                  const SizedBox(height: 14),
                ],
                _SettingsCard(
                  title: 'Notifications',
                  subtitle: riderMode
                      ? 'Choose which rider updates can alert you.'
                      : 'Choose the Buyer updates you want LIKHAE to send.',
                  icon: Icons.notifications_none_rounded,
                  child: Column(
                    children: riderMode
                        ? <Widget>[
                            _SettingSwitch(
                              title: 'Assignment Alerts',
                              description:
                                  'New pickup and delivery assignments.',
                              value: settings.riderAssignmentUpdates,
                              onChanged: (bool value) => settings.update(
                                riderAssignmentUpdates: value,
                              ),
                            ),
                            _SettingSwitch(
                              title: 'Route & Status Updates',
                              description:
                                  'Handoffs, destination changes, and delivery status reminders.',
                              value: settings.riderRouteUpdates,
                              onChanged: (bool value) =>
                                  settings.update(riderRouteUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Messages',
                              description:
                                  'New messages from buyers and support.',
                              value: settings.riderChatUpdates,
                              onChanged: (bool value) =>
                                  settings.update(riderChatUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Earnings Updates',
                              description:
                                  'Completed-delivery earnings and payout notices.',
                              value: settings.riderEarningsUpdates,
                              onChanged: (bool value) =>
                                  settings.update(riderEarningsUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Safety & Exceptions',
                              description:
                                  'Urgent parcel issues and safety-related notices.',
                              value: settings.riderSafetyUpdates,
                              onChanged: (bool value) =>
                                  settings.update(riderSafetyUpdates: value),
                            ),
                          ]
                        : <Widget>[
                            _SettingSwitch(
                              title: 'Order Updates',
                              description:
                                  'Order confirmation, processing, and status changes.',
                              value: settings.orderUpdates,
                              onChanged: (bool value) =>
                                  settings.update(orderUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Delivery Updates',
                              description:
                                  'Pickup, sorting, rider, and delivery updates.',
                              value: settings.deliveryUpdates,
                              onChanged: (bool value) =>
                                  settings.update(deliveryUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Chat Notifications',
                              description:
                                  'New messages from the existing Messages feature.',
                              value: settings.chatNotifications,
                              onChanged: (bool value) =>
                                  settings.update(chatNotifications: value),
                            ),
                            _SettingSwitch(
                              title: 'Promotions & Vouchers',
                              description:
                                  'Eligible voucher, discount, and promotion updates.',
                              value: settings.promotionUpdates,
                              onChanged: (bool value) =>
                                  settings.update(promotionUpdates: value),
                            ),
                            _SettingSwitch(
                              title: 'Show Online Status',
                              description:
                                  'Let sellers know when you are available in Messages.',
                              value: settings.showOnlineStatus,
                              onChanged: (bool value) =>
                                  settings.update(showOnlineStatus: value),
                            ),
                          ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildAiAndSounds(settings, riderMode: riderMode),
                const SizedBox(height: 14),
                _buildAppearanceAndLanguage(settings),
                const SizedBox(height: 14),
                _buildSaveBar(context, colors, riderMode: riderMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuyerSettingsPage(
    BuildContext context,
    BuyerSystemSettingsController settings,
    ColorScheme colors,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: onBack == null
            ? null
            : IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Account Settings'),
        actions: [
          AnimatedBuilder(
            animation: BuyerNavigationBadges.instance,
            builder: (BuildContext context, Widget? child) {
              final int unread = BuyerNavigationBadges.instance.messageCount;
              return IconButton(
                tooltip: 'Messages',
                onPressed: onMessages,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colors.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _SettingsGroupHeader(title: 'My Account'),
            _SettingsMenuRow(title: 'Account & Security', onTap: onMyAccount),
            _SettingsMenuRow(title: 'My Addresses', onTap: onMyAddresses),
            _SettingsMenuRow(title: 'Wallet', onTap: onWallet),
            _SettingsMenuRow(title: 'Vouchers', onTap: onVouchers),
            _SettingsMenuRow(title: 'Rewards', onTap: onRewards),
            _SettingsMenuRow(
              title: 'My review history',
              onTap: onReviewHistory,
            ),
            _SettingsMenuRow(
              title: 'Following Stores',
              onTap: onFollowingStores,
            ),
            _SettingsMenuRow(
              title: 'Recently Viewed',
              onTap: onRecentlyViewed,
            ),
            const _SettingsGroupHeader(title: 'Settings'),
            _SettingsMenuRow(
              title: 'Chat Settings',
              onTap: () => _openSettingsSheet(
                context,
                'Chat Settings',
                (
                  BuildContext context,
                  BuyerSystemSettingsController value,
                ) => Column(
                  children: [
                    _SettingSwitch(
                      title: 'Chat Notifications',
                      description: 'Get alerts for new messages.',
                      value: value.chatNotifications,
                      onChanged: (bool enabled) =>
                          value.update(chatNotifications: enabled),
                    ),
                    _SettingSwitch(
                      title: 'Show Online Status',
                      description:
                          'Let sellers know when you are available in Messages.',
                      value: value.showOnlineStatus,
                      onChanged: (bool enabled) =>
                          value.update(showOnlineStatus: enabled),
                    ),
                  ],
                ),
              ),
            ),
            _SettingsMenuRow(
              title: 'Order Settings',
              onTap: () => _openSettingsSheet(
                context,
                'Order Settings',
                (
                  BuildContext context,
                  BuyerSystemSettingsController value,
                ) => Column(
                  children: [
                    _SettingSwitch(
                      title: 'Order Updates',
                      description:
                          'Order confirmation, processing, and status changes.',
                      value: value.orderUpdates,
                      onChanged: (bool enabled) =>
                          value.update(orderUpdates: enabled),
                    ),
                    _SettingSwitch(
                      title: 'Delivery Updates',
                      description:
                          'Pickup, sorting, rider, and delivery updates.',
                      value: value.deliveryUpdates,
                      onChanged: (bool enabled) =>
                          value.update(deliveryUpdates: enabled),
                    ),
                  ],
                ),
              ),
            ),
            _SettingsMenuRow(
              title: 'Notification Settings',
              onTap: () => _openSettingsSheet(
                context,
                'Notification Settings',
                (
                  BuildContext context,
                  BuyerSystemSettingsController value,
                ) => Column(
                  children: [
                    _SettingSwitch(
                      title: 'Promotions & Vouchers',
                      description:
                          'Eligible voucher, discount, and promotion updates.',
                      value: value.promotionUpdates,
                      onChanged: (bool enabled) =>
                          value.update(promotionUpdates: enabled),
                    ),
                    _SettingSwitch(
                      title: 'Notification Sounds',
                      description: 'Play sounds for supported LIKHAE alerts.',
                      value: value.notificationSounds,
                      onChanged: (bool enabled) =>
                          value.update(notificationSounds: enabled),
                    ),
                    for (final NotificationSoundOption sound
                        in NotificationSoundService.catalog)
                      _SoundPreviewRow(sound: sound),
                  ],
                ),
                scrollContent: true,
              ),
            ),
            _SettingsMenuRow(
              title: 'Privacy Settings',
              onTap: () => _openSettingsSheet(
                context,
                'Privacy Settings',
                (
                  BuildContext context,
                  BuyerSystemSettingsController value,
                ) => Column(
                  children: [
                    _SettingSwitch(
                      title: 'Show Online Status',
                      description:
                          'Let sellers know when you are available in Messages.',
                      value: value.showOnlineStatus,
                      onChanged: (bool enabled) =>
                          value.update(showOnlineStatus: enabled),
                    ),
                    _SettingSwitch(
                      title: 'Show AI Assistant',
                      description: 'Show the floating LIKHAE AI chat button.',
                      value: value.showAiAssistant,
                      onChanged: (bool enabled) =>
                          value.update(showAiAssistant: enabled),
                    ),
                  ],
                ),
              ),
            ),
            _SettingsMenuRow(
              title: 'Blocked Users',
              onTap: () => _showSettingsInfo(
                context,
                'Blocked Users',
                'Blocked-user management is not available yet.',
              ),
            ),
            _SettingsMenuRow(
              title: 'Language / 语言 / Wika',
              subtitle: 'English',
              onTap: () => _openSettingsSheet(
                context,
                'Language / Appearance',
                (BuildContext context, BuyerSystemSettingsController value) =>
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Appearance',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            _ThemeChoice(
                              icon: Icons.light_mode_outlined,
                              label: 'Light',
                              selected: value.themeMode == ThemeMode.light,
                              onTap: () => value.setTheme(ThemeMode.light),
                            ),
                            _ThemeChoice(
                              icon: Icons.dark_mode_outlined,
                              label: 'Dark',
                              selected: value.themeMode == ThemeMode.dark,
                              onTap: () => value.setTheme(ThemeMode.dark),
                            ),
                            _ThemeChoice(
                              icon: Icons.brightness_auto_outlined,
                              label: 'System',
                              selected: value.themeMode == ThemeMode.system,
                              onTap: () => value.setTheme(ThemeMode.system),
                            ),
                          ],
                        ),
                        const Divider(),
                        const Text(
                          'Display language',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('English'),
                          trailing: Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
              ),
            ),
            const _SettingsGroupHeader(title: 'Support'),
            _SettingsMenuRow(
              title: 'Help Centre',
              onTap: () => _showSettingsInfo(
                context,
                'Help Centre',
                'For help with an order or seller, open Messages from the bottom navigation.',
                actionLabel: 'Open Messages',
                onAction: onMessages,
              ),
            ),
            _SettingsMenuRow(
              title: 'Community Rules',
              onTap: () => _showSettingsInfo(
                context,
                'Community Rules',
                'Be respectful, provide accurate information, and use LIKHAE for lawful products and honest transactions.',
              ),
            ),
            _SettingsMenuRow(
              title: 'LIKHAE Policies',
              onTap: () => _showSettingsInfo(
                context,
                'LIKHAE Policies',
                'Current Terms & Conditions and Privacy Policy are shown during registration.',
              ),
            ),
            _SettingsMenuRow(
              title: 'Happy with LIKHAE? Rate us!',
              onTap: () => _showSettingsInfo(
                context,
                'Rate LIKHAE',
                'App-store ratings are not available yet. Thank you for supporting LIKHAE.',
              ),
            ),
            _SettingsMenuRow(
              title: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'LIKHAE',
                applicationVersion: '1.0.0',
                applicationLegalese: 'A marketplace for local finds.',
              ),
            ),
            const _SettingsGroupHeader(title: 'Account'),
            _SettingsMenuRow(title: 'Danger Zone', onTap: onDangerZone),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openSettingsSheet(
    BuildContext context,
    String title,
    Widget Function(BuildContext, BuyerSystemSettingsController) content, {
    bool scrollContent = false,
  }) {
    final BuyerSystemSettingsController settings =
        BuyerSystemSettingsController.instance;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: scrollContent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, Widget? child) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (scrollContent)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: ListView(
                    primary: false,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [content(context, settings)],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: content(context, settings),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final bool synced = await settings.save(
                          syncServer: true,
                        );
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              synced
                                  ? 'Settings saved.'
                                  : 'Device settings saved. Account sync is unavailable right now.',
                            ),
                          ),
                        );
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Save Settings'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsInfo(
    BuildContext context,
    String title,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onAction();
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  Widget _buildAiAndSounds(
    BuyerSystemSettingsController settings, {
    required bool riderMode,
  }) {
    final Widget aiCard = _SettingsCard(
      title: 'LIKHAE AI Assistant',
      subtitle: 'Control the optional Buyer AI assistant.',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          _SettingSwitch(
            title: 'Show AI Assistant',
            description: 'Show the floating AI chat head on Buyer pages.',
            value: settings.showAiAssistant,
            onChanged: (bool value) => settings.update(showAiAssistant: value),
          ),
          _SettingSwitch(
            title: 'AI Response Sound',
            description: 'Play a subtle sound after the assistant replies.',
            value: settings.aiResponseSound,
            onChanged: (bool value) => settings.update(aiResponseSound: value),
          ),
        ],
      ),
    );
    final Widget soundsCard = _SettingsCard(
      title: 'Sounds',
      subtitle: 'Manage LIKHAE interface sound cues.',
      icon: Icons.music_note_rounded,
      child: Column(
        children: [
          _SettingSwitch(
            title: 'Notification Sounds',
            description: 'Play sounds for supported LIKHAE notifications.',
            value: riderMode
                ? settings.riderNotificationSounds
                : settings.notificationSounds,
            onChanged: (bool value) => settings.update(
              notificationSounds: riderMode ? null : value,
              riderNotificationSounds: riderMode ? value : null,
            ),
          ),
          const SizedBox(height: 6),
          for (final NotificationSoundOption sound
              in NotificationSoundService.catalog)
            _SoundPreviewRow(sound: sound),
        ],
      ),
    );

    if (riderMode) return soundsCard;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [aiCard, const SizedBox(height: 14), soundsCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: aiCard),
            const SizedBox(width: 14),
            Expanded(child: soundsCard),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceAndLanguage(BuyerSystemSettingsController settings) {
    final Widget appearanceCard = _SettingsCard(
      title: 'Appearance',
      subtitle: 'Apply your preferred LIKHAE theme.',
      icon: Icons.brightness_6_outlined,
      child: Row(
        children: [
          _ThemeChoice(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: settings.themeMode == ThemeMode.light,
            onTap: () => settings.setTheme(ThemeMode.light),
          ),
          _ThemeChoice(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: settings.themeMode == ThemeMode.dark,
            onTap: () => settings.setTheme(ThemeMode.dark),
          ),
          _ThemeChoice(
            icon: Icons.brightness_auto_outlined,
            label: 'System',
            selected: settings.themeMode == ThemeMode.system,
            onTap: () => settings.setTheme(ThemeMode.system),
          ),
        ],
      ),
    );
    final Widget languageCard = _SettingsCard(
      title: 'Language',
      subtitle: 'More languages will appear when translations are ready.',
      icon: Icons.translate_rounded,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Display language',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: 'en',
              decoration: const InputDecoration(isDense: true),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: null,
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              appearanceCard,
              const SizedBox(height: 14),
              languageCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: appearanceCard),
            const SizedBox(width: 14),
            Expanded(child: languageCard),
          ],
        );
      },
    );
  }

  Widget _buildSaveBar(
    BuildContext context,
    ColorScheme colors, {
    required bool riderMode,
  }) {
    final Widget saveButton = FilledButton(
      onPressed: () async {
        try {
          final bool synced = await BuyerSystemSettingsController.instance.save(
            syncServer: true,
            riderMode: riderMode,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                synced
                    ? 'Settings saved.'
                    : 'Device settings saved. Account sync is unavailable right now.',
              ),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save settings. Try again.'),
            ),
          );
        }
      },
      child: const Text('Save Settings'),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  riderMode
                      ? 'Changes apply immediately to this Rider app.'
                      : 'Changes apply immediately to this Buyer app.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                saveButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  riderMode
                      ? 'Changes apply immediately to this Rider app.'
                      : 'Changes apply immediately to this Buyer app.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ),
              saveButton,
            ],
          );
        },
      ),
    );
  }
}

class _RiderAvailabilityCard extends StatefulWidget {
  const _RiderAvailabilityCard();

  @override
  State<_RiderAvailabilityCard> createState() => _RiderAvailabilityCardState();
}

class _RiderAvailabilityCardState extends State<_RiderAvailabilityCard> {
  RiderProfileData? _profile;
  bool _isOnline = false;
  bool _loading = true;
  bool _saving = false;
  String? _savingMessage;
  String? _error;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (!AppConfig.apiEnabled) {
      setState(() {
        _loading = false;
        _error = 'Connect to the Rider API to load your online status.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final RiderProfileData profile = await RiderMobileService.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isOnline = profile.isOnline;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setAvailability(bool isOnline) async {
    if (_saving || !AppConfig.apiEnabled) return;
    setState(() {
      _saving = true;
      _savingMessage = isOnline
          ? 'Saving online status…'
          : 'Saving offline status…';
      _actionError = null;
    });
    try {
      final Future<bool> update = RiderMobileService.updateAvailability(
        isOnline,
      );
      final bool savedStatus = await update.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'The server took too long to update your availability. Check your connection and try again.',
        ),
      );
      if (!mounted) return;
      setState(() {
        _isOnline = savedStatus;
        _actionError = null;
        _saving = false;
        _savingMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profile?.isVan == true
                ? (savedStatus
                      ? 'You are online and available for transfer assignments.'
                      : 'You are offline and will not receive new transfer assignments.')
                : (savedStatus
                      ? 'You are online and available for assignments.'
                      : 'You are offline and will not receive new assignments.'),
          ),
        ),
      );
      if (savedStatus && _profile?.isLocalBarangay == true) {
        unawaited(_syncAvailabilityLocation());
      }
    } catch (error) {
      if (!mounted) return;
      final String message = _availabilityErrorText(error);
      setState(() {
        _actionError = message;
        _saving = false;
        _savingMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update your status: $message')),
      );
    } finally {
      if (mounted && _saving) {
        setState(() {
          _saving = false;
          _savingMessage = null;
        });
      }
    }
  }

  Future<void> _syncAvailabilityLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
      )) {
        return;
      }
      final LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 2));
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (position == null ||
          DateTime.now().difference(position.timestamp) >
              const Duration(minutes: 5)) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      }
      await RiderMobileService.updateAvailabilityLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Saving availability does not wait on GPS; the tracker will retry later.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool interHubVan = _profile?.isVan == true;
    return _SettingsCard(
      title: interHubVan ? 'Account Visibility' : 'Rider Availability',
      subtitle: interHubVan
          ? 'Choose whether your hub can see that you are available for inter-hub transfers.'
          : 'Choose whether dispatch can assign new deliveries to you.',
      icon: interHubVan ? Icons.circle : Icons.wifi_tethering_rounded,
      iconTile: interHubVan,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: interHubVan ? 4 : 12),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            : _error != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _loadAvailability,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ),
                ],
              )
            : _profile?.supportsAvailabilityStatus != true
            ? Text(
                'Availability controls are for local motorcycle, tricycle, and van riders.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              )
            : interHubVan
            ? Column(
                children: [
                  _SettingSwitch(
                    title: 'Show Online Status',
                    description:
                        'When off, your hub will not assign new transfers while you continue using LIKHAE.',
                    value: _isOnline,
                    onChanged: _saving ? null : _setAvailability,
                  ),
                  if (_savingMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _savingMessage!,
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  if (_actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _actionError!,
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOnline
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_filled_rounded,
                        size: 18,
                        color: _isOnline
                            ? AppTheme.resolve(context, const Color(0xFF27856E))
                            : colors.onSurface.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _isOnline ? 'Currently Online' : 'Currently Offline',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_saving) ...<Widget>[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (_savingMessage != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      _savingMessage!,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.wifi_tethering_rounded),
                          label: Text('Online'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.wifi_off_rounded),
                          label: Text('Offline'),
                        ),
                      ],
                      selected: <bool>{_isOnline},
                      onSelectionChanged: _saving
                          ? null
                          : (Set<bool> selection) =>
                                _setAvailability(selection.first),
                    ),
                  ),
                  if (_actionError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _actionError!,
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _availabilityErrorText(Object error) {
    if (error is StateError) return error.message.toString();
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}

class _SettingsGroupHeader extends StatelessWidget {
  final String title;

  const _SettingsGroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F3F3),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 9),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.58),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsMenuRow({required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: subtitle == null ? 14 : 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 14)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.58),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurface.withValues(alpha: 0.58),
                    size: 21,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.7, color: const Color(0xFFECECEC)),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool iconTile;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconTile = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (iconTile)
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: colors.onPrimary, size: 8),
                  )
                else
                  Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.62),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SoundPreviewRow extends StatelessWidget {
  final NotificationSoundOption sound;

  const _SoundPreviewRow({required this.sound});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sound.description,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.62),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () =>
                unawaited(NotificationSoundService.preview(sound.key)),
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.62),
          fontSize: 11,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 3),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
