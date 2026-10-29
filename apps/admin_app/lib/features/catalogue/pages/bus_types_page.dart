import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/amenities_card.dart';
import '../widgets/bus_type_requests_tab.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/import_dialog.dart';
import '../widgets/record_actions.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Bus types: the kinds of bus operators register and customers filter by, and
/// (second tab) the bus types operators ask for. `?tab=requests` opens the
/// second tab, where a "Bus type request" notification leads.
class BusTypesPage extends ConsumerStatefulWidget {
  const BusTypesPage({super.key});

  @override
  ConsumerState<BusTypesPage> createState() => _BusTypesPageState();
}

class _BusTypesPageState extends ConsumerState<BusTypesPage> {
  bool? _requests;

  @override
  Widget build(BuildContext context) {
    final canSeeRequests = ref
        .watch(accessProvider)
        .can(PermissionKeys.catalogueRead);
    final asked = GoRouterState.of(context).uri.queryParameters['tab'];
    final showRequests =
        canSeeRequests && (_requests ?? asked == 'requests');
    if (!canSeeRequests) return const _BusTypesList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AbraSpacing.xl,
            AbraSpacing.md,
            AbraSpacing.xl,
            0,
          ),
          child: BusTypesTabStrip(
            showRequests: true,
            requestsSelected: showRequests,
            pending: ref.watch(busTypeRequestsPendingProvider).value,
            onSelect: (requests) => setState(() => _requests = requests),
          ),
        ),
        Expanded(
          child: showRequests
              ? const BusTypeRequestsTab()
              : const _BusTypesList(),
        ),
      ],
    );
  }
}

class _BusTypesList extends ConsumerWidget {
  const _BusTypesList();

  static const _editFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    BoolSpec('isAc', AdminStrings.fieldAc),
    ChoiceSpec(
      'berthType',
      AdminStrings.fieldBerthType,
      CatalogueLabels.berthTypes,
      isRequired: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canManage = access.can(PermissionKeys.catalogueManage);
    final canDelete = access.can(PermissionKeys.catalogueDelete);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'bus-types',
      footer: AmenitiesCard(canManage: canManage),
      exportPath: access.can(PermissionKeys.catalogueExport)
          ? 'bus-types'
          : null,
      importSpec: canManage
          ? ImportSpec(
              name: 'bus types',
              fields: const <FieldSpec>[
                TextSpec('key', AdminStrings.fieldKey, isRequired: true),
                ..._editFields,
              ],
              sampleRow: const <String>[
                'AC_SLEEPER',
                'AC Sleeper',
                'yes',
                'SLEEPER',
              ],
              save: (values) => repository.post('bus-types', values),
            )
          : null,
      emptyTitle: 'Nothing here yet',
      emptyMessage: 'New items will appear here.',
      filters: const <FilterSpec>[
        ChoiceFilter(
          'active',
          AdminStrings.fieldStatus,
          CatalogueLabels.activeFilter,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldName,
          (_, r) => textCell(r['name']),
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldKey,
          (_, r) => textCell(r['key']),
          text: (r) => plainText(r['key']),
        ),
        ColumnSpec(
          AdminStrings.fieldAc,
          (_, r) => Text(
            l10n.text(
              r['isAc'] == true ? AdminStrings.formYes : AdminStrings.formNo,
            ),
          ),
          text: (r) => l10n.text(
            r['isAc'] == true ? AdminStrings.formYes : AdminStrings.formNo,
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldBerthType,
          (_, r) => AbraStatusBadge(
            label: l10n.text(
              CatalogueLabels.berthTypes[r['berthType']] ??
                  AdminStrings.berthMixed,
            ),
            tone: AbraStatusTone.info,
          ),
          text: (r) => l10n.text(
            CatalogueLabels.berthTypes['${r['berthType']}'] ??
                AdminStrings.berthMixed,
          ),
        ),
        ColumnSpec(
          AdminStrings.opdBuses,
          (_, r) => Text('${r['busesCount'] ?? r['buses'] ?? 0}'),
          isNumeric: true,
          text: (r) => '${r['busesCount'] ?? r['buses'] ?? 0}',
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => StatusBadge.active(isActive: r['isActive'] == true),
          text: (r) => l10n.text(
            r['isActive'] == true
                ? AdminStrings.statusActive
                : AdminStrings.statusInactive,
          ),
        ),
      ],
      onCreate: canManage
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.busTypeCreateTitle),
              fields: const <FieldSpec>[
                TextSpec('key', AdminStrings.fieldKey, isRequired: true),
                ..._editFields,
              ],
              onSubmit: (values) => repository.post('bus-types', values),
            )
          : null,
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: 'bus-types',
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(AdminStrings.fieldName, nameOf(r)),
            DetailLine(AdminStrings.fieldKey, '${r['key']}'),
            DetailLine(AdminStrings.fieldAc, yesNo(l10n, r['isAc'])),
            DetailLine(
              AdminStrings.fieldBerthType,
              optionLabel(l10n, CatalogueLabels.berthTypes, r['berthType']),
            ),
            DetailLine(
              AdminStrings.fieldStatus,
              l10n.text(
                r['isActive'] == true
                    ? AdminStrings.statusActive
                    : AdminStrings.statusInactive,
              ),
            ),
          ],
        ),
        if (canManage) ...<RowAction>[
          RowAction(
            AdminStrings.actionEdit,
            Icons.edit_outlined,
            (context, record) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.busTypeEditTitle),
              fields: _editFields,
              initial: record,
              onSubmit: (values) =>
                  repository.put('bus-types/${record['id']}', values),
            ),
          ),
          activeToggleAction(ref, 'bus-types', record),
        ],
        if (canDelete)
          deleteAction(
            repository: repository,
            path: 'bus-types',
            nameOf: nameOf,
          ),
      ],
    );
  }
}
