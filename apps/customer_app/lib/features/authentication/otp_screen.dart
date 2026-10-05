import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_validation/shared_validation.dart';

import '../../app/providers.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import 'field_error.dart';
import 'otp_sign_in_controller.dart';
import 'seconds_ticker.dart';
import 'sign_in_problem.dart';

/// Second step of sign-in: the one-time code. The code is typed here and
/// sent to the backend; it is never stored, logged or kept after sending.
/// When the backend accepts it the session starts and the router moves on.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SecondsTicker<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  OtpSignInController get _controller =>
      ref.read(otpSignInControllerProvider.notifier);

  String _loginLocation() =>
      GoRouterState.of(context).uri.replace(path: AppRoutes.login).toString();

  Future<void> _verify() async {
    final code = _code.text;
    // The code leaves the field as soon as it is submitted.
    _code.clear();
    final signedIn = await _controller.verify(code);
    if (!mounted || signedIn) return;
    _codeFocus.requestFocus();
  }

  Future<void> _resend() async {
    _code.clear();
    await _controller.resend();
    if (mounted) _codeFocus.requestFocus();
  }

  void _changeNumber() {
    _controller.changeNumber();
    context.go(_loginLocation());
  }

  String _sentMessage(AbraLocalizations l10n, OtpDispatch dispatch, String to) {
    final key = switch (dispatch.channel) {
      OtpDeliveryChannel.whatsApp => CustomerStrings.authOtpSentWhatsApp,
      OtpDeliveryChannel.sms => CustomerStrings.authOtpSentSms,
      OtpDeliveryChannel.unknown => CustomerStrings.authOtpSent,
    };
    return l10n.text(key, <String, Object?>{
      'length': dispatch.codeLength,
      'phone': PhoneNumbers.mask(to),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final signIn = ref.watch(otpSignInControllerProvider);
    final phone = signIn.phone;
    final dispatch = signIn.dispatch;

    if (phone == null || dispatch == null) {
      // Opened without a pending code (for example by a link, or after the
      // app was restarted): go back to the number step. After a successful
      // sign-in the router is already leaving this screen.
      if (ref.watch(authStateProvider) is! AuthSignedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(_loginLocation());
        });
      }
      return const Scaffold(body: AbraLoadingView());
    }

    final now = ref.read(signInClockProvider)();
    final resendSeconds = OtpSignInState.secondsUntil(
      signIn.resendAvailableAt,
      now,
    );
    final isExpired = OtpSignInState.secondsUntil(signIn.expiresAt, now) == 0;
    final problem =
        signIn.problem ?? (isExpired ? SignInProblem.codeExpired : null);
    final isComplete = _code.text.length == dispatch.codeLength;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text(CustomerStrings.routeOtpTitle))),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.authOtpHeading),
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                _sentMessage(l10n, dispatch, phone),
                style: textTheme.bodyMedium?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              TextField(
                controller: _code,
                focusNode: _codeFocus,
                autofocus: true,
                enabled: !signIn.isVerifying,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                // Pasted text keeps its digits only, so "123 456" works.
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(dispatch.codeLength),
                ],
                enableSuggestions: false,
                autocorrect: false,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  letterSpacing: AbraSpacing.sm,
                ),
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.authOtpCodeLabel),
                  error: problem == null
                      ? null
                      : FieldError(signInProblemMessage(l10n, problem)),
                ),
                onChanged: (value) {
                  _controller.clearProblem();
                  setState(() {});
                  if (value.length == dispatch.codeLength && !isExpired) {
                    _verify();
                  }
                },
                onSubmitted: (_) => isComplete && !isExpired ? _verify() : null,
              ),
              if (signIn.resentNotice) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.text(CustomerStrings.authOtpResent),
                    style: textTheme.bodySmall?.copyWith(
                      color: AbraColors.tealDark,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AbraSpacing.xl),
              AbraButton(
                label: l10n.text(CustomerStrings.authOtpVerify),
                variant: AbraButtonVariant.callToAction,
                expand: true,
                isLoading: signIn.isVerifying,
                onPressed: isComplete && !isExpired ? _verify : null,
              ),
              const SizedBox(height: AbraSpacing.lg),
              if (resendSeconds > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AbraSpacing.md),
                  child: Text(
                    l10n.text(
                      CustomerStrings.authOtpResendIn,
                      <String, Object?>{'count': resendSeconds},
                    ),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                )
              else
                AbraButton(
                  label: l10n.text(CustomerStrings.authOtpResend),
                  variant: AbraButtonVariant.secondary,
                  expand: true,
                  isLoading: signIn.isSending,
                  onPressed: signIn.isVerifying ? null : _resend,
                ),
              const SizedBox(height: AbraSpacing.sm),
              AbraButton(
                label: l10n.text(CustomerStrings.authOtpChangeNumber),
                variant: AbraButtonVariant.text,
                expand: true,
                onPressed: signIn.isBusy ? null : _changeNumber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
