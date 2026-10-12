import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../l10n/customer_strings.dart';

/// True once the splash screen has played. The router leaves the splash
/// screen then, without waiting for the stored session to be checked (that
/// continues in the background), except for a location that needs an
/// account.
final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;
}

/// First screen: the logo on the brand gradient, at most [maxDuration]
/// (none when the device asks for reduced motion). Stays only when the app
/// was opened at a personal location and the session check has not
/// finished; if the server cannot be reached it offers a retry.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const maxDuration = Duration(milliseconds: 900);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: SplashScreen.maxDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    if (AbraMotion.isReduced(context)) {
      _entrance.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _done());
    } else {
      _entrance.forward().whenComplete(_done);
    }
  }

  void _done() {
    if (mounted) ref.read(splashDoneProvider.notifier).markDone();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final startup = ref.watch(startupControllerProvider);
    final isWaiting = ref.watch(splashDoneProvider);
    final failure = startup.failure;

    if (isWaiting && failure != null) {
      return Scaffold(
        body: AbraPageContainer(
          child: AbraFailureView(
            failure: failure,
            onRetry: ref
                .read(startupControllerProvider.notifier)
                .restoreSession,
          ),
        ),
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final fade = CurvedAnimation(parent: _entrance, curve: AbraMotion.enter);
    final scale = Tween<double>(begin: 0.86, end: 1).animate(fade);
    return Scaffold(
      body: AbraBrandSurface(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AbraResponsive.pagePadding(context),
              child: FadeTransition(
                opacity: fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ScaleTransition(
                      scale: scale,
                      child: const AbraLogo(size: 96),
                    ),
                    const SizedBox(height: AbraSpacing.xl),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.text(CustomerStrings.appName),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          color: AbraColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.sm),
                    Text(
                      l10n.text(CustomerStrings.splashTagline),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AbraColors.white,
                      ),
                    ),
                    // Only when the app waits here for the session check.
                    if (isWaiting) ...<Widget>[
                      const SizedBox(height: AbraSpacing.xxxl),
                      AbraLoadingView(
                        onDark: true,
                        label: l10n.text(
                          CustomerStrings.startupCheckingSession,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
