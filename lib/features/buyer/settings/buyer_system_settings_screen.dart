import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';

class BuyerSystemSettingsController extends ChangeNotifier {
  BuyerSystemSettingsController._();

  static final BuyerSystemSettingsController instance =
      BuyerSystemSettingsController._();

  bool orderUpdates = true;
  bool deliveryUpdates = true;
  bool chatNotifications = true;
  bool promotionUpdates = true;
  bool showAiAssistant = true;
  bool aiResponseSound = false;
  bool notificationSounds = true;

  ThemeMode get themeMode => ThemeController.instance.value;

  void setTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        ThemeController.instance.setLightMode();
      case ThemeMode.dark:
        ThemeController.instance.setDarkMode();
      case ThemeMode.system:
        ThemeController.instance.setSystemMode();
    }
    notifyListeners();
  }

  void update({
    bool? orderUpdates,
    bool? deliveryUpdates,
    bool? chatNotifications,
    bool? promotionUpdates,
    bool? showAiAssistant,
    bool? aiResponseSound,
    bool? notificationSounds,
  }) {
    this.orderUpdates = orderUpdates ?? this.orderUpdates;
    this.deliveryUpdates = deliveryUpdates ?? this.deliveryUpdates;
    this.chatNotifications = chatNotifications ?? this.chatNotifications;
    this.promotionUpdates = promotionUpdates ?? this.promotionUpdates;
    this.showAiAssistant = showAiAssistant ?? this.showAiAssistant;
    this.aiResponseSound = aiResponseSound ?? this.aiResponseSound;
    this.notificationSounds = notificationSounds ?? this.notificationSounds;
    notifyListeners();
  }
}

class BuyerSystemSettingsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onMyAccount;

  const BuyerSystemSettingsScreen({
    super.key,
    this.onBack,
    this.onMyAccount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BuyerSystemSettingsController.instance,
      builder: (BuildContext context, Widget? child) {
        final BuyerSystemSettingsController settings =
            BuyerSystemSettingsController.instance;
        final ColorScheme colors = Theme.of(context).colorScheme;

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
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
            children: [
              Text(
                'Fine-tune how LIKHAE looks, sounds, and keeps you informed.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: 'Notifications',
                subtitle: 'Choose the Buyer updates you want LIKHAE to send.',
                icon: Icons.notifications_none_rounded,
                child: Column(
                  children: [
                    _SettingSwitch(
                      title: 'Order Updates',
                      description: 'Order confirmation, processing, and status changes.',
                      value: settings.orderUpdates,
                      onChanged: (bool value) => settings.update(orderUpdates: value),
                    ),
                    _SettingSwitch(
                      title: 'Delivery Updates',
                      description: 'Pickup, sorting, rider, and delivery updates.',
                      value: settings.deliveryUpdates,
                      onChanged: (bool value) => settings.update(deliveryUpdates: value),
                    ),
                    _SettingSwitch(
                      title: 'Chat Notifications',
                      description: 'New messages from the existing Messages feature.',
                      value: settings.chatNotifications,
                      onChanged: (bool value) => settings.update(chatNotifications: value),
                    ),
                    _SettingSwitch(
                      title: 'Promotions & Vouchers',
                      description: 'Eligible voucher, discount, and promotion updates.',
                      value: settings.promotionUpdates,
                      onChanged: (bool value) => settings.update(promotionUpdates: value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SettingsCard(
                      title: 'LIKHAE AI Assistant',
                      subtitle: 'Control the optional Buyer AI assistant.',
                      icon: Icons.auto_awesome_rounded,
                      child: Column(
                        children: [
                          _SettingSwitch(
                            title: 'Show AI Assistant',
                            description: 'Show the floating AI chat head on Buyer pages.',
                            value: settings.showAiAssistant,
                            onChanged: (bool value) =>
                                settings.update(showAiAssistant: value),
                          ),
                          _SettingSwitch(
                            title: 'AI Response Sound',
                            description: 'Play a subtle sound after the assistant replies.',
                            value: settings.aiResponseSound,
                            onChanged: (bool value) =>
                                settings.update(aiResponseSound: value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SettingsCard(
                      title: 'Sounds',
                      subtitle: 'Manage LIKHAE interface sound cues.',
                      icon: Icons.music_note_rounded,
                      child: _SettingSwitch(
                        title: 'Notification Sounds',
                        description: 'Play sounds for supported LIKHAE notifications.',
                        value: settings.notificationSounds,
                        onChanged: (bool value) =>
                            settings.update(notificationSounds: value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SettingsCard(
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
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SettingsCard(
                      title: 'Language',
                      subtitle: 'More languages will appear when translations are ready.',
                      icon: Icons.translate_rounded,
                      child: DropdownButtonFormField<String>(
                        initialValue: 'en',
                        decoration: const InputDecoration(
                          labelText: 'Display language',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Changes apply immediately to this Buyer app.',
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved.')),
                      ),
                      child: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
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
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: child),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

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
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(
        description,
        style: TextStyle(color: colors.onSurface.withValues(alpha: 0.62), fontSize: 11),
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
