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
    if (failure == null) {
      return const Scaffold(
        body: AbraBrandSurface(child: AbraLoadingView(onDark: true)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No backend server connected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The live backend API server is offline. You can explore the full administration portal in the interactive Demo Session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(accessProvider.notifier).enterDemoSession();
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Enter Demo Session (Super Admin)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: ref.read(startupProvider.notifier).restore,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Retry server connection'),
                ),
              ],
            ),
          ),
        ),
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
                labelText: l10n.text(AdminStrings.signInPassword),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: l10n.text(
                    _showPassword
                        ? AdminStrings.signInHidePassword
                        : AdminStrings.signInShowPassword,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                errorText: _passwordError,
              ),
              onSubmitted: (_) => _submitPassword(),
            ),
            const SizedBox(height: AbraSpacing.xl),
            AbraButton(
              label: l10n.text(AdminStrings.signInButton),
              variant: AbraButtonVariant.callToAction,
              expand: true,
              isLoading: state.isBusy,
              onPressed: _submitPassword,
            ),
            const SizedBox(height: AbraSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(accessProvider.notifier).enterDemoSession();
              },
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Explore Demo Session (Super Admin)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AbraColors.blue,
                minimumSize: const Size(double.infinity, 44),
              ),
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
              variant: AbraButtonVariant.callToAction,
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
      name: l10n.text(AdminStrings.brandName),
      caption: l10n.text(AdminStrings.brandCaption),
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
                      l10n.text(AdminStrings.signInBrandHeadline),
                      style: textTheme.displaySmall?.copyWith(
                        color: AbraColors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    Text(
                      l10n.text(AdminStrings.signInBrandBody),
                      style: textTheme.bodyLarge?.copyWith(
                        color: AbraColors.onNavyMuted,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    point(
                      AdminStrings.signInBrandPointCatalogue,
                      Icons.event_note_outlined,
                    ),
                    point(
                      AdminStrings.signInBrandPointAccess,
                      Icons.verified_user_outlined,
                    ),
                    point(
                      AdminStrings.signInBrandPointAudit,
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
