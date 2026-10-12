import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/ui/tonal_button.dart';
import '../../../l10n/customer_strings.dart';
import '../controllers/payment_controller.dart';

/// "Processing your payment": a turning ring, "don't close this screen" and
/// the amount. Shown on its own page that cannot be left.
class PaymentProcessingCard extends StatelessWidget {
  const PaymentProcessingCard({required this.amount, super.key});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return AbraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xxl,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: SizedBox.square(
                dimension: 84,
                child: CircularProgressIndicator(
                  value: still ? 0.25 : null,
                  strokeWidth: 6,
                  backgroundColor: AbraColors.skyContainer,
                  color: AbraColors.blue,
                ),
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            Text(
              l10n.text(CustomerStrings.payProcessingTitle),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AbraSpacing.sm),
            Text(
              l10n.text(CustomerStrings.payProcessingMessage),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            const Center(
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: AbraSkeleton(height: 8),
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            Text(
              amount,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Payment failed": why, what happens to any money, and the three ways on.
class PaymentFailedCard extends StatelessWidget {
  const PaymentFailedCard({
    required this.failureCode,
    required this.reference,
    required this.onRetry,
    required this.onChangeMethod,
    required this.onBack,
    super.key,
  });

  final String? failureCode;
  final String? reference;
  final VoidCallback onRetry;
  final VoidCallback onChangeMethod;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isNetwork = failureCode == PaymentController.networkFailureCode;
    final hasReference = reference != null && reference!.isNotEmpty;
    return AbraCard(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: _red),
              child: Padding(
                padding: EdgeInsets.all(AbraSpacing.lg),
                child: Icon(
                  Icons.close_rounded,
                  size: 44,
                  color: AbraColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.text(CustomerStrings.payFailedTitle),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            isNetwork
                ? l10n.text(CustomerStrings.payFailedNetwork)
                : l10n.text(CustomerStrings.payFailedMessage, <String, Object?>{
                    'code': failureCode ?? '',
                  }),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              borderRadius: AbraRadius.medium,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFF7A4B00),
                  ),
                  const SizedBox(width: AbraSpacing.sm),
                  Expanded(
                    child: Text(
                      hasReference
                          ? l10n.text(
                              CustomerStrings.payFailedRefundNote,
                              <String, Object?>{'reference': reference},
                            )
                          : l10n.text(CustomerStrings.payFailedRefundNoteShort),
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A4B00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          AbraButton(
            label: l10n.text(CustomerStrings.payRetry),
            variant: AbraButtonVariant.primary,
            expand: true,
            onPressed: onRetry,
          ),
          const SizedBox(height: AbraSpacing.sm),
          TonalButton(
            label: l10n.text(CustomerStrings.payChangeMethod),
            expand: true,
            onPressed: onChangeMethod,
          ),
          const SizedBox(height: AbraSpacing.xs),
          AbraButton(
            label: l10n.text(CustomerStrings.payBackToReview),
            variant: AbraButtonVariant.text,
            expand: true,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

/// The red of failures in the approved design.
const Color _red = Color(0xFFEF4444);

/// Places a card at the top of a page, with the width a single-column step
/// uses.
class PaymentStatePage extends StatelessWidget {
  const PaymentStatePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      padding: AbraResponsive.pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    ),
  );
}
