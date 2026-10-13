import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../../invitations/invitations_page.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/record_actions.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Operators. Platform staff see all and decide their status; operator
/// staff see their own operator and may edit its profile.
class OperatorsPage extends ConsumerWidget {
  const OperatorsPage({super.key});

  static const _fields = <FieldSpec>[
    TextSpec('companyName', AdminStrings.fieldCompanyName, isRequired: true),
    TextSpec('displayName', AdminStrings.fieldDisplayName, clearable: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canEdit = access.can(PermissionKeys.operatorsUpdate);
    final canApprove = access.can(PermissionKeys.operatorsApprove);
    final canDelete = access.can(PermissionKeys.operatorsDelete);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'operators',
      exportPath: access.can(PermissionKeys.operatorsExport)
          ? 'operators'
          : null,
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.operatorActive,
          <String, String>{'status': 'ACTIVE'},
          Icons.verified_outlined,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.operatorPending,
          <String, String>{'status': 'PENDING_APPROVAL'},
          Icons.hourglass_top,
          AbraColors.orangeDark,
        ),
        StatSpec(
          AdminStrings.operatorSuspended,
          <String, String>{'status': 'SUSPENDED'},
          Icons.block,
          AbraColors.danger,
        ),
      ],
      filters: const <FilterSpec>[
        ChoiceFilter(
          'status',
          AdminStrings.fieldStatus,
          CatalogueLabels.operatorStatuses,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldCompanyName,
          (_, r) => textCell(r['companyName']),
          text: (r) => plainText(r['companyName']),
        ),
        ColumnSpec(
          AdminStrings.fieldDisplayName,
          (_, r) => textCell(r['displayName']),
          text: (r) => plainText(r['displayName']),
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => StatusBadge(
            r['status']! as String,
            CatalogueLabels.operatorStatuses,
          ),
          text: (r) => CatalogueLabels.readable('${r['status']}'),
        ),
      ],
      onCreate: access.can(PermissionKeys.operatorsCreate)
          ? (context) => InvitationsPage.inviteOwner(context, repository)
          : null,
      rowActions: (record) {
        final next =
            CatalogueLabels.operatorTransitions[record['status']] ??
            const <String>[];
        return <RowAction>[
          viewAction(
            repository: repository,
            path: 'operators',
            titleOf: operatorNameOf,
            linesOf: (l10n, r) => <DetailLine>[
              DetailLine(
                AdminStrings.fieldCompanyName,
                '${r['companyName'] ?? ''}',
              ),
              DetailLine(
                AdminStrings.fieldDisplayName,
                '${r['displayName'] ?? ''}',
              ),
              DetailLine(
                AdminStrings.fieldStatus,
                optionLabel(
                  l10n,
                  CatalogueLabels.operatorStatuses,
                  r['status'],
                ),
              ),
            ],
          ),
          if (canEdit)
            RowAction(
              AdminStrings.actionEdit,
              Icons.edit_outlined,
              (context, record) => showResourceForm(
                context,
                title: l10n.text(AdminStrings.operatorEditTitle),
                fields: _fields,
                initial: record,
                onSubmit: (values) =>
                    repository.put('operators/${record['id']}', values),
              ),
            ),
          if (canApprove && next.isNotEmpty)
            RowAction(
              AdminStrings.actionChangeStatus,
              Icons.verified_outlined,
              (context, record) => showStatusForm(
                context,
                ref,
                title: l10n.text(AdminStrings.operatorStatusTitle),
                path: 'operators/${record['id']}/status',
                options: <String, String>{
                  for (final status in next)
                    status: CatalogueLabels.operatorStatuses[status]!,
                },
                reasonRequired: true,
              ),
            ),
          if (canDelete)
            deleteAction(
              repository: repository,
              path: 'operators',
              nameOf: operatorNameOf,
            ),
        ];
      },
    );
  }
}
