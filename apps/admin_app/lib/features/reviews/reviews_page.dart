import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

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
class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return ResourcePage(
      path: 'onboarding/submissions',
      exportName: 'reviews',
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.revStatusPending,
          <String, String>{'status': 'PENDING'},
          Icons.hourglass_top,
          AbraColors.orangeDark,
        ),
        StatSpec(
          AdminStrings.revStatusRejected,
          <String, String>{'status': 'REJECTED'},
          Icons.undo,
          AbraColors.danger,
        ),
        StatSpec(
          AdminStrings.revStatusApproved,
          <String, String>{'status': 'APPROVED'},
          Icons.verified_outlined,
          AbraColors.tealDark,
        ),
      ],
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
          AdminStrings.revColSubject,
          (_, r) => Text(_subjectText(l10n, r)),
          text: (r) => _subjectText(l10n, r),
        ),
        ColumnSpec(
          AdminStrings.revColCompany,
          (_, r) => textCell(r['companyName']),
          text: (r) => '${r['companyName'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.revColBus,
          (_, r) => textCell(r['busRegistrationNumber']),
          text: (r) => '${r['busRegistrationNumber'] ?? ''}',
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
