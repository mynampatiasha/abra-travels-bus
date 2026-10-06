import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../l10n/admin_strings.dart';
import 'sign_in_controller.dart';

/// Shown while the stored session is checked; offers a retry when the
/// server cannot be reached.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(startupProvider);
    return Scaffold(
      body: failure == null
          ? const AbraLoadingView()
          : AbraFailureView(
              failure: failure,
              onRetry: ref.read(startupProvider.notifier).restore,
            ),
    );
  }
}

/// Staff sign-in: email and password, then the two-step verification code
/// when the account uses it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _useRecovery = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  SignInController get _controller =>
      ref.read(signInControllerProvider.notifier);

  Future<void> _submitPassword() async {
    final l10n = AbraLocalizations.of(context);
    final email = _email.text.trim();
    setState(() {
      _emailError = email.contains('@')
          ? null
          : l10n.text(AdminStrings.signInEmailInvalid);
      _passwordError = _password.text.isEmpty
          ? l10n.text(AdminStrings.signInPasswordRequired)
          : null;
    });
    if (_emailError != null || _passwordError != null) return;
    await _controller.signIn(email, _password.text);
    // The password leaves the field once it has been sent.
    if (mounted) _password.clear();
  }

  Future<void> _submitCode() async {
    final value = _code.text.trim();
    if (value.isEmpty) return;
    _code.clear();
    await _controller.verify(
      code: _useRecovery ? null : value,
      recoveryCode: _useRecovery ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(signInControllerProvider);
    final sessionEnded =
        ref.watch(authStateProvider) ==
        const AuthSignedOut(SignedOutReason.sessionExpired);
    final message = state.messageKey != null
        ? l10n.text(state.messageKey!)
        : state.failure != null
        ? failureText(l10n, state.failure!)
        : null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth),
            child: AbraCard(
              padding: const EdgeInsetsDirectional.all(AbraSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.text(AdminStrings.appName),
                    style: textTheme.titleMedium?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.text(
                        state.needsSecondStep
                            ? AdminStrings.mfaTitle
                            : AdminStrings.signInTitle,
                      ),
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    l10n.text(
                      !state.needsSecondStep
                          ? AdminStrings.signInSubtitle
                          : _useRecovery
                          ? AdminStrings.mfaRecoverySubtitle
                          : AdminStrings.mfaSubtitle,
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.lg),
                  if (sessionEnded && message == null && !state.needsSecondStep)
                    _Message(
                      l10n.text(AdminStrings.sessionEndedNotice),
                      isError: false,
                    ),
                  if (message != null) _Message(message, isError: true),
                  if (!state.needsSecondStep) ...<Widget>[
                    TextField(
                      controller: _email,
                      enabled: !state.isBusy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.text(AdminStrings.signInEmail),
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    TextField(
                      controller: _password,
                      enabled: !state.isBusy,
                      obscureText: true,
                      autofillHints: const <String>[AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: l10n.text(AdminStrings.signInPassword),
                        errorText: _passwordError,
                      ),
                      onSubmitted: (_) => _submitPassword(),
                    ),
                    const SizedBox(height: AbraSpacing.xl),
                    AbraButton(
                      label: l10n.text(AdminStrings.signInButton),
                      variant: AbraButtonVariant.primary,
                      expand: true,
                      isLoading: state.isBusy,
                      onPressed: _submitPassword,
                    ),
                  ] else ...<Widget>[
                    TextField(
                      controller: _code,
                      autofocus: true,
                      enabled: !state.isBusy,
                      keyboardType: _useRecovery
                          ? TextInputType.text
                          : TextInputType.number,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      inputFormatters: <TextInputFormatter>[
                        if (!_useRecovery) ...<TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ] else
                          LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.text(
                          _useRecovery
                              ? AdminStrings.mfaRecoveryCode
                              : AdminStrings.mfaCode,
                        ),
                      ),
                      onSubmitted: (_) => _submitCode(),
                    ),
                    const SizedBox(height: AbraSpacing.xl),
                    AbraButton(
                      label: l10n.text(AdminStrings.mfaVerify),
                      variant: AbraButtonVariant.primary,
                      expand: true,
                      isLoading: state.isBusy,
                      onPressed: _submitCode,
                    ),
                    const SizedBox(height: AbraSpacing.sm),
                    AbraButton(
                      label: l10n.text(
                        _useRecovery
                            ? AdminStrings.mfaUseApp
                            : AdminStrings.mfaUseRecovery,
                      ),
                      variant: AbraButtonVariant.text,
                      expand: true,
                      onPressed: state.isBusy
                          ? null
                          : () => setState(() {
                              _useRecovery = !_useRecovery;
                              _code.clear();
                            }),
                    ),
                    AbraButton(
                      label: l10n.text(AdminStrings.mfaBack),
                      variant: AbraButtonVariant.text,
                      expand: true,
                      onPressed: state.isBusy
                          ? null
                          : _controller.backToPassword,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = AbraStatusColors.from(context);
    final tone = isError ? colors.danger : colors.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tone.container,
            borderRadius: AbraRadius.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.md),
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tone.foreground),
            ),
          ),
        ),
      ),
    );
  }
}
