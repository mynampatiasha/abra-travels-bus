import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/format.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/resource_form.dart';
import '../catalogue/widgets/resource_page.dart';

const _statuses = <String, String>{
  'PENDING': AdminStrings.invStatusPending,
  'ACCEPTED': AdminStrings.invStatusAccepted,
  'REVOKED': AdminStrings.invStatusRevoked,
};

AbraStatusTone _tone(String status) => switch (status) {
  'ACCEPTED' => AbraStatusTone.success,
  'PENDING' => AbraStatusTone.warning,
  _ => AbraStatusTone.neutral,
};

/// Bus owners invited to the platform. Inviting creates the company and
/// emails the owner a link to set a password; from there the owner submits
/// documents, which appear under Reviews.
class InvitationsPage extends ConsumerWidget {
  const InvitationsPage({super.key});

  static const _inviteFields = <FieldSpec>[
    TextSpec('companyName', AdminStrings.invCompany, isRequired: true),
    TextSpec('displayName', AdminStrings.invDisplayName),
    TextSpec('ownerName', AdminStrings.invOwner, isRequired: true),
    TextSpec('email', AdminStrings.invEmail, isRequired: true),
    TextSpec('phone', AdminStrings.invPhone),
  ];

  /// Adds a company and sends its owner the invitation in one step; shows
  /// what happened to the email and the link. Used by Invitations and Operators.
  static Future<bool> inviteOwner(
    BuildContext context,
    CatalogueRepository repository,
  ) async {
    final l10n = AbraLocalizations.of(context);
    JsonMap? result;
    final saved = await showResourceForm(
      context,
      title: l10n.text(AdminStrings.invCreateTitle),
      fields: _inviteFields,
      message:
          'The owner receives an email with a link that works for seven days. '
          'KYC must be approved before the account opens.',
      onSubmit: (values) async {
        result = await repository.post('onboarding/invitations', values);
      },
    );
    if (saved && result != null && context.mounted) {
      await _showOutcome(context, result!);
    }
    return saved;
  }

  /// What happened to the email, and (outside production) the link to use.
  static Future<void> _showOutcome(BuildContext context, JsonMap result) {
    final l10n = AbraLocalizations.of(context);
    final sent = result['emailStatus'] == 'SENT';
    final link = result['inviteUrl'];
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          sent
              ? l10n.text(AdminStrings.invSent, <String, Object?>{
                  'email': result['email'],
                })
              : l10n.text(AdminStrings.invNotSent, <String, Object?>{
                  'reason': result['emailProblem'] ?? '',
                }),
        ),
        content: link == null
            ? null
            : SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.text(AdminStrings.invLink),
                      style: Theme.of(dialogContext).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    SelectableText('$link'),
                  ],
                ),
              ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.text(AdminStrings.importClose)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final repository = ref.read(catalogueRepositoryProvider);
    String statusText(JsonMap r) => l10n.text(
      r['expired'] == true
          ? AdminStrings.invStatusExpired
          : _statuses['${r['status']}'] ?? AdminStrings.invStatusPending,
    );

    return ResourcePage(
      path: 'onboarding/invitations',
      exportName: 'invitations',
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.invStatusPending,
          <String, String>{'status': 'PENDING'},
          Icons.mark_email_unread_outlined,
          AbraColors.orangeDark,
        ),
        StatSpec(
          AdminStrings.invStatusAccepted,
          <String, String>{'status': 'ACCEPTED'},
          Icons.how_to_reg_outlined,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.invStatusRevoked,
          <String, String>{'status': 'REVOKED'},
          Icons.block,
          AbraColors.navySecondary,
        ),
      ],
      filters: const <FilterSpec>[
        ChoiceFilter('status', AdminStrings.invColStatus, _statuses),
        DateRangeFilter('from', AdminStrings.invColCreated, toParam: 'to'),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.invColCompany,
          (_, r) => textCell(r['companyName']),
          text: (r) => '${r['companyName']}',
        ),
        ColumnSpec(
          AdminStrings.invColOwner,
          (_, r) => textCell(r['ownerName']),
          text: (r) => '${r['ownerName']}',
        ),
        ColumnSpec(
          AdminStrings.invColEmail,
          (_, r) => textCell(r['email']),
          text: (r) => '${r['email']}',
        ),
        ColumnSpec(
          AdminStrings.invColStatus,
          (_, r) => AbraStatusBadge(
            label: statusText(r),
            tone: r['expired'] == true
                ? AbraStatusTone.danger
                : _tone('${r['status']}'),
          ),
          text: statusText,
        ),
        ColumnSpec(
          AdminStrings.invColMail,
          (_, r) => Text(
            l10n.text(switch ('${r['emailStatus']}') {
              'SENT' => AdminStrings.invMailSent,
              'FAILED' => AdminStrings.invMailFailed,
              _ => AdminStrings.invMailNotSent,
            }),
          ),
          text: (r) => '${r['emailStatus']}',
        ),
        ColumnSpec(
          AdminStrings.invColExpires,
          (_, r) => Text(dateOf(r['expiresAt'])),
          text: (r) => dateOf(r['expiresAt']),
        ),
        ColumnSpec(
          AdminStrings.invColCreated,
          (_, r) => Text(dateOf(r['createdAt'])),
          text: (r) => dateOf(r['createdAt']),
        ),
      ],
      onCreate: (context) => inviteOwner(context, repository),
      rowActions: (record) => '${record['status']}' != 'PENDING'
          ? const <RowAction>[]
          : <RowAction>[
              RowAction(
                AdminStrings.invActionResend,
                Icons.forward_to_inbox_outlined,
                (context, record) async {
                  final result = await repository.post(
                    'onboarding/invitations/${record['id']}/resend',
                  );
                  if (context.mounted) await _showOutcome(context, result);
                  return true;
                },
              ),
              RowAction(AdminStrings.invActionRevoke, Icons.block, (
                context,
                record,
              ) async {
                final confirmed = await showAbraConfirmDialog(
                  context,
                  title: l10n.text(AdminStrings.invRevokeTitle),
                  message: l10n.text(AdminStrings.invRevokeMessage),
                  confirmLabel: l10n.text(AdminStrings.invRevokeConfirm),
                  isDestructive: true,
                );
                if (!confirmed) return false;
                await repository.post(
                  'onboarding/invitations/${record['id']}/revoke',
                );
                return true;
              }),
            ],
    );
  }
}
