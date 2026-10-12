import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/import_dialog.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Bus types: the kinds of bus operators register and customers filter by.
class BusTypesPage extends ConsumerWidget {
  const BusTypesPage({super.key});

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
    final canManage = ref
        .watch(accessProvider)
        .can(PermissionKeys.catalogueManage);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'bus-types',
      exportName: 'bus-types',
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.statusActive,
          <String, String>{'active': 'true'},
          Icons.check_circle_outline,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.statusInactive,
          <String, String>{'active': 'false'},
          Icons.pause_circle_outline,
          AbraColors.navySecondary,
        ),
      ],
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
      filters: const <FilterSpec>[
        ChoiceFilter(
          'active',
          AdminStrings.fieldStatus,
          CatalogueLabels.activeFilter,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldKey,
          (_, r) => textCell(r['key']),
          text: (r) => plainText(r['key']),
        ),
        ColumnSpec(
          AdminStrings.fieldName,
          (_, r) => textCell(r['name']),
          text: (r) => plainText(r['name']),
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
          (_, r) => Text(
            l10n.text(
              CatalogueLabels.berthTypes[r['berthType']] ??
                  AdminStrings.berthMixed,
            ),
          ),
          text: (r) => l10n.text(
            CatalogueLabels.berthTypes['${r['berthType']}'] ??
                AdminStrings.berthMixed,
          ),
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
      rowActions: canManage
          ? (record) => <RowAction>[
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
            ]
          : null,
    );
  }
}
