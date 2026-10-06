import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
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
    final canManage = ref
        .watch(accessProvider)
        .can(PermissionKeys.catalogueManage);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'cities',
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
        ChoiceFilter(
          'active',
          AdminStrings.fieldStatus,
          CatalogueLabels.activeFilter,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(AdminStrings.fieldName, (_, r) => textCell(r['name'])),
        ColumnSpec(AdminStrings.fieldState, (_, r) => textCell(r['state'])),
        ColumnSpec(
          AdminStrings.fieldCountryCode,
          (_, r) => textCell(r['countryCode']),
        ),
        ColumnSpec(AdminStrings.fieldSlug, (_, r) => textCell(r['slug'])),
        ColumnSpec(
          AdminStrings.fieldPopular,
          (context, r) => Text(
            l10n.text(
              r['isPopular'] == true
                  ? AdminStrings.formYes
                  : AdminStrings.formNo,
            ),
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => StatusBadge.active(isActive: r['isActive'] == true),
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
      rowActions: canManage
          ? (record) => <RowAction>[
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
            ]
          : null,
    );
  }
}
