import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../features/authentication/gate/session_events.dart';
import '../features/authentication/gate/sign_in_intent.dart';
import '../l10n/customer_strings.dart';
import '../routing/app_routes.dart';
import '../routing/customer_router.dart';
import '../routing/router_location.dart';
import 'providers.dart';

/// Root widget: the Abra theme, the selected language and the router. Also
/// where two app-wide sign-in events are handled: a session the server
/// ended (a notice over the current screen) and, after a restart, an action
/// that was waiting for sign-in (taken up again).
class CustomerApp extends ConsumerStatefulWidget {
  const CustomerApp({super.key});

  @override
  ConsumerState<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends ConsumerState<CustomerApp>
    with WidgetsBindingObserver {
  GoRouter? _router;
  OverlayEntry? _welcome;
  Timer? _welcomeTimer;

  /// An action that waited for sign-in when the app was last closed.
  SignInIntent? _toResume;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Starts the check of the stored session.
    ref.read(startupControllerProvider);
    _toResume = ref.read(pendingSignInIntentProvider.notifier).fresh;
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _welcome?.remove();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _attach(GoRouter router) {
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onLocationChanged);
    _router = router..routerDelegate.addListener(_onLocationChanged);
  }

  Uri? get _location {
    final router = _router;
    return router == null ? null : topLocationOf(router);
  }

  BuildContext? get _navigatorContext =>
      _router?.routerDelegate.navigatorKey.currentContext;

  /// Takes up [_toResume] once the app has arrived at its screen.
  void _onLocationChanged() {
    final intent = _toResume;
    final location = _location;
    if (intent == null || location == null) return;
    if (location.path == AppRoutes.splash) return;
    _toResume = null;
    if (location.path != Uri.parse(intent.returnLocation).path) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorContext;
      if (context != null && context.mounted) {
        resumePendingSignIn(context, intent);
      }
    });
  }

  void _onAuthChanged(AuthState? previous, AuthState next) {
    if (previous is AuthSignedOut && next is AuthSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ref.read(authStateProvider) is! AuthSignedIn) return;
        final navigator = _router?.routerDelegate.navigatorKey.currentState;
        final overlay = navigator?.overlay;
        if (overlay == null) return;
        _welcomeTimer?.cancel();
        _welcome?.remove();
        _welcome = OverlayEntry(builder: (_) => const _SignInWelcome());
        overlay.insert(_welcome!);
        _welcomeTimer = Timer(const Duration(seconds: 2), () {
          _welcome?.remove();
          _welcome = null;
        });
      });
    }
    final ended =
        previous is AuthSignedIn &&
        next == const AuthSignedOut(SignedOutReason.sessionExpired);
    final context = _navigatorContext;
    final location = _location;
    if (!ended || context == null || location == null) return;
    showSessionEndedSheet(context, location: location.toString());
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (locales == null) return;
    ref
        .read(appDependenciesProvider)
        .localeController
        .updateDeviceLocales(locales);
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = ref.watch(appDependenciesProvider);
    final localeController = dependencies.localeController;
    final router = ref.watch(customerRouterProvider);
    _attach(router);
    ref.listen(authStateProvider, _onAuthChanged);

    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: AbraTheme.light(),
        locale: localeController.locale,
        supportedLocales: localeController.config.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<Object?>>[
          AbraLocalizationsDelegate(
            config: localeController.config,
            source: dependencies.translations,
            onMissingKey: (key, locale) => dependencies.logger.warning(
              'Missing translation',
              context: <String, Object?>{
                'key': key,
                'locale': LocaleTags.of(locale),
              },
            ),
          ),
          ...GlobalMaterialLocalizations.delegates,
        ],
        onGenerateTitle: (context) =>
            AbraLocalizations.of(context).text(CustomerStrings.appName),
        builder: (context, child) => child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _SignInWelcome extends StatelessWidget {
  const _SignInWelcome();

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.18),
        child: AbsorbPointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.9 + value * 0.1,
                    child: child,
                  ),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x240B3556),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFFE4F6EE),
                          child: Icon(
                            Icons.check_rounded,
                            size: 44,
                            color: Color(0xFF14865C),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.text(CustomerStrings.authWelcomeTitle),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.text(CustomerStrings.authWelcomeMessage),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF536679)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
