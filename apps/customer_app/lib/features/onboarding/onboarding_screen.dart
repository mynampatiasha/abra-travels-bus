import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import 'first_launch.dart';

/// One page of the tour.
class OnboardingStep {
  const OnboardingStep({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
    this.isComingSoon = false,
  });

  final String titleKey;
  final String bodyKey;
  final IconData icon;

  /// The feature is not in the app yet; the page says so.
  final bool isComingSoon;

  /// Discover → Search → Choose & Book → Track journey → Safety & Support.
  static const List<OnboardingStep> all = <OnboardingStep>[
    OnboardingStep(
      titleKey: CustomerStrings.onboardingDiscoverTitle,
      bodyKey: CustomerStrings.onboardingDiscoverBody,
      icon: Icons.explore_outlined,
    ),
    OnboardingStep(
      titleKey: CustomerStrings.onboardingSearchTitle,
      bodyKey: CustomerStrings.onboardingSearchBody,
      icon: Icons.search,
    ),
    OnboardingStep(
      titleKey: CustomerStrings.onboardingBookTitle,
      bodyKey: CustomerStrings.onboardingBookBody,
      icon: Icons.event_seat_outlined,
      isComingSoon: true,
    ),
    OnboardingStep(
      titleKey: CustomerStrings.onboardingTrackTitle,
      bodyKey: CustomerStrings.onboardingTrackBody,
      icon: Icons.near_me_outlined,
      isComingSoon: true,
    ),
    OnboardingStep(
      titleKey: CustomerStrings.onboardingSafetyTitle,
      bodyKey: CustomerStrings.onboardingSafetyBody,
      icon: Icons.health_and_safety_outlined,
      isComingSoon: true,
    ),
  ];
}

/// The first-launch tour: what the app offers, one idea per page. Swipe or
/// use the buttons; "Skip" on every page. Both ways lead to the language
/// step, then Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _steps = OnboardingStep.all;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Skip and "Get started" both lead to the language step, the last step
  /// of the first launch. The tour is not shown again.
  Future<void> _finish() async {
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    if (mounted) context.go(AppRoutes.languageFirstLaunch);
  }

  void _goTo(int index) {
    if (AbraMotion.isReduced(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: AbraDurations.normal,
        curve: AbraMotion.enter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final isLast = _index == _steps.length - 1;

    return Scaffold(
      backgroundColor: AbraColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.sm,
                    vertical: AbraSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (_index > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: l10n.text(CustomerStrings.onboardingBack),
                          onPressed: () => _goTo(_index - 1),
                        ),
                      const Spacer(),
                      const AbraLogo(size: 36),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        child: Text(l10n.text(CustomerStrings.welcomeSkip)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _steps.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) =>
                        _StepPage(step: _steps[index]),
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  label: l10n.text(
                    CustomerStrings.onboardingStep,
                    <String, Object?>{
                      'current': _index + 1,
                      'total': _steps.length,
                    },
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (var dot = 0; dot < _steps.length; dot++)
                          AnimatedContainer(
                            duration: AbraMotion.isReduced(context)
                                ? Duration.zero
                                : AbraDurations.normal,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AbraSpacing.xs,
                            ),
                            height: 8,
                            width: dot == _index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: dot == _index
                                  ? AbraColors.blue
                                  : AbraColors.navyContainer,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(AbraRadius.pill),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AbraSpacing.xl),
                  child: AbraButton(
                    label: l10n.text(
                      isLast
                          ? CustomerStrings.onboardingDone
                          : CustomerStrings.onboardingNext,
                    ),
                    variant: AbraButtonVariant.callToAction,
                    expand: true,
                    onPressed: isLast ? _finish : () => _goTo(_index + 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xl),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AbraSpacing.lg),
          // The picture of the step: its symbol on the brand colours.
          ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: 1.5,
              child: AbraBrandSurface(
                borderRadius: AbraRadius.extraLarge,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0x24FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AbraSpacing.xl),
                      child: Icon(step.icon, size: 64, color: AbraColors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.xxl),
          if (step.isComingSoon) ...<Widget>[
            AbraStatusBadge(
              label: l10n.text(CustomerStrings.onboardingComingSoon),
              tone: AbraStatusTone.info,
              icon: Icons.schedule,
            ),
            const SizedBox(height: AbraSpacing.md),
          ],
          Semantics(
            header: true,
            child: Text(
              l10n.text(step.titleKey),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          Text(
            l10n.text(step.bodyKey),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
        ],
      ),
    );
  }
}
