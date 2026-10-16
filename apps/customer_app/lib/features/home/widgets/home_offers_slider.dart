import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';

class HomeOffersSlider extends StatelessWidget {
  const HomeOffersSlider({super.key});

  static const _offers = <(String code, String desc)>[
    ('ABRA100', 'Rs 100 off your first booking'),
    ('WEEKEND15', '15% off up to Rs 250, Friday to Sunday'),
    ('UPIFEST', 'Rs 75 cashback with UPI'),
    ('WOMEN10', '10% off for women travellers'),
  ];

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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AbraColors.navy,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: AbraColors.divider),
                  foregroundColor: AbraColors.navy,
                ),
                onPressed: () => context.push(AppRoutes.offers),
                child: Text(
                  viewAll,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.sm),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
            itemCount: _offers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final o = _offers[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: o.$1));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${o.$1} copied to clipboard!'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: 210,
                  decoration: BoxDecoration(
                    color: AbraColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AbraColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        o.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AbraColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        o.$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
