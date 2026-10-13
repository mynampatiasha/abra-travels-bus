import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../l10n/admin_strings.dart';
import '../../../routing/admin_routes.dart';
import '../../invitations/invitations_page.dart';
import '../../reviews/reviews_page.dart';
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
      path: 'admin/operators',
      createLabelKey: AdminStrings.opInvite,
      exportPath: access.can(PermissionKeys.operatorsExport)
          ? 'admin/operators'
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
        SearchFilter('query', AdminStrings.opSearch),
        ChoiceFilter(
          'status',
          AdminStrings.fieldStatus,
          CatalogueLabels.operatorStatuses,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.opNameColumn,
          (context, r) => InkWell(
            onTap: () => context.go(AdminRoutes.operatorOf('${r['id']}')),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  operatorNameOf(r),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(r['owner'] as Map<Object?, Object?>?)?['name'] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          text: operatorNameOf,
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => StatusBadge(
            r['status']! as String,
            CatalogueLabels.operatorStatuses,
          ),
          text: (r) => CatalogueLabels.readable('${r['status']}'),
        ),
        ColumnSpec(
          AdminStrings.opKycColumn,
          (context, r) {
            final kyc = r['kycStatus'] as String?;
            return kyc == null
                ? const Text('—')
                : AbraStatusBadge(
                    label: AbraLocalizations.of(context).text(
                      submissionStatuses[kyc] ?? AdminStrings.revStatusDraft,
                    ),
                    tone: submissionTone(kyc),
                  );
          },
          text: (r) => CatalogueLabels.readable('${r['kycStatus'] ?? ''}'),
        ),
        ColumnSpec(
          AdminStrings.opdBuses,
          (_, r) => Text('${r['buses'] ?? 0}'),
          isNumeric: true,
          text: (r) => plainText(r['buses']),
        ),
        ColumnSpec(
          AdminStrings.opdTrips,
          (_, r) => Text('${r['trips'] ?? 0}'),
          isNumeric: true,
          text: (r) => plainText(r['trips']),
        ),
        ColumnSpec(
          AdminStrings.opJoinedColumn,
          (_, r) => Text(dateOf(r['joinedAt'])),
          text: (r) => dateOf(r['joinedAt']),
        ),
      ],
      onCreate: access.can(PermissionKeys.operatorsCreate)
          ? (context) => InvitationsPage.inviteOwner(context, repository)
          : null,
      rowActions: (record) {
        // Suspending and reactivating are done on the operator's own page; here only a
        // company waiting for approval is approved or rejected
        final next = record['status'] == 'PENDING_APPROVAL'
            ? (CatalogueLabels.operatorTransitions['PENDING_APPROVAL'] ??
                  const <String>[])
            : const <String>[];
        return <RowAction>[
          RowAction(AdminStrings.actionView, Icons.visibility_outlined, (
            context,
            record,
          ) async {
            context.go(AdminRoutes.operatorOf('${record['id']}'));
            return false;
          }),
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
