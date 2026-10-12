import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/record_actions.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Boarding and dropping locations. Shared locations belong to the platform
/// and are read-only for operator staff; an operator's own locations are
/// managed by that operator.
class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  static const _detailFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    TextSpec(
      'address',
      AdminStrings.fieldAddress,
      isRequired: true,
      maxLines: 2,
    ),
    TextSpec('landmark', AdminStrings.fieldLandmark, clearable: true),
    TextSpec(
      'instructions',
      AdminStrings.fieldInstructions,
      clearable: true,
      maxLines: 2,
    ),
    TextSpec('contactPhone', AdminStrings.fieldContactPhone, clearable: true),
    NumberSpec('latitude', AdminStrings.fieldLatitude, allowDecimal: true),
    NumberSpec('longitude', AdminStrings.fieldLongitude, allowDecimal: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    final canUpdate = access.can(PermissionKeys.routesUpdate);
    final canDelete = access.can(PermissionKeys.catalogueDelete);
    final repository = ref.read(catalogueRepositoryProvider);
    // Operator staff see the cities of the locations they can use through
    // the locations themselves; the city list is platform catalogue.
    final canListCities = access.can(PermissionKeys.catalogueRead);

    /// Shared locations can be changed by platform staff only; the backend
    /// answers "not found" to anyone else.
    bool canChange(JsonMap record) =>
        canUpdate && (isPlatform || record['operatorId'] != null);

    return ResourcePage(
      path: 'locations',
      exportName: 'locations',
      filters: <FilterSpec>[
        if (canListCities)
          const RefFilter(
            'cityId',
            AdminStrings.fieldCity,
            'cities?active=true',
            nameOf,
          ),
        const ChoiceFilter(
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
        if (canListCities)
          ColumnSpec(
            AdminStrings.fieldCity,
            (_, r) => LookupName('cities', r['cityId'] as String?),
          ),
        ColumnSpec(
          AdminStrings.fieldAddress,
          (_, r) => textCell(r['address']),
          text: (r) => plainText(r['address']),
        ),
        ColumnSpec(
          AdminStrings.fieldOwner,
          (_, r) => Text(
            l10n.text(
              r['operatorId'] == null
                  ? AdminStrings.ownerShared
                  : AdminStrings.ownerOperator,
            ),
          ),
          text: (r) => l10n.text(
            r['operatorId'] == null
                ? AdminStrings.ownerShared
                : AdminStrings.ownerOperator,
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
      onCreate: access.can(PermissionKeys.routesCreate) && canListCities
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.locationCreateTitle),
              fields: <FieldSpec>[
                const RefSpec(
                  'cityId',
                  AdminStrings.fieldCity,
                  'cities?active=true',
                  nameOf,
                  isRequired: true,
                ),
                // Only platform staff choose an operator; left empty the
                // location is shared by all operators.
                if (isPlatform)
                  const RefSpec(
                    'operatorId',
                    AdminStrings.fieldOperator,
                    'operators',
                    operatorNameOf,
                  ),
                ..._detailFields,
              ],
              onSubmit: (values) => repository.post('locations', values),
            )
          : null,
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: 'locations',
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(AdminStrings.fieldName, nameOf(r)),
            DetailLine(AdminStrings.fieldAddress, '${r['address'] ?? ''}'),
            DetailLine(
              AdminStrings.fieldOwner,
              l10n.text(
                r['operatorId'] == null
                    ? AdminStrings.ownerShared
                    : AdminStrings.ownerOperator,
              ),
            ),
            DetailLine(
              AdminStrings.fieldInstructions,
              '${r['instructions'] ?? ''}',
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
        if (canUpdate && canChange(record)) ...<RowAction>[
          RowAction(
            AdminStrings.actionEdit,
            Icons.edit_outlined,
            (context, record) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.locationEditTitle),
              fields: _detailFields,
              initial: record,
              onSubmit: (values) =>
                  repository.put('locations/${record['id']}', values),
            ),
          ),
          activeToggleAction(ref, 'locations', record),
        ],
        if (canDelete && canChange(record))
          deleteAction(
            repository: repository,
            path: 'locations',
            nameOf: nameOf,
          ),
      ],
    );
  }
}
