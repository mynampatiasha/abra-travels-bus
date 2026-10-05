import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import 'abra_button.dart';

/// The situations a screen can be in instead of showing its content.
enum AbraStateKind {
  empty,
  error,
  networkUnavailable,
  timeout,
  serverFailure,
  unauthorized,
  forbidden,
  notFound,
  sessionExpired,
  rateLimited,
  success,
}

typedef _StateDefaults = ({
  IconData icon,
  AbraStatusTone tone,
  String titleKey,
  String? messageKey,
});

_StateDefaults _defaultsFor(AbraStateKind kind) => switch (kind) {
  AbraStateKind.empty => (
    icon: Icons.inbox_outlined,
    tone: AbraStatusTone.neutral,
    titleKey: AbraStrings.stateEmptyTitle,
    messageKey: AbraStrings.stateEmptyMessage,
  ),
  AbraStateKind.error => (
    icon: Icons.error_outline,
    tone: AbraStatusTone.danger,
    titleKey: AbraStrings.stateErrorTitle,
    messageKey: AbraStrings.stateErrorMessage,
  ),
  AbraStateKind.networkUnavailable => (
    icon: Icons.wifi_off_outlined,
    tone: AbraStatusTone.warning,
    titleKey: AbraStrings.stateNetworkTitle,
    messageKey: AbraStrings.stateNetworkMessage,
  ),
  AbraStateKind.timeout => (
    icon: Icons.hourglass_empty_outlined,
    tone: AbraStatusTone.warning,
    titleKey: AbraStrings.stateTimeoutTitle,
    messageKey: AbraStrings.stateTimeoutMessage,
  ),
  AbraStateKind.serverFailure => (
    icon: Icons.cloud_off_outlined,
    tone: AbraStatusTone.danger,
    titleKey: AbraStrings.stateServerTitle,
    messageKey: AbraStrings.stateServerMessage,
  ),
  AbraStateKind.unauthorized => (
    icon: Icons.lock_outline,
    tone: AbraStatusTone.info,
    titleKey: AbraStrings.stateUnauthorizedTitle,
    messageKey: AbraStrings.stateUnauthorizedMessage,
  ),
  AbraStateKind.forbidden => (
    icon: Icons.block_outlined,
    tone: AbraStatusTone.danger,
    titleKey: AbraStrings.stateForbiddenTitle,
    messageKey: AbraStrings.stateForbiddenMessage,
  ),
  AbraStateKind.notFound => (
    icon: Icons.search_off_outlined,
    tone: AbraStatusTone.neutral,
    titleKey: AbraStrings.stateNotFoundTitle,
    messageKey: AbraStrings.stateNotFoundMessage,
  ),
  AbraStateKind.sessionExpired => (
    icon: Icons.logout_outlined,
    tone: AbraStatusTone.info,
    titleKey: AbraStrings.stateSessionExpiredTitle,
    messageKey: AbraStrings.stateSessionExpiredMessage,
  ),
  AbraStateKind.rateLimited => (
    icon: Icons.timer_outlined,
    tone: AbraStatusTone.warning,
    titleKey: AbraStrings.stateRateLimitedTitle,
    messageKey: AbraStrings.stateRateLimitedMessage,
  ),
  AbraStateKind.success => (
    icon: Icons.check_circle_outline,
    tone: AbraStatusTone.success,
    titleKey: AbraStrings.stateSuccessTitle,
    messageKey: null,
  ),
};

/// A full-area message for a screen state: icon, title, explanation and up
/// to two actions. Texts default to the shared translations for [kind] and
/// can be replaced per screen ("No bookings yet").
///
/// An action button appears only when both its label and its callback are
/// given, so there is never a button that does nothing.
class AbraStateView extends StatelessWidget {
  const AbraStateView({
    required this.kind,
    this.title,
    this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  final AbraStateKind kind;

  /// Replaces the default title of [kind].
  final String? title;

  /// Replaces the default message of [kind].
  final String? message;

  /// Small print under the message, for example a support reference.
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final defaults = _defaultsFor(kind);
    final colors = AbraStatusColors.from(context).of(defaults.tone);
    final textTheme = Theme.of(context).textTheme;
    final resolvedMessage =
        message ??
        (defaults.messageKey == null ? null : l10n.text(defaults.messageKey!));

    return Center(
      child: SingleChildScrollView(
        padding: AbraResponsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.container,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: AbraSizes.stateIllustration,
                    child: Icon(
                      defaults.icon,
                      size: AbraSizes.iconLarge - AbraSpacing.md,
                      color: colors.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title ?? l10n.text(defaults.titleKey),
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              if (resolvedMessage != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                Text(
                  resolvedMessage,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (detail != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                SelectableText(
                  detail!,
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.xl),
                AbraButton(label: actionLabel!, onPressed: onAction),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                AbraButton(
                  label: secondaryActionLabel!,
                  onPressed: onSecondaryAction,
                  variant: AbraButtonVariant.text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
