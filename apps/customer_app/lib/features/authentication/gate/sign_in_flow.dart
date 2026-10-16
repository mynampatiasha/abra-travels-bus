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

import '../../../app/providers.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../field_error.dart';
import '../otp_sign_in_controller.dart';
import '../seconds_ticker.dart';
import '../sign_in_problem.dart';

/// The two steps of sign-in.
enum SignInStepView { phone, code }

/// Sign-in with a mobile number and a one-time code, as one flow with two
/// steps. Used inside the sign-in sheet (the gate) and on the `/login` page
/// (links). The steps are not routes: Back on the code step returns to the
/// number, Back on the number step leaves the flow.
///
/// [builder] lays the current step out (a sheet scaffold or a page);
/// [onBackToPhone] is handed to it for its back button.
class SignInFlow extends ConsumerStatefulWidget {
  const SignInFlow({required this.builder, super.key});

  final Widget Function(
    BuildContext context,
    SignInStepView step,
    Widget content,
    VoidCallback onBackToPhone,
  )
  builder;

  @override
  ConsumerState<SignInFlow> createState() => _SignInFlowState();
}

class _SignInFlowState extends ConsumerState<SignInFlow> {
  SignInStepView _step = SignInStepView.phone;

  void _toPhone() {
    ref.read(otpSignInControllerProvider.notifier).changeNumber();
    setState(() => _step = SignInStepView.phone);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_step) {
      SignInStepView.phone => PhoneStep(
        key: const ValueKey<String>('sign-in-phone'),
        onCodeSent: () => setState(() => _step = SignInStepView.code),
      ),
      SignInStepView.code => CodeStep(
        key: const ValueKey<String>('sign-in-code'),
        onChangeNumber: _toPhone,
      ),
    };
    return PopScope(
      // Back on the code step goes to the number step, not out of sign-in.
      canPop: _step == SignInStepView.phone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toPhone();
      },
      child: widget.builder(
        context,
        _step,
        AnimatedSwitcher(
          duration: AbraMotion.isReduced(context)
              ? Duration.zero
              : AbraDurations.normal,
          child: content,
        ),
        _toPhone,
      ),
    );
  }
}

/// First step: the mobile number. The backend sends a one-time code
/// (WhatsApp first, SMS as fallback). An account is created on first
/// sign-in, so there is no separate sign-up.
class PhoneStep extends ConsumerStatefulWidget {
  const PhoneStep({required this.onCodeSent, super.key});

  final VoidCallback onCodeSent;

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep>
    with SecondsTicker<PhoneStep> {
  late final TextEditingController _phone;
  bool _socialTerms = true;
  static const SignInCountry _country = SignInCountry.india;

  @override
  void initState() {
    super.initState();
    // Coming back from the code step keeps the number that was used.
    final phone = ref.read(otpSignInControllerProvider).phone;
    _phone = TextEditingController(
      text: phone != null && phone.startsWith(_country.dialCode)
          ? phone.substring(_country.dialCode.length)
          : '',
    );
  }

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
    widget.onCodeSent();
  }

  void _showSocialDemoSheet(BuildContext context, {required bool isApple}) {
    final providerName = isApple ? 'Apple' : 'Google';
    const demoUsers = [
      UserProfile(
        id: 'c1',
        name: 'Ramesh Kumar',
        email: 'ramesh.kumar@example.com',
        phone: '+919876543210',
        userType: UserType.customer,
        status: UserStatus.active,
        preferredLanguage: 'en',
        emailVerified: true,
        phoneVerified: true,
        hasPassword: true,
        mfaEnabled: false,
      ),
      UserProfile(
        id: 'c2',
        name: 'Priya Sharma',
        email: 'priya.sharma@example.com',
        phone: '+919876543211',
        userType: UserType.customer,
        status: UserStatus.active,
        preferredLanguage: 'te',
        emailVerified: true,
        phoneVerified: true,
        hasPassword: true,
        mfaEnabled: false,
      ),
      UserProfile(
        id: 'c3',
        name: 'Rahul Verma',
        email: 'rahul.verma@example.com',
        phone: '+919876543212',
        userType: UserType.customer,
        status: UserStatus.active,
        preferredLanguage: 'hi',
        emailVerified: true,
        phoneVerified: true,
        hasPassword: true,
        mfaEnabled: false,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    isApple ? Icons.apple : Icons.account_circle,
                    color: isApple ? Colors.black : const Color(0xFF4285F4),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with $providerName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'In the real app this opens the OAuth screen. For the demo, choose an account:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final user in demoUsers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref.read(authStateProvider.notifier).signInDemo(user);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: Text(
                              user.name?[0] ?? 'U',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  user.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I agree to the terms and privacy policy'),
          value: _socialTerms,
          onChanged: signIn.isBusy
              ? null
              : (value) => setState(() => _socialTerms = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: !signIn.isBusy
                    ? () => _showSocialDemoSheet(context, isApple: false)
                    : null,
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: !signIn.isBusy
                    ? () => _showSocialDemoSheet(context, isApple: true)
                    : null,
                child: const Icon(Icons.apple, size: 26, color: Colors.black),
              ),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),
        if (sessionEnded) ...<Widget>[
          SignInNotice(l10n.text(CustomerStrings.authSessionEndedNotice)),
          const SizedBox(height: AbraSpacing.lg),
        ],
        Semantics(
          header: true,
          child: Text(
            l10n.text(CustomerStrings.authLoginHeading),
            style: textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AbraSpacing.xs),
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
          autofillHints: const <String>[AutofillHints.telephoneNumberNational],
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
          onChanged: (_) =>
              ref.read(otpSignInControllerProvider.notifier).clearProblem(),
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
          // Disabled while the server asked to wait; it enforces the limit
          // itself as well.
          onPressed: waitSeconds > 0 ? null : _submit,
        ),
        const SizedBox(height: AbraSpacing.lg),
        const _TermsLinks(),
      ],
    );
  }
}

/// Second step: the one-time code. The code is typed here and sent to the
/// backend; it is never stored, logged or kept after sending.
class CodeStep extends ConsumerStatefulWidget {
  const CodeStep({required this.onChangeNumber, super.key});

  final VoidCallback onChangeNumber;

  @override
  ConsumerState<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<CodeStep>
    with SecondsTicker<CodeStep> {
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
      // Signed in a moment ago (the state was reset): the flow is closing.
      return const AbraLoadingView();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.text(CustomerStrings.authOtpHeading),
            style: textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AbraSpacing.xs),
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
              style: textTheme.bodySmall?.copyWith(color: AbraColors.tealDark),
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
              l10n.text(CustomerStrings.authOtpResendIn, <String, Object?>{
                'count': resendSeconds,
              }),
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
          onPressed: signIn.isBusy ? null : widget.onChangeNumber,
        ),
      ],
    );
  }
}

/// "By continuing you agree to …" with links to the terms and the privacy
/// policy. The pages open above the sign-in sheet; Back returns to it.
class _TermsLinks extends StatelessWidget {
  const _TermsLinks();

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Text(
          l10n.text(CustomerStrings.authTermsNote),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () => context.push(AppRoutes.terms),
              child: Text(l10n.text(CustomerStrings.infoTermsTitle)),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.privacy),
              child: Text(l10n.text(CustomerStrings.infoPrivacyTitle)),
            ),
          ],
        ),
      ],
    );
  }
}

/// An information line above the sign-in form (for example "Your session
/// has ended").
class SignInNotice extends StatelessWidget {
  const SignInNotice(this.message, {super.key});

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
