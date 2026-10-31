import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/app_info.dart';
import '../../core/async_value_view.dart';
import '../../core/ui/gradient_header.dart';
import '../../l10n/customer_strings.dart';
import 'info_repository.dart';

export 'info_repository.dart' show InfoPageKind;

/// Terms, privacy or about: the text staff published in the admin app,
/// read from the backend. Nothing is written into the app itself.
class InfoPage extends ConsumerWidget {
  const InfoPage({required this.kind, super.key});

  final InfoPageKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final title = l10n.text(switch (kind) {
      InfoPageKind.terms => CustomerStrings.infoTermsTitle,
      InfoPageKind.privacy => CustomerStrings.infoPrivacyTitle,
      InfoPageKind.about => CustomerStrings.infoAboutTitle,
    });

    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: AsyncValueView<InfoPageContent>(
        value: ref.watch(infoPageProvider(kind)),
        onRetry: () => ref.invalidate(infoPageProvider(kind)),
        data: (context, page) => _PageBody(kind: kind, page: page),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.kind, required this.page});

  final InfoPageKind kind;
  final InfoPageContent page;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final updated = page.updatedAt;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: AbraResponsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth * 1.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (kind == InfoPageKind.about) ...<Widget>[
                const Center(child: AbraLogo(size: 88)),
                const SizedBox(height: AbraSpacing.lg),
              ],
              Semantics(
                header: true,
                child: Text(page.title, style: textTheme.titleLarge),
              ),
              if (updated != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.xs),
                Text(
                  MaterialLocalizations.of(context).formatMediumDate(updated.toLocal()),
                  style: textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AbraSpacing.lg),
              for (final paragraph in page.paragraphs) ...<Widget>[
                Text(paragraph, style: textTheme.bodyMedium),
                const SizedBox(height: AbraSpacing.md),
              ],
              if (kind == InfoPageKind.about) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Text(
                  l10n.text(CustomerStrings.infoAboutVersion, <String, Object?>{
                    'version': AppInfo.version,
                  }),
                  style: textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
