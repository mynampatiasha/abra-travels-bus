import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../l10n/admin_strings.dart';
import '../../routing/admin_routes.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/resource_page.dart';

/// Label keys of the onboarding file statuses.
const submissionStatuses = <String, String>{
  'DRAFT': AdminStrings.revStatusDraft,
  'PENDING': AdminStrings.revStatusPending,
  'APPROVED': AdminStrings.revStatusApproved,
  'REJECTED': AdminStrings.revStatusRejected,
};

/// The colour of a status badge for an onboarding file or one of its documents.
AbraStatusTone submissionTone(String status) => switch (status) {
  'APPROVED' => AbraStatusTone.success,
  'PENDING' => AbraStatusTone.warning,
  'REJECTED' => AbraStatusTone.danger,
  _ => AbraStatusTone.neutral,
};

String _subjectText(AbraLocalizations l10n, JsonMap record) => l10n.text(
  record['subjectType'] == 'BUS'
      ? AdminStrings.revSubjectBus
      : AdminStrings.revSubjectCompany,
);

/// The review queue: company and bus documents sent by bus owners, oldest
/// waiting first. Opening one leads to the screen where its documents are
/// checked.
class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final canExport = ref
        .watch(accessProvider)
        .can(PermissionKeys.documentsExport);
    return ResourcePage(
      path: 'onboarding/submissions',
      exportPath: canExport ? 'onboarding/submissions' : null,
      emptyTitle: 'No submissions waiting',
      emptyMessage: 'You are all caught up.',
      filters: const <FilterSpec>[
        ChoiceFilter('status', AdminStrings.fieldStatus, submissionStatuses),
        ChoiceFilter(
          'subjectType',
          AdminStrings.revColSubject,
          <String, String>{
            'OPERATOR': AdminStrings.revSubjectCompany,
            'BUS': AdminStrings.revSubjectBus,
          },
        ),
        DateRangeFilter('from', AdminStrings.revColSent, toParam: 'to'),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          'ID',
          (_, r) => Text(
            r['id'] != null
                ? '#${r['id'].toString().length > 6 ? r['id'].toString().substring(0, 6) : r['id']}'
                : '',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          text: (r) => '${r['id'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.revColCompany,
          (_, r) {
            final bus = r['busRegistrationNumber'] as String?;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${r['companyName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (bus != null && bus.isNotEmpty)
                  Text(
                    'Bus $bus',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AbraColors.textSecondary,
                    ),
                  ),
              ],
            );
          },
          text: (r) => '${r['companyName'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.revColSubject,
          (_, r) => AbraStatusBadge(
            label: _subjectText(l10n, r),
            tone: AbraStatusTone.info,
          ),
          text: (r) => _subjectText(l10n, r),
        ),
        ColumnSpec(
          AdminStrings.revColStatus,
          (_, r) => AbraStatusBadge(
            label: l10n.text(
              submissionStatuses['${r['status']}'] ??
                  AdminStrings.revStatusDraft,
            ),
            tone: submissionTone('${r['status']}'),
          ),
          text: (r) => '${r['status']}',
        ),
        ColumnSpec(
          AdminStrings.revColSent,
          (_, r) => Text(dateOf(r['submittedAt'])),
          text: (r) => dateOf(r['submittedAt']),
        ),
        ColumnSpec(
          AdminStrings.revColTimes,
          (_, r) => textCell(r['submitCount']),
          isNumeric: true,
          text: (r) => '${r['submitCount']}',
        ),
      ],
      rowActions: (record) => <RowAction>[
        RowAction(AdminStrings.revActionOpen, Icons.fact_check_outlined, (
          context,
          record,
        ) async {
          context.go(AdminRoutes.reviewOf('${record['id']}'));
          return false;
        }),
      ],
    );
  }
}
