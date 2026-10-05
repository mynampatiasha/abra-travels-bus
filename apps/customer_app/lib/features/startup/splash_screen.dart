import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../l10n/customer_strings.dart';

/// First screen: shown while the stored session is checked. The router
/// leaves it as soon as the result is known. If the server cannot be
/// reached the session is kept and the user can try again.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final startup = ref.watch(startupControllerProvider);
    final failure = startup.failure;

    return Scaffold(
      body: AbraPageContainer(
        child: failure != null
            ? AbraFailureView(
                failure: failure,
                onRetry: ref
                    .read(startupControllerProvider.notifier)
                    .restoreSession,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.text(CustomerStrings.appName),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AbraColors.navy),
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.xxl),
                  AbraLoadingView(
                    label: l10n.text(CustomerStrings.startupCheckingSession),
                  ),
                ],
              ),
      ),
    );
  }
}
