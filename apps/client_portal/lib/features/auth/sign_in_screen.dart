import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../l10n/portal_strings.dart';
import 'sign_in_controller.dart';

/// Shown while the stored session is checked; offers a retry when the
/// server cannot be reached.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupProvider);
    return const Scaffold(
      backgroundColor: AbraColors.lightGray,
      body: Center(
        child: CircularProgressIndicator(color: AbraColors.blue),
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
  bool _showPassword = false;
  bool _terms = false;

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
      _emailError =
          email.contains('@') || RegExp(r'^\+?[0-9 ()-]{8,20}$').hasMatch(email)
          ? null
          : l10n.text(PortalStrings.signInEmailInvalid);
      _passwordError = _password.text.isEmpty
          ? l10n.text(PortalStrings.signInPasswordRequired)
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

    final form = AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(
                state.needsSecondStep
                    ? PortalStrings.mfaTitle
                    : PortalStrings.signInTitle,
              ),
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(
              !state.needsSecondStep
                  ? PortalStrings.signInSubtitle
                  : _useRecovery
                  ? PortalStrings.mfaRecoverySubtitle
                  : PortalStrings.mfaSubtitle,
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          if (sessionEnded && message == null && !state.needsSecondStep)
            _Message(
              l10n.text(PortalStrings.sessionEndedNotice),
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
                labelText: 'Email or phone number',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            TextField(
              controller: _password,
              enabled: !state.isBusy,
              obscureText: !_showPassword,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.text(PortalStrings.signInPassword),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: l10n.text(
                    _showPassword
                        ? PortalStrings.signInHidePassword
                        : PortalStrings.signInShowPassword,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                errorText: _passwordError,
              ),
              onSubmitted: (_) => _submitPassword(),
            ),
            const SizedBox(height: AbraSpacing.xl),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I agree to the terms and privacy policy'),
              value: _terms,
              onChanged: state.isBusy
                  ? null
                  : (value) => setState(() => _terms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AbraSpacing.sm),
            AbraButton(
              label: l10n.text(PortalStrings.signInButton),
              variant: AbraButtonVariant.callToAction,
              expand: true,
              isLoading: state.isBusy,
              onPressed: _submitPassword,
            ),
            const SizedBox(height: AbraSpacing.md),
            const Row(
              children: [
                Expanded(child: Divider(color: AbraColors.divider)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AbraColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AbraColors.divider)),
              ],
            ),
            const SizedBox(height: AbraSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final provider in SocialSignInProvider.values) ...[
                  SizedBox(
                    width: 48,
                    child: GoogleSignInButton(
                      iconOnly: true,
                      showTerms: false,
                      termsAccepted: _terms,
                      enabled: !state.isBusy,
                      provider: provider,
                      exchange: (token, password) async {
                        final manager = ref.read(sessionManagerProvider);
                        final result = provider == SocialSignInProvider.apple
                            ? await manager.signInWithApple(
                                token,
                                audience: 'CLIENT',
                                linkPassword: password,
                              )
                            : await manager.signInWithGoogle(
                                token,
                                audience: 'CLIENT',
                                linkPassword: password,
                              );
                        if (result is MfaChallenge) {
                          _controller.acceptGoogleChallenge(result);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.outlined(
                    tooltip: 'Continue with phone number',
                    onPressed: !_terms || state.isBusy
                        ? null
                        : () => showClientLoginMethods(context, signIn: true),
                    icon: const Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.md),
            const Text(
              'New clients complete KYC before account access. Already registered? Choose your account to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AbraColors.textSecondary, fontSize: 12),
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
                      ? PortalStrings.mfaRecoveryCode
                      : PortalStrings.mfaCode,
                ),
              ),
              onSubmitted: (_) => _submitCode(),
            ),
            const SizedBox(height: AbraSpacing.xl),
            AbraButton(
              label: l10n.text(PortalStrings.mfaVerify),
              variant: AbraButtonVariant.callToAction,
              expand: true,
              isLoading: state.isBusy,
              onPressed: _submitCode,
            ),
            const SizedBox(height: AbraSpacing.sm),
            AbraButton(
              label: l10n.text(
                _useRecovery
                    ? PortalStrings.mfaUseApp
                    : PortalStrings.mfaUseRecovery,
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
              label: l10n.text(PortalStrings.mfaBack),
              variant: AbraButtonVariant.text,
              expand: true,
              onPressed: state.isBusy ? null : _controller.backToPassword,
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AbraColors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          final formPanel = Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                isWide ? AbraSpacing.xxxl : AbraSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AbraEntrance(child: form),
              ),
            ),
          );
          if (isWide) {
            return Row(
              children: <Widget>[
                const Expanded(flex: 5, child: _BrandPanel(isCompact: false)),
                Expanded(flex: 4, child: SafeArea(child: formPanel)),
              ],
            );
          }
          return Column(
            children: <Widget>[
              const _BrandPanel(isCompact: true),
              Expanded(child: SafeArea(top: false, child: formPanel)),
            ],
          );
        },
      ),
    );
  }
}

