import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/app_config.dart';
import '../../../features/rider/profile/rider_profile_screen.dart';
import '../../../services/notification_sound_service.dart';
import '../../../services/rider_mobile_service.dart';
import 'buyer_system_settings_controller.dart';

class BuyerSystemSettingsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onMyAccount;
  final bool riderMode;

  const BuyerSystemSettingsScreen({
    super.key,
    this.onBack,
    this.onMyAccount,
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
          await BuyerSystemSettingsController.instance.save();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved on this device.')),
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
            savedStatus
                ? 'You are online and available for assignments.'
                : 'You are offline and will not receive new assignments.',
          ),
        ),
      );
      if (savedStatus) unawaited(_syncAvailabilityLocation());
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
    return _SettingsCard(
      title: 'Rider Availability',
      subtitle: 'Choose whether dispatch can assign new deliveries to you.',
      icon: Icons.wifi_tethering_rounded,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                'Availability controls are for local motorcycle and tricycle riders.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
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
                            ? const Color(0xFF27856E)
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
            onPressed: () => unawaited(
              NotificationSoundService.preview(sound.key),
            ),
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
