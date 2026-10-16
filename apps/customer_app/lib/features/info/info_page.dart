import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/app_info.dart';
import '../../core/ui/gradient_header.dart';
import '../../l10n/customer_strings.dart';

enum InfoPageKind { terms, privacy, about }

class InfoPage extends StatelessWidget {
  const InfoPage({required this.kind, super.key});

  final InfoPageKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final title = l10n.text(switch (kind) {
      InfoPageKind.terms => CustomerStrings.infoTermsTitle,
      InfoPageKind.privacy => CustomerStrings.infoPrivacyTitle,
      InfoPageKind.about => CustomerStrings.infoAboutTitle,
    });

    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: switch (kind) {
        InfoPageKind.about => _About(),
        InfoPageKind.terms => const _TermsContent(),
        InfoPageKind.privacy => const _PrivacyContent(),
      },
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth * 1.4),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms and Conditions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AbraSpacing.xs),
              Text(
                'Version 4.0 • Updated October 2026',
                style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
              ),
              SizedBox(height: AbraSpacing.lg),
              _PolicySection(
                title: '1. Booking & Travel Regulations',
                body:
                    'All bus tickets booked via Abra Travels are confirmed reservations with licensed operator partners. Passengers must carry a government-approved photo ID and reach their scheduled boarding point at least 15 minutes before the departure time.',
              ),
              _PolicySection(
                title: '2. Seat Allocation & Quotas',
                body:
                    'Seats designated as "Ladies Quota" are reserved strictly for female passengers. Abra Travels and the operating partner reserve the right to reassign or cancel non-compliant bookings.',
              ),
              _PolicySection(
                title: '3. Cancellation & Refund Policy',
                body:
                    'Cancellations are governed by the operator slabs:\n• More than 48 hours before departure: 100% fare refund\n• 24 to 48 hours: 75% fare refund\n• 12 to 24 hours: 50% fare refund\n• 4 to 12 hours: 25% fare refund\n• Less than 4 hours: No refund\nIf a trip is cancelled by the operator, passengers receive a 100% full refund.',
              ),
              _PolicySection(
                title: '4. Limitation of Liability',
                body:
                    'Abra Travels acts as a technology intermediary connecting passengers with bus operators. While we enforce strict quality, safety, and GPS compliance standards, delays caused by traffic or severe weather remain subject to operator management.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth * 1.4),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AbraSpacing.xs),
              Text(
                'Version 3.0 • Updated October 2026',
                style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
              ),
              SizedBox(height: AbraSpacing.lg),
              _PolicySection(
                title: '1. Information We Collect',
                body:
                    'We collect your mobile number, name, email address, passenger travel details, and designated emergency contacts solely to facilitate bus booking, ticket delivery, and journey safety.',
              ),
              _PolicySection(
                title: '2. Payment Security',
                body:
                    'Payments are processed through PCI-DSS Level 1 certified payment partners. Abra Travels does not record, store, or process your credit/debit card numbers or CVV on our servers.',
              ),
              _PolicySection(
                title: '3. Live Location & Trip Sharing',
                body:
                    'Live bus tracking and trip sharing links are shared only with contacts you explicitly authorize. All public tracking tokens expire automatically 1 hour after arrival.',
              ),
              _PolicySection(
                title: '4. Data Retention',
                body:
                    'Account profiles and preferences can be deleted anytime. Transaction and tax invoice records are retained for 8 years strictly to comply with Indian financial and accounting statutes.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AbraColors.deepBlue,
            ),
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AbraColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: AbraResponsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth),
          child: Column(
            children: <Widget>[
              const AbraLogo(size: 88),
              const SizedBox(height: AbraSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.appName),
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                l10n.text(CustomerStrings.splashTagline),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              AbraCard(
                child: Text(
                  l10n.text(CustomerStrings.infoAboutBody),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              Text(
                l10n.text(CustomerStrings.infoAboutVersion, <String, Object?>{
                  'version': AppInfo.version,
                }),
                style: textTheme.bodySmall?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
