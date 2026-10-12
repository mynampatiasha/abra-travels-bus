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
import '../widgets/record_actions.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Cities: the platform catalogue customers choose from.
class CitiesPage extends ConsumerWidget {
  const CitiesPage({super.key});

  static const _fields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    TextSpec('state', AdminStrings.fieldState, isRequired: true),
    TextSpec('countryCode', AdminStrings.fieldCountryCode),
    BoolSpec('isPopular', AdminStrings.fieldPopular),
    NumberSpec('sortOrder', AdminStrings.fieldSortOrder),
    NumberSpec('latitude', AdminStrings.fieldLatitude, allowDecimal: true),
    NumberSpec('longitude', AdminStrings.fieldLongitude, allowDecimal: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canManage = access.can(PermissionKeys.catalogueManage);
    final canDelete = access.can(PermissionKeys.catalogueDelete);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'cities',
      exportName: 'cities',
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
              name: 'cities',
              fields: _fields,
              sampleRow: const <String>[
                'Bengaluru',
                'Karnataka',
                'IN',
                'yes',
                '10',
                '12.9716',
                '77.5946',
              ],
              save: (values) => repository.post('cities', values),
            )
          : null,
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
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
          AdminStrings.fieldState,
          (_, r) => textCell(r['state']),
          text: (r) => plainText(r['state']),
        ),
        ColumnSpec(
          AdminStrings.fieldCountryCode,
          (_, r) => textCell(r['countryCode']),
          text: (r) => plainText(r['countryCode']),
        ),
        ColumnSpec(
          AdminStrings.fieldSlug,
          (_, r) => textCell(r['slug']),
          text: (r) => plainText(r['slug']),
        ),
        ColumnSpec(
          AdminStrings.fieldPopular,
          (context, r) => Text(
            l10n.text(
              r['isPopular'] == true
                  ? AdminStrings.formYes
                  : AdminStrings.formNo,
            ),
          ),
          text: (r) => l10n.text(
            r['isPopular'] == true ? AdminStrings.formYes : AdminStrings.formNo,
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
              title: l10n.text(AdminStrings.cityCreateTitle),
              fields: _fields,
              onSubmit: (values) => repository.post('cities', values),
            )
          : null,
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: 'cities',
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(AdminStrings.fieldName, nameOf(r)),
            DetailLine(AdminStrings.fieldState, '${r['state'] ?? ''}'),
            DetailLine(
              AdminStrings.fieldCountryCode,
              '${r['countryCode'] ?? ''}',
            ),
            DetailLine(AdminStrings.fieldSlug, '${r['slug'] ?? ''}'),
            DetailLine(AdminStrings.fieldPopular, yesNo(l10n, r['isPopular'])),
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
              title: l10n.text(AdminStrings.cityEditTitle),
              fields: _fields,
              initial: record,
              onSubmit: (values) =>
                  repository.put('cities/${record['id']}', values),
            ),
          ),
          activeToggleAction(ref, 'cities', record),
        ],
        if (canDelete)
          deleteAction(repository: repository, path: 'cities', nameOf: nameOf),
      ],
    );
  }
}