/// The branded side of the sign-in screen: what this app is, on the brand
/// gradient. A short banner on narrow screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final mark = AbraBrandMark(
      name: l10n.text(PortalStrings.brandName),
      caption: l10n.text(PortalStrings.brandCaption),
    );
    if (isCompact) {
      return AbraBrandSurface(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.xl),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: mark,
            ),
          ),
        ),
      );
    }
    Widget point(String key, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: AbraSpacing.lg),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x24FFFFFF),
                borderRadius: AbraRadius.medium,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.sm),
                child: Icon(icon, color: AbraColors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Text(
              l10n.text(key),
              style: textTheme.bodyLarge?.copyWith(color: AbraColors.white),
            ),
          ),
        ],
      ),
    );
    return AbraBrandSurface(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              mark,
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.text(PortalStrings.signInBrandHeadline),
                      style: textTheme.displaySmall?.copyWith(
                        color: AbraColors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    Text(
                      l10n.text(PortalStrings.signInBrandBody),
                      style: textTheme.bodyLarge?.copyWith(
                        color: AbraColors.onNavyMuted,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    point(
                      PortalStrings.signInBrandPointCatalogue,
                      Icons.event_note_outlined,
                    ),
                    point(
                      PortalStrings.signInBrandPointAccess,
                      Icons.verified_user_outlined,
                    ),
                    point(
                      PortalStrings.signInBrandPointAudit,
                      Icons.history_outlined,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
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

Future<void> showClientLoginMethods(
  BuildContext context, {
  bool signIn = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ClientLoginMethods(signIn: signIn),
);

class _ClientLoginMethods extends ConsumerStatefulWidget {
  const _ClientLoginMethods({required this.signIn});
  final bool signIn;
  @override
  ConsumerState<_ClientLoginMethods> createState() =>
      _ClientLoginMethodsState();
}

class _ClientLoginMethodsState extends ConsumerState<_ClientLoginMethods> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _sentPhone;
  int _digits = 6;
  DateTime? _resendAt;
  Timer? _timer;
  String? _error;
  Map<String, dynamic>? _methods;
  @override
  void initState() {
    super.initState();
    if (!widget.signIn) unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _sent) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String get phone {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 10 ? '+91$digits' : '+$digits';
  }

  Future<void> _load() async {
    try {
      final r = await ref
          .read(appDependenciesProvider)
          .apiClient
          .get('client/kyc/login-methods');
      if (mounted) {
        setState(() => _methods = Map<String, dynamic>.from(r.data as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    }
  }

  Future<void> _request() async {
    if (_busy || (_resendAt?.isAfter(DateTime.now()) ?? false)) return;
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      setState(
        () => _error = 'Enter a valid phone number, including country code.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final number = phone;
      final r = await ref
          .read(appDependenciesProvider)
          .apiClient
          .post(
            'auth/otp/send',
            authenticated: false,
            body: {'phone': number, 'purpose': 'SIGN_IN'},
          );
      final j = r.data as Map;
      if (mounted) {
        setState(() {
          _sent = true;
          _sentPhone = number;
          _digits = (j['codeLength'] as num?)?.toInt() ?? 6;
          _resendAt = DateTime.now().add(
            Duration(seconds: (j['resendAfterSeconds'] as num?)?.toInt() ?? 60),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _sentPhone == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.signIn) {
        final result = await ref
            .read(sessionManagerProvider)
            .signInWithOtp(
              phone: _sentPhone!,
              code: _otp.text.trim(),
              audience: 'CLIENT',
            );
        if (result is MfaChallenge) {
          ref
              .read(signInControllerProvider.notifier)
              .acceptGoogleChallenge(result);
        }
        if (mounted) Navigator.pop(context);
      } else {
        await ref
            .read(appDependenciesProvider)
            .apiClient
            .post(
              'client/kyc/login-methods/phone',
              body: {'phone': _sentPhone, 'code': _otp.text.trim()},
            );
        _otp.clear();
        if (mounted) {
          setState(() => _sent = false);
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone linked to your existing client account.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _password() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(appDependenciesProvider)
          .apiClient
          .post(
            'me/password',
            body: {
              'newPassword': _newPassword.text,
              if (_methods?['hasPassword'] == true)
                'currentPassword': _currentPassword.text,
            },
          );
      _newPassword.clear();
      _currentPassword.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password saved. Use your linked email or phone to sign in.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_resendAt?.difference(DateTime.now()).inSeconds ?? 0)
        .clamp(0, 3600);
    return AlertDialog(
      title: Text(widget.signIn ? 'Phone sign-in' : 'Login methods'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.signIn
                    ? 'Receive a code on WhatsApp. New accounts must complete KYC. To use an existing approved account, enter its linked phone number.'
                    : 'Link your login methods here. Your company approval stays with this account.',
              ),
              if (_methods != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Email: ${_methods!['email'] ?? 'Not linked'}\nPhone: ${_methods!['phone'] ?? 'Not linked'}',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                enabled: !_busy && !_sent,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+91 9876543210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              if (!_sent)
                FilledButton(
                  onPressed: _busy ? null : _request,
                  child: const Text('Send code'),
                ),
              if (_sent) ...[
                Text('Enter the $_digits-digit code sent to $_sentPhone.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: _digits,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: Text(
                    widget.signIn
                        ? 'Verify and sign in'
                        : 'Verify and link phone',
                  ),
                ),
                TextButton(
                  onPressed: _busy || seconds > 0 ? null : _request,
                  child: Text(
                    seconds > 0 ? 'Resend in ${seconds}s' : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sent = false;
                          _sentPhone = null;
                          _otp.clear();
                        }),
                  child: const Text('Change number'),
                ),
              ],
              if (!widget.signIn) ...[
                const Divider(height: 32),
                for (final provider in SocialSignInProvider.values)
                  GoogleSignInButton(
                    enabled: !_busy,
                    provider: provider,
                    exchange: (token, password) async {
                      await ref
                          .read(appDependenciesProvider)
                          .apiClient
                          .post(
                            'client/kyc/login-methods/social',
                            body: {
                              'idToken': token,
                              'provider': provider == SocialSignInProvider.apple
                                  ? 'apple'
                                  : 'google',
                            },
                          );
                      await _load();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Social login linked to this account.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                const Divider(height: 32),
                if (_methods?['hasPassword'] == true)
                  TextField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'Use at least 10 characters.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _password,
                  child: const Text('Save password'),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
