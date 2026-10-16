import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../../discovery/controllers/search_form_controller.dart';
import '../../discovery/controllers/travel_dates.dart';
import '../../discovery/models/discovery_models.dart';

class PopularRoutesSection extends ConsumerWidget {
  const PopularRoutesSection({super.key});

  static const _routes = <(String fromId, String fromName, String toId, String toName)>[
    ('CT2', 'Bengaluru', 'CT1', 'Hyderabad'),
    ('CT1', 'Hyderabad', 'CT2', 'Bengaluru'),
    ('CT2', 'Bengaluru', 'CT3', 'Chennai'),
    ('CT3', 'Chennai', 'CT6', 'Coimbatore'),
    ('CT4', 'Vijayawada', 'CT5', 'Visakhapatnam'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final itemWidth = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

            Widget routeCard((String fromId, String fromName, String toId, String toName) r) {
              return SizedBox(
                width: itemWidth,
                child: Container(
                  margin: const EdgeInsets.only(bottom: AbraSpacing.xs),
                  child: Material(
                    color: AbraColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AbraColors.divider),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final now = ref.read(discoveryClockProvider)();
                        final today = TravelDates.today(now);
                        final controller = ref.read(searchFormControllerProvider.notifier);
                        controller.setFrom(City(id: r.$1, name: r.$2, state: ''));
                        controller.setTo(City(id: r.$3, name: r.$4, state: ''));
                        context.push(
                          AppRoutes.searchResultsFor(
                            fromId: r.$1,
                            fromName: r.$2,
                            toId: r.$3,
                            toName: r.$4,
                            date: TravelDates.format(today),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AbraSpacing.md,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AbraColors.blue,
                            ),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(
                              child: Text(
                                '${r.$2} → ${r.$4}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AbraColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AbraColors.textDisabled,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (isWide) {
              return Wrap(
                spacing: 12,
                runSpacing: 0,
                children: _routes.map(routeCard).toList(),
              );
            }

            return Column(
              children: _routes.map(routeCard).toList(),
            );
          },
        ),
      ],
    );
  }
}
