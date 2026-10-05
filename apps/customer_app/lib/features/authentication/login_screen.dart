import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import 'field_error.dart';
import 'otp_sign_in_controller.dart';
import 'seconds_ticker.dart';
import 'sign_in_problem.dart';

/// First step of sign-in: the mobile number. The backend sends a one-time
/// code (WhatsApp first, SMS as fallback) and the code screen follows. An
/// account is created on first sign-in, so there is no separate sign-up.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SecondsTicker<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  static const SignInCountry _country = SignInCountry.india;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(otpSignInControllerProvider.notifier)
        .requestCode(_phone.text, country: _country);
    if (!mounted || outcome != SendCodeOutcome.codeSent) return;
    // Keeps the location to return to after sign-in (`from`).
    context.go(
      GoRouterState.of(context).uri.replace(path: AppRoutes.otp).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final signIn = ref.watch(otpSignInControllerProvider);
    final sessionEnded =
        ref.watch(authStateProvider) ==
        const AuthSignedOut(SignedOutReason.sessionExpired);
    final waitSeconds = OtpSignInState.secondsUntil(
      signIn.blockedUntil,
      ref.read(signInClockProvider)(),
    );
    final problem = signIn.problem;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text(CustomerStrings.routeLoginTitle)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: l10n.text(CustomerStrings.languageChangeAction),
            onPressed: () => context.push(AppRoutes.language),
          ),
        ],
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (sessionEnded) ...<Widget>[
                _Notice(l10n.text(CustomerStrings.authSessionEndedNotice)),
                const SizedBox(height: AbraSpacing.lg),
              ],
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.authLoginHeading),
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                l10n.text(CustomerStrings.authLoginSubtitle),
                style: textTheme.bodyMedium?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              TextField(
                controller: _phone,
                enabled: !signIn.isSending,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[
                  AutofillHints.telephoneNumberNational,
                ],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.authPhoneLabel),
                  prefixText: '${_country.dialCode} ',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    semanticLabel: l10n.text(
                      CustomerStrings.authPhoneCountryCode,
                      <String, Object?>{'dialCode': _country.dialCode},
                    ),
                  ),
                  error: problem == null
                      ? null
                      : FieldError(signInProblemMessage(l10n, problem)),
                ),
                onChanged: (_) => ref
                    .read(otpSignInControllerProvider.notifier)
                    .clearProblem(),
                onSubmitted: (_) => waitSeconds > 0 ? null : _submit(),
              ),
              if (waitSeconds > 0) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                Text(
                  l10n.text(AbraStrings.commonRetryInSeconds, <String, Object?>{
                    'count': waitSeconds,
                  }),
                  style: textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AbraSpacing.xl),
              AbraButton(
                label: l10n.text(CustomerStrings.authSendCode),
                variant: AbraButtonVariant.callToAction,
                expand: true,
                isLoading: signIn.isSending,
                // Disabled while the server asked to wait; it enforces the
                // limit itself as well.
                onPressed: waitSeconds > 0 ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = AbraStatusColors.from(context).info;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.container,
          borderRadius: AbraRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.md),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(Icons.info_outline, color: tone.foreground),
              ),
              const SizedBox(width: AbraSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tone.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
