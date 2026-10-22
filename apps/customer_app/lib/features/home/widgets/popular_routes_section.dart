import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../l10n/customer_strings.dart';
import 'home_offers_slider.dart';

/// The home screen's "Popular routes" (demo). Admin manages popular routes in Phase 7; until then
/// the title stays and one card says so, instead of a fixed list of cities.
class PopularRoutesSection extends StatelessWidget {
  const PopularRoutesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final title = l10n.text(CustomerStrings.homePopularRoutesTitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AbraColors.navy,
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.sm),
        const HomeNotConnectedCard(
          icon: Icons.alt_route,
          text: 'Not connected yet - built in Phase 7',
        ),
      ],
    );
  }
}
