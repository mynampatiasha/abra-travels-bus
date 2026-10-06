import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Routes of the operators the user may see.
class RoutesPage extends ConsumerWidget {
  const RoutesPage({super.key});

  static const _stops = RowsSpec('stops', AdminStrings.fieldStops, <FieldSpec>[
    RefSpec(
      'cityId',
      AdminStrings.fieldCity,
      'cities?active=true',
      nameOf,
      isRequired: true,
    ),
    NumberSpec(
      'offsetMinutes',
      AdminStrings.fieldOffsetMinutes,
      isRequired: true,
    ),
  ]);

  static const _editFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    NumberSpec(
      'estimatedDurationMinutes',
      AdminStrings.fieldDuration,
      isRequired: true,
    ),
    NumberSpec('distanceKm', AdminStrings.fieldDistanceKm, allowDecimal: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    // Choosing cities needs the platform city list.
    final canListCities = access.can(PermissionKeys.catalogueRead);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'routes',
      filters: <FilterSpec>[
        if (isPlatform)
          const RefFilter(
            'operatorId',
            AdminStrings.fieldOperator,
            'operators',
            operatorNameOf,
          ),
        const ChoiceFilter(
          'status',
          AdminStrings.fieldStatus,
          CatalogueLabels.routeStatuses,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(AdminStrings.fieldName, (_, r) => textCell(r['name'])),
        if (isPlatform)
          ColumnSpec(
            AdminStrings.fieldOperator,
            (_, r) => LookupName(
              'operators',
              r['operatorId'] as String?,
              labelOf: operatorNameOf,
            ),
          ),
        if (canListCities) ...<ColumnSpec>[
          ColumnSpec(
            AdminStrings.fieldOrigin,
            (_, r) => LookupName('cities', r['originCityId'] as String?),
          ),
          ColumnSpec(
            AdminStrings.fieldDestination,
            (_, r) => LookupName('cities', r['destinationCityId'] as String?),
          ),
        ],
        ColumnSpec(
          AdminStrings.fieldDuration,
          (_, r) => textCell(r['estimatedDurationMinutes']),
          isNumeric: true,
        ),
        ColumnSpec(
          AdminStrings.fieldStops,
          (_, r) => textCell((r['stops'] as List<Object?>?)?.length ?? 0),
          isNumeric: true,
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) => StatusBadge(
            r['status']! as String,
            CatalogueLabels.routeStatuses,
          ),
        ),
      ],
      onCreate: access.can(PermissionKeys.routesCreate) && canListCities
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.routeCreateTitle),
              fields: <FieldSpec>[
                if (isPlatform)
                  const RefSpec(
                    'operatorId',
                    AdminStrings.fieldOperator,
                    'operators',
                    operatorNameOf,
                    isRequired: true,
                  ),
                const RefSpec(
                  'originCityId',
                  AdminStrings.fieldOrigin,
                  'cities?active=true',
                  nameOf,
                  isRequired: true,
                ),
                const RefSpec(
                  'destinationCityId',
                  AdminStrings.fieldDestination,
                  'cities?active=true',
                  nameOf,
                  isRequired: true,
                ),
                ..._editFields,
                _stops,
              ],
              onSubmit: (values) => repository.post('routes', values),
            )
          : null,
      rowActions: access.can(PermissionKeys.routesUpdate)
          ? (record) {
              final isActive = record['status'] == 'ACTIVE';
              return <RowAction>[
                RowAction(
                  AdminStrings.actionEdit,
                  Icons.edit_outlined,
                  (context, record) => showResourceForm(
                    context,
                    title: l10n.text(AdminStrings.routeEditTitle),
                    fields: <FieldSpec>[
                      ..._editFields,
                      if (canListCities) _stops,
                    ],
                    initial: record,
                    onSubmit: (values) =>
                        repository.put('routes/${record['id']}', values),
                  ),
                ),
                RowAction(
                  isActive
                      ? AdminStrings.actionDisable
                      : AdminStrings.actionEnable,
                  isActive ? Icons.block : Icons.check_circle_outline,
                  (context, record) async {
                    final confirmed = await showAbraConfirmDialog(
                      context,
                      title: l10n.text(
                        isActive
                            ? AdminStrings.confirmDisableTitle
                            : AdminStrings.confirmEnableTitle,
                        <String, Object?>{'name': nameOf(record)},
                      ),
                      message: l10n.text(AdminStrings.confirmStatusMessage),
                      confirmLabel: l10n.text(
                        isActive
                            ? AdminStrings.actionDisable
                            : AdminStrings.actionEnable,
                      ),
                      isDestructive: isActive,
                    );
                    if (confirmed != true) return false;
                    await repository.post(
                      'routes/${record['id']}/status',
                      <String, Object?>{
                        'status': isActive ? 'INACTIVE' : 'ACTIVE',
                      },
                    );
                    return true;
                  },
                ),
              ];
            }
          : null,
    );
  }
}
