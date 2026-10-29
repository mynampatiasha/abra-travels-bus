import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../../places/places_admin_manage_screen.dart'
    show placeRequestStatuses, requestTone, timeAgo, twoLineCell;
import '../catalogue_repository.dart';
import 'catalogue_common.dart';
import 'record_actions.dart';
import 'resource_form.dart';
import 'resource_page.dart';

// The Requests tab of the admin Bus types page: the bus types operators ask for
// from the client portal ("My bus type isn't listed", `admin/bus-type-requests`).

// ===== 1. STATE AND API =====

/// How many bus type requests wait for a decision (the number on the tab).
final busTypeRequestsPendingProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  // Reload together with the lists, after any change
  final repository = ref.watch(catalogueRepositoryProvider);
  final access = ref.watch(accessProvider);
  if (!access.can(PermissionKeys.catalogueRead)) return 0;
  final answer = await repository.get('admin/bus-type-requests/pending-count');
  return (answer['pending'] as num? ?? 0).toInt();
});

/// What the operator asked for, in the words the Bus types list uses.
String _kindOf(Map<String, Object?> r) {
  final ac = r['isAc'] == true ? 'AC' : 'Non-AC';
  final berth = switch (r['berthType']) {
    'SEATER' => 'Seater',
    'SLEEPER' => 'Sleeper',
    'SEMI_SLEEPER' => 'Semi-sleeper',
    _ => 'Seater + Sleeper',
  };
  return '$ac $berth';
}

// ===== 2. WIDGETS =====

/// Search and Status; Bus type, Operator, Requested, Status; Approve and Reject
/// while pending.
class BusTypeRequestsTab extends ConsumerWidget {
  const BusTypeRequestsTab({super.key});

  static const path = 'admin/bus-type-requests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final repository = ref.read(catalogueRepositoryProvider);
    final canDecide = access.can(PermissionKeys.catalogueManage);

    /// Runs a decision and says what happened.
    Future<bool> approve(BuildContext context, Map<String, Object?> r) async {
      final messenger = ScaffoldMessenger.of(context);
      final container = ProviderScope.containerOf(context);
      try {
        await repository.post('$path/${r['id']}/approve');
      } on Object catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(failureText(l10n, error))),
        );
        return false;
      }
      container
        ..invalidate(resourceListProvider)
        ..invalidate(busTypeRequestsPendingProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Approved. The bus type is now on the list.'),
        ),
      );
      return false;
    }

    return ResourcePage(
      path: path,
      exportPath: null,
      emptyTitle: 'No requests',
      emptyMessage: 'Operators ask here when their bus type is not listed.',
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
        ChoiceFilter('status', AdminStrings.fieldStatus, placeRequestStatuses),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          'Bus type',
          (_, r) => twoLineCell(r['name'], _kindOf(r)),
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldOperator,
          (_, r) => Text(plainText(r['operatorName'])),
          text: (r) => plainText(r['operatorName']),
        ),
        ColumnSpec(
          AdminStrings.preqColRequested,
          (context, r) =>
              Text(timeAgo(AbraLocalizations.of(context), r['requestedAt'])),
          text: (r) => plainText(r['requestedAt']),
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (context, r) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AbraStatusBadge(
                label: optionLabel(
                  AbraLocalizations.of(context),
                  placeRequestStatuses,
                  r['status'],
                ),
                tone: requestTone('${r['status']}'),
              ),
              if (r['reason'] != null)
                Text(
                  '${r['reason']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AbraColors.textSecondary,
                  ),
                ),
            ],
          ),
          text: (r) => optionLabel(l10n, placeRequestStatuses, r['status']),
        ),
      ],
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: path,
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(
              AdminStrings.fieldOperator,
              plainText(r['operatorName']),
            ),
            DetailLine('Bus type', nameOf(r)),
            DetailLine('Kind', _kindOf(r)),
            DetailLine(
              AdminStrings.fieldStatus,
              optionLabel(l10n, placeRequestStatuses, r['status']),
            ),
            if (r['reason'] != null)
              DetailLine(AdminStrings.fieldReason, plainText(r['reason'])),
          ],
        ),
        if (canDecide && record['status'] == 'PENDING') ...<RowAction>[
          RowAction(AdminStrings.preqApprove, Icons.check, approve),
          RowAction(AdminStrings.preqReject, Icons.close, (context, r) async {
            final container = ProviderScope.containerOf(context);
            final rejected = await showResourceForm(
              context,
              title: l10n.text(AdminStrings.preqRejectTitle),
              submitLabel: l10n.text(AdminStrings.preqReject),
              width: 440,
              fields: const <FieldSpec>[
                TextSpec(
                  'reason',
                  AdminStrings.preqReason,
                  isRequired: true,
                  maxLines: 3,
                ),
              ],
              onSubmit: (values) =>
                  repository.post('$path/${r['id']}/reject', values),
            );
            if (rejected) container.invalidate(busTypeRequestsPendingProvider);
            return rejected;
          }),
        ],
      ],
    );
  }
}

/// The two tabs of the page: the list and the requests, with the number waiting.
class BusTypesTabStrip extends StatelessWidget {
  const BusTypesTabStrip({
    required this.showRequests,
    required this.requestsSelected,
    required this.pending,
    required this.onSelect,
    super.key,
  });

  final bool showRequests;
  final bool requestsSelected;
  final int? pending;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tab(String label, bool selected, bool requests, {int? count}) =>
        Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            onTap: () => onSelect(requests),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AbraColors.blue : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected
                          ? AbraColors.deepBlue
                          : AbraColors.textSecondary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(width: AbraSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: AbraColors.navyContainer,
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AbraColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AbraColors.border)),
      ),
      child: Row(
        children: <Widget>[
          tab('Bus types', !requestsSelected, false),
          if (showRequests)
            tab('Requests', requestsSelected, true, count: pending),
        ],
      ),
    );
  }
}
