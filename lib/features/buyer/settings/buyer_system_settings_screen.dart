import 'package:flutter/material.dart';
import '../../../shared/widgets/shop_ui.dart';
import 'buyer_system_settings_controller.dart';

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
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                24,
              ),
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
                _buildAiAndSounds(settings),
                const SizedBox(height: 14),
                _buildAppearanceAndLanguage(settings),
                const SizedBox(height: 14),
                _buildSaveBar(context, colors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiAndSounds(
    BuyerSystemSettingsController settings,
  ) {
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
      child: _SettingSwitch(
        title: 'Notification Sounds',
        description: 'Play sounds for supported LIKHAE notifications.',
        value: settings.notificationSounds,
        onChanged: (bool value) => settings.update(notificationSounds: value),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              aiCard,
              const SizedBox(height: 14),
              soundsCard,
            ],
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

  Widget _buildAppearanceAndLanguage(
    BuyerSystemSettingsController settings,
  ) {
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

  Widget _buildSaveBar(BuildContext context, ColorScheme colors) {
    final Widget saveButton = FilledButton(
      onPressed: () async {
        try {
          await BuyerSystemSettingsController.instance.save();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved on this device.')),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save settings. Try again.')),
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
                  'Changes apply immediately to this Buyer app.',
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
                  'Changes apply immediately to this Buyer app.',
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
