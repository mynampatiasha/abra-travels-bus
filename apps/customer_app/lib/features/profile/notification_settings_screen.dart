import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/ui/gradient_header.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _booking = true;
  bool _offers = true;
  final bool _safety = true; // locked always-on
  bool _whatsapp = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Notification settings',
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth * 1.3,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.md,
            vertical: AbraSpacing.lg,
          ),
          children: [
            AbraCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AbraColors.teal,
                    title: const Text(
                      'Booking and trip updates',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Tickets, delays, boarding reminders and refunds',
                      style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                    ),
                    value: _booking,
                    onChanged: (val) => setState(() => _booking = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeThumbColor: AbraColors.teal,
                    title: const Text(
                      'Offers and promotions',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Discounts, coupon codes and new routes',
                      style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                    ),
                    value: _offers,
                    onChanged: (val) => setState(() => _offers = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeThumbColor: AbraColors.teal,
                    title: const Text(
                      'Safety alerts',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Always on while you travel (cannot be turned off)',
                      style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                    ),
                    value: _safety,
                    onChanged: null, // locked switch matching demo
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeThumbColor: AbraColors.teal,
                    title: const Text(
                      'WhatsApp messages',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Receive ticket PDF, boarding details and live link on WhatsApp',
                      style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                    ),
                    value: _whatsapp,
                    onChanged: (val) => setState(() => _whatsapp = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
