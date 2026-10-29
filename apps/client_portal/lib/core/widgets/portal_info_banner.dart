import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

enum PortalBannerTone { info, success, warning, danger }

/// Inline banner matching the demo .hb class.
class PortalInfoBanner extends StatelessWidget {
  const PortalInfoBanner({
    required this.message,
    this.tone = PortalBannerTone.info,
    this.icon,
    super.key,
  });

  final String message;
  final PortalBannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PortalBannerTone.success => (AbraColors.tealContainer, AbraColors.tealDark),
      PortalBannerTone.warning => (AbraColors.orangeContainer, AbraColors.orangeDark),
      PortalBannerTone.danger  => (AbraColors.dangerContainer, AbraColors.danger),
      PortalBannerTone.info    => (AbraColors.lightBlue, AbraColors.deepBlue),
    };
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AbraRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, color: fg, size: 18),
          const SizedBox(width: AbraSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
