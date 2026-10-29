import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/ui/gradient_header.dart';
import '../home/widgets/home_offers_slider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final bool _booking = true;
  final bool _offers = true;
  final bool _safety = true; // locked always-on
  final bool _whatsapp = true;

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
            const HomeNotConnectedCard(
              icon: Icons.cloud_off_outlined,
              text: 'Not connected yet - built in Phase 7',
            ),
            const SizedBox(height: AbraSpacing.md),
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
                    onChanged: null, // saving needs the server: not connected yet
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
                    onChanged: null, // saving needs the server: not connected yet
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
                    onChanged: null, // saving needs the server: not connected yet
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
