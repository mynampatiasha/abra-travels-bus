import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/brand_photo.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import 'first_launch.dart';

/// The first thing a new customer sees: the Abra Travels photograph, with
/// "Get started" (the tour) and "Skip" (straight to Home). Shown once.
///
/// On a phone the photograph fills the screen. On a wide screen a portrait
/// photograph cannot, so it takes one side and the words and buttons the
/// other.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const double _wideFrom = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);

    Future<void> skip() async {
      await ref.read(welcomeSeenProvider.notifier).markSeen();
      if (context.mounted) context.go(AppRoutes.home);
    }

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AbraButton(
          label: l10n.text(CustomerStrings.welcomeGetStarted),
          icon: Icons.arrow_forward,
          variant: AbraButtonVariant.callToAction,
          expand: true,
          onPressed: () => context.go(AppRoutes.onboarding),
        ),
        const SizedBox(height: AbraSpacing.sm),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AbraColors.white),
          onPressed: skip,
          child: Text(l10n.text(CustomerStrings.welcomeSkip)),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AbraColors.navy,
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _wideFrom
            ? _Wide(actions: actions)
            : _Narrow(actions: actions),
      ),
    );
  }
}

/// Phone and tablet: the photograph edge to edge, the buttons on a dark
/// fade at the bottom.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.actions});

  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          image: true,
          label: l10n.text(CustomerStrings.welcomeImageLabel),
          // Slightly above centre: the logo and the bus both stay in view
          // on short and on tall screens.
          child: const BrandPhoto(alignment: Alignment(0, -0.1)),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 280,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00071E3D), Color(0xF2071E3D)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AbraSizes.maxFormWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AbraSpacing.xl,
                  0,
                  AbraSpacing.xl,
                  AbraSpacing.lg,
                ),
                child: AbraEntrance(child: actions),
              ),
            ),
          ),
        ),
        // The product name for screen readers: it is part of the picture.
        Semantics(
          header: true,
          label: l10n.text(CustomerStrings.welcomeHeading),
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Desktop and landscape tablets: photograph on one side, welcome on the
/// other.
class _Wide extends StatelessWidget {
  const _Wide({required this.actions});

  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Semantics(
            image: true,
            label: l10n.text(CustomerStrings.welcomeImageLabel),
            child: const BrandPhoto(alignment: Alignment(0, -0.1)),
          ),
        ),
        Expanded(
          flex: 4,
          child: AbraBrandSurface(
            gradient: AbraGradients.brandDeep,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AbraSpacing.xxxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AbraEntrance(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.text(CustomerStrings.welcomeHeading),
                              style: textTheme.displaySmall?.copyWith(
                                color: AbraColors.white,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: AbraSpacing.md),
                          Text(
                            l10n.text(CustomerStrings.welcomeTagline),
                            style: textTheme.titleMedium?.copyWith(
                              color: AbraColors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: AbraSpacing.xxxl),
                          actions,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
