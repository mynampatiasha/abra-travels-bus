import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/failure_text.dart';
import '../../l10n/portal_strings.dart';
import '../../routing/portal_routes.dart';
import '../onboarding/onboarding_repository.dart';

/// Where the link in the invitation email leads: the owner sees which company
/// it is for, chooses a password, and the account is created. Then they sign in.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  JsonMap? _invitation;
  var _invalid = false;
  var _loading = true;
  var _busy = false;
  var _done = false;
  var _hidden = true;
  String? _error;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inspect());
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _invalid = true;
        _loading = false;
      });
      return;
    }
    try {
      final invitation = await ref
          .read(onboardingRepositoryProvider)
          .inspectInvitation(token);
      if (!mounted) return;
      setState(() {
        _invitation = invitation;
        _name.text = '${invitation['ownerName'] ?? ''}';
        _loading = false;
      });
    } on Object {
      // A bad, used, withdrawn or expired link all look the same
      if (mounted) {
        setState(() {
          _invalid = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .acceptInvitation(
            token: widget.token!,
            password: _password.text,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          );
      if (mounted) setState(() => _done = true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = failureText(_l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;
    if (_loading) {
      body = const AbraLoadingView();
    } else if (_invalid) {
      body = AbraStateView(
        kind: AbraStateKind.forbidden,
        title: _l10n.text(PortalStrings.inviteInvalidTitle),
        message: _l10n.text(PortalStrings.inviteInvalidMessage),
        actionLabel: _l10n.text(PortalStrings.inviteSignIn),
        onAction: () => context.go(PortalRoutes.signIn),
      );
    } else if (_done) {
      body = AbraStateView(
        kind: AbraStateKind.empty,
        title: _l10n.text(PortalStrings.inviteDone),
        actionLabel: _l10n.text(PortalStrings.inviteSignIn),
        onAction: () => context.go(PortalRoutes.signIn),
      );
    } else {
      final invitation = _invitation!;
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AbraCard(
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              gradient: AbraGradients.brand,
                              borderRadius: AbraRadius.medium,
                            ),
                            child: const Icon(
                              Icons.directions_bus_outlined,
                              color: AbraColors.white,
                            ),
                          ),
                          const SizedBox(width: AbraSpacing.md),
                          Text(
                            'Abra Partner Portal',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AbraSpacing.lg),
                      Text(
                        _l10n.text(PortalStrings.inviteTitle),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      Text(
                        _l10n.text(
                          PortalStrings.inviteSubtitle,
                          <String, Object?>{
                            'company': invitation['companyName'],
                          },
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AbraSpacing.lg),
                      TextFormField(
                        initialValue: '${invitation['email']}',
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: _l10n.text(PortalStrings.inviteEmail),
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.md),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: _l10n.text(PortalStrings.inviteName),
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.md),
                      TextFormField(
                        controller: _password,
                        onChanged: (_) => setState(() {}),
                        obscureText: _hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: _l10n.text(PortalStrings.invitePassword),
                          helperText: _l10n.text(PortalStrings.inviteHelp),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidden ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _hidden = !_hidden),
                          ),
                        ),
                        validator: (value) => (value ?? '').length < 10
                            ? _l10n.text(PortalStrings.invitePasswordShort)
                            : null,
                      ),
                      _StrengthMeter(password: _password.text),
                      const SizedBox(height: AbraSpacing.md),
                      TextFormField(
                        controller: _repeat,
                        obscureText: _hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: _l10n.text(PortalStrings.inviteConfirm),
                        ),
                        validator: (value) => value != _password.text
                            ? _l10n.text(PortalStrings.inviteMismatch)
                            : null,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: AbraSpacing.md),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AbraColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: AbraSpacing.lg),
                      AbraButton(
                        label: _l10n.text(PortalStrings.inviteButton),
                        isLoading: _busy,
                        variant: AbraButtonVariant.callToAction,
                        onPressed: _accept,
                        expand: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final showsForm = !_loading && !_invalid && !_done;
    return Scaffold(
      backgroundColor: AbraColors.lightGray,
      body: showsForm
          ? DecoratedBox(
              decoration: const BoxDecoration(gradient: AbraGradients.brand),
              child: body,
            )
          : body,
    );
  }
}

/// Four bars that fill as the password gets stronger (length, mixed case,
/// a digit, a symbol with a long password).
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  int get _score {
    var score = 0;
    if (password.length >= 10) score++;
    if (RegExp('[A-Z]').hasMatch(password) &&
        RegExp('[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) && password.length >= 12) {
      score++;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final color = switch (score) {
      <= 1 => AbraColors.danger,
      2 => AbraColors.orange,
      3 => AbraColors.blue,
      _ => AbraColors.teal,
    };
    return password.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AbraSpacing.sm),
            child: Semantics(
              label: 'Password strength $score of 4',
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < 4; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: AbraSpacing.xs),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < score ? color : AbraColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
  }
}
