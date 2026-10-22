import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../app/providers.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/record_actions.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';
import '../widgets/server_import_dialog.dart';

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
      exportPath: access.can(PermissionKeys.catalogueExport) ? 'cities' : null,
      serverImport: canManage
          ? const ServerImport('cities', AdminStrings.impsWhatCities)
          : null,
      emptyTitle: 'Nothing here yet',
      emptyMessage: 'New items will appear here.',
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
        SearchFilter('state', AdminStrings.fieldState),
        ChoiceFilter(
          'active',
          AdminStrings.fieldStatus,
          CatalogueLabels.activeFilter,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.fieldName,
          (_, r) {
            final te = r['te'] as String?;
            final hi = r['hi'] as String?;
            final sub = [
              if (te != null && te.isNotEmpty) te,
              if (hi != null && hi.isNotEmpty) hi,
            ].join(' ');
            return sub.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${r['name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        sub,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : textCell(r['name']);
          },
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldState,
          (_, r) => textCell(r['state']),
          text: (r) => plainText(r['state']),
        ),
        ColumnSpec(
          AdminStrings.placesTabPlaces,
          (_, r) => Text('${r['placesCount'] ?? r['places'] ?? 0}'),
          isNumeric: true,
          text: (r) => '${r['placesCount'] ?? r['places'] ?? 0}',
        ),
        ColumnSpec(
          AdminStrings.fieldPopular,
          (context, r) => Text(
            r['isPopular'] == true ? l10n.text(AdminStrings.formYes) : '-',
          ),
          text: (r) => r['isPopular'] == true
              ? l10n.text(AdminStrings.formYes)
              : '-',
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
