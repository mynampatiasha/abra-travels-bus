import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../l10n/customer_strings.dart';

/// The home screen's "Offers" row (demo). Offers and coupons come from the server in Phase 3;
/// until then the title stays and one card says so, instead of showing made-up codes.
class HomeOffersSlider extends StatelessWidget {
  const HomeOffersSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final title = l10n.text(CustomerStrings.homeOffersTitle);
    final viewAll = l10n.text(CustomerStrings.homeOffersViewAll);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
              ),
              Tooltip(
                message: 'Not connected yet',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: AbraColors.divider),
                    foregroundColor: AbraColors.navy,
                  ),
                  onPressed: null,
                  child: Text(
                    viewAll,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.sm),
        const HomeNotConnectedCard(
          icon: Icons.local_offer_outlined,
          text: 'Not connected yet - built in Phase 3',
        ),
      ],
    );
  }
}

/// A light card that says a home section has no server data yet.
class HomeNotConnectedCard extends StatelessWidget {
  const HomeNotConnectedCard({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: const BoxDecoration(
        color: AbraColors.lightBlue,
        borderRadius: AbraRadius.medium,
      ),
      child: Row(
        children: [
          Icon(icon, color: AbraColors.deepBlue, size: 20),
          const SizedBox(width: AbraSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AbraColors.deepBlue),
            ),
          ),
        ],
      ),
    );
  }
}
