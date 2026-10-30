import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/ui/gradient_header.dart';
import 'profile_repository.dart';

/// For each kind of message, which of WhatsApp, email and push the customer wants. A change is
/// saved at once; if the server cannot be reached the switch goes back and says so.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Notification settings'),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth * 1.3,
        child: AsyncValueView<NotificationSettings>(
          value: ref.watch(notificationSettingsProvider),
          onRetry: () => ref.invalidate(notificationSettingsProvider),
          data: (context, settings) => _SettingsList(initial: settings),
        ),
      ),
    );
  }
}

const _topicTitles = <String, (String, String)>{
  'bookings': (
    'Bookings and refunds',
    'Tickets, payments, cancellations and refunds',
  ),
  'trips': (
    'Trip updates',
    'Delays and boarding reminders',
  ),
  'offers': (
    'Offers and promotions',
    'Discounts, coupon codes and new routes',
  ),
};

class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({required this.initial});

  final NotificationSettings initial;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList> {
  late NotificationSettings _settings = widget.initial;
  bool _saving = false;

  Future<void> _change(String topic, ChannelChoices choices) async {
    final before = _settings;
    final next = <String, ChannelChoices>{..._settings, topic: choices};
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      final saved = await ref.read(profileRepositoryProvider).saveNotificationSettings(next);
      if (mounted) setState(() => _settings = saved);
    } on ProfileProblem catch (problem) {
      if (!mounted) return;
      setState(() => _settings = before);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    activeThumbColor: AbraColors.teal,
    dense: true,
    title: Text(label),
    value: value,
    onChanged: _saving ? null : onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.md,
        vertical: AbraSpacing.lg,
      ),
      children: <Widget>[
        for (final topic in notificationTopics)
          if (_settings[topic] case final choices?) ...<Widget>[
            AbraCard(
              padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AbraSpacing.lg,
                      AbraSpacing.sm,
                      AbraSpacing.lg,
                      AbraSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _topicTitles[topic]!.$1,
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          _topicTitles[topic]!.$2,
                          style: textTheme.bodySmall?.copyWith(
                            color: AbraColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _switch(
                    'WhatsApp',
                    choices.whatsapp,
                    (value) => _change(topic, choices.copyWith(whatsapp: value)),
                  ),
                  _switch(
                    'Email',
                    choices.email,
                    (value) => _change(topic, choices.copyWith(email: value)),
                  ),
                  _switch(
                    'Push notification',
                    choices.push,
                    (value) => _change(topic, choices.copyWith(push: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
          ],
        AbraCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.shield_outlined, color: AbraColors.teal),
              const SizedBox(width: AbraSpacing.md),
              Expanded(
                child: Text(
                  'Safety alerts are always on while you travel and cannot be turned off. '
                  'Everything is also kept in your notifications list in the app.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
