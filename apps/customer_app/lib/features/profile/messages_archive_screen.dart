import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/ui/gradient_header.dart';

class MessagesArchiveScreen extends StatelessWidget {
  const MessagesArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = <(String title, String body, String channel, String time)>[
      (
        'Booking Confirmed (PNR: ABRM7412B)',
        'Your ticket for Bengaluru to Hyderabad on 20 Oct 2026 has been issued. Bus leaves at 21:00 from Madiwala.',
        'WhatsApp & SMS',
        'Today, 10:30 AM',
      ),
      (
        'Seat Hold Initiated',
        'Seats 4A, 4B are held for 10 minutes. Please complete payment before 10:40 AM.',
        'SMS',
        'Today, 10:20 AM',
      ),
      (
        'Refund Credited (UTR92847192)',
        'Refund of ₹1,850 for booking ABRK2941A has been credited to your UPI ID.',
        'WhatsApp',
        'Yesterday, 4:15 PM',
      ),
      (
        'Welcome to Abra Travels!',
        'Thank you for signing up. Use promo code ABRA100 to get ₹100 off your first booking.',
        'WhatsApp',
        '14 Oct 2026',
      ),
    ];

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Messages sent to me',
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth * 1.3,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.md,
            vertical: AbraSpacing.lg,
          ),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: AbraSpacing.sm),
          itemBuilder: (context, index) {
            final m = messages[index];
            return AbraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AbraSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AbraColors.lightBlue,
                          borderRadius: AbraRadius.small,
                        ),
                        child: Text(
                          m.$3,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AbraColors.blueDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        m.$4,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    m.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AbraColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.xs),
                  Text(
                    m.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AbraColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
