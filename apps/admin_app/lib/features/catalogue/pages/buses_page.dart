import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

/// Buses of the operators the user may see.
class BusesPage extends ConsumerWidget {
  const BusesPage({super.key});

  static const _editFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    RefSpec(
      'busTypeId',
      AdminStrings.fieldBusType,
      'bus-types?active=true',
      nameOf,
      isRequired: true,
    ),
    NumberSpec(
      'seatCapacity',
      AdminStrings.fieldSeatCapacity,
      isRequired: true,
    ),
    MultiChoiceSpec(
      'amenities',
      AdminStrings.fieldAmenities,
      CatalogueLabels.amenities,
      CatalogueLabels.readable,
      choicesPath: 'amenities',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    final canUpdate = access.can(PermissionKeys.busesUpdate);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'buses',
      exportName: 'buses',
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.busActive,
          <String, String>{'status': 'ACTIVE'},
          Icons.directions_bus_outlined,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.operatorPending,
          <String, String>{'status': 'PENDING_APPROVAL'},
          Icons.hourglass_top,
          AbraColors.orangeDark,
        ),
        StatSpec(
          AdminStrings.busMaintenance,
          <String, String>{'status': 'MAINTENANCE'},
          Icons.build_outlined,
          AbraColors.navySecondary,
        ),
      ],
      filters: <FilterSpec>[
        // Offered to platform staff only. Operator staff have no operator to
        // choose: the backend returns their own buses whatever is asked.
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
          CatalogueLabels.busStatuses,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldName,
          (_, r) => textCell(r['name']),
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldRegistration,
          (_, r) => textCell(r['registrationNumber']),
          text: (r) => plainText(r['registrationNumber']),
        ),
        if (isPlatform)
          ColumnSpec(
            AdminStrings.fieldOperator,
            (_, r) => LookupName(
              'operators',
              r['operatorId'] as String?,
              labelOf: operatorNameOf,
            ),
          ),
        ColumnSpec(
          AdminStrings.fieldBusType,
          (_, r) => LookupName('bus-types', r['busTypeId'] as String?),
        ),
        ColumnSpec(
          AdminStrings.fieldSeatCapacity,
          (_, r) => textCell(r['seatCapacity']),
          isNumeric: true,
          text: (r) => plainText(r['seatCapacity']),
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) =>
              StatusBadge(r['status']! as String, CatalogueLabels.busStatuses),
          text: (r) => CatalogueLabels.readable('${r['status']}'),
        ),
      ],
      onCreate: access.can(PermissionKeys.busesCreate)
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.busCreateTitle),
              fields: <FieldSpec>[
                if (isPlatform)
                  const RefSpec(
                    'operatorId',
                    AdminStrings.fieldOperator,
                    'operators',
                    operatorNameOf,
                    isRequired: true,
                  ),
                const TextSpec(
                  'registrationNumber',
                  AdminStrings.fieldRegistration,
                  isRequired: true,
                ),
                ..._editFields,
              ],
              onSubmit: (values) => repository.post('buses', values),
            )
          : null,
      rowActions: canUpdate
          ? (record) => <RowAction>[
              RowAction(
                AdminStrings.actionEdit,
                Icons.edit_outlined,
                (context, record) => showResourceForm(
                  context,
                  title: l10n.text(AdminStrings.busEditTitle),
                  fields: _editFields,
                  initial: record,
                  onSubmit: (values) =>
                      repository.put('buses/${record['id']}', values),
                ),
              ),
              if (record['status'] != 'RETIRED')
                RowAction(
                  AdminStrings.actionChangeStatus,
                  Icons.build_circle_outlined,
                  (context, record) => showStatusForm(
                    context,
                    ref,
                    title: l10n.text(AdminStrings.busStatusTitle),
                    path: 'buses/${record['id']}/status',
                    options: CatalogueLabels.busStatuses,
                    reasonRequired: false,
                    current: record['status'] as String?,
                  ),
                ),
            ]
          : null,
    );
  }
}
