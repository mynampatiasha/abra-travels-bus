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

/// Required documents: what a bus owner must upload for the company and for
/// each bus before the platform approves them.
class DocumentTypesPage extends ConsumerWidget {
  const DocumentTypesPage({super.key});

  /// The key and what the document is asked for are permanent, so they are
  /// only on the create form.
  static const _createOnlyFields = <FieldSpec>[
    TextSpec('key', AdminStrings.fieldKey, isRequired: true),
    ChoiceSpec(
      'appliesTo',
      AdminStrings.fieldAppliesTo,
      CatalogueLabels.documentSubjects,
      isRequired: true,
    ),
  ];

  static const _editFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    TextSpec('instructions', AdminStrings.fieldInstructions, maxLines: 3),
    BoolSpec('isRequired', AdminStrings.fieldRequired),
    BoolSpec('requiresExpiry', AdminStrings.fieldRequiresExpiry),
    MultiChoiceSpec('allowedMimeTypes', AdminStrings.fieldFileTypes, <String>[
      'application/pdf',
      'image/jpeg',
      'image/png',
    ], _fileTypeLabel),
    NumberSpec(
      'maxFileSizeMb',
      AdminStrings.fieldMaxFileSize,
      isRequired: true,
    ),
    NumberSpec('maxFiles', AdminStrings.fieldMaxFiles, isRequired: true),
    NumberSpec('sortOrder', AdminStrings.fieldSortOrder),
  ];

  static String _fileTypeLabel(String mimeType) =>
      CatalogueLabels.documentFileTypes[mimeType] ?? mimeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final canManage = access.can(PermissionKeys.documentsManage);
    final canDelete = access.can(PermissionKeys.documentsDelete);
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'document-types',
      exportName: 'document-types',
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
        StatSpec(
          AdminStrings.subjectOperator,
          <String, String>{'appliesTo': 'OPERATOR'},
          Icons.business_outlined,
          AbraColors.blueDark,
        ),
        StatSpec(
          AdminStrings.subjectBus,
          <String, String>{'appliesTo': 'BUS'},
          Icons.directions_bus_outlined,
          AbraColors.blue,
        ),
      ],
      importSpec: canManage
          ? ImportSpec(
              name: 'required documents',
              fields: const <FieldSpec>[..._createOnlyFields, ..._editFields],
              sampleRow: const <String>[
                'ROAD_TAX',
                'BUS',
                'Road tax receipt',
                'Latest road tax receipt of the bus',
                'yes',
                'yes',
                'application/pdf;image/jpeg',
                '5',
                '1',
                '100',
              ],
              save: (values) => repository.post('document-types', values),
            )
          : null,
      filters: const <FilterSpec>[
        ChoiceFilter(
          'appliesTo',
          AdminStrings.fieldAppliesTo,
          CatalogueLabels.documentSubjects,
        ),
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
          AdminStrings.fieldAppliesTo,
          (_, r) => Text(
            l10n.text(
              CatalogueLabels.documentSubjects[r['appliesTo']] ??
                  AdminStrings.subjectBus,
            ),
          ),
          text: (r) => l10n.text(
            CatalogueLabels.documentSubjects['${r['appliesTo']}'] ??
                AdminStrings.subjectBus,
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldRequired,
          (_, r) => Text(
            l10n.text(
              r['isRequired'] == true
                  ? AdminStrings.formYes
                  : AdminStrings.formNo,
            ),
          ),
          text: (r) => l10n.text(
            r['isRequired'] == true
                ? AdminStrings.formYes
                : AdminStrings.formNo,
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldRequiresExpiry,
          (_, r) => Text(
            l10n.text(
              r['requiresExpiry'] == true
                  ? AdminStrings.formYes
                  : AdminStrings.formNo,
            ),
          ),
          text: (r) => l10n.text(
            r['requiresExpiry'] == true
                ? AdminStrings.formYes
                : AdminStrings.formNo,
          ),
        ),
        ColumnSpec(
          AdminStrings.fieldFileTypes,
          (_, r) => Text(
            <String>[
              for (final type
                  in (r['allowedMimeTypes'] as List<Object?>? ??
                      const <Object?>[]))
                _fileTypeLabel('$type'),
            ].join(', '),
          ),
          text: (r) => [
            for (final type
                in (r['allowedMimeTypes'] as List<Object?>? ??
                    const <Object?>[]))
              CatalogueLabels.documentFileTypes['$type'] ?? '$type',
          ].join(', '),
        ),
        ColumnSpec(
          AdminStrings.fieldMaxFiles,
          (_, r) => textCell(r['maxFiles']),
          isNumeric: true,
          text: (r) => plainText(r['maxFiles']),
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
              title: l10n.text(AdminStrings.documentTypeCreateTitle),
              fields: const <FieldSpec>[..._createOnlyFields, ..._editFields],
              initial: const <String, Object?>{
                'isRequired': true,
                'requiresExpiry': false,
                'allowedMimeTypes': <String>[
                  'application/pdf',
                  'image/jpeg',
                  'image/png',
                ],
                'maxFileSizeMb': 5,
                'maxFiles': 1,
                'sortOrder': 0,
              },
              onSubmit: (values) => repository.post('document-types', values),
            )
          : null,
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: 'document-types',
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(AdminStrings.fieldName, nameOf(r)),
            DetailLine(AdminStrings.fieldKey, '${r['key'] ?? ''}'),
            DetailLine(
              AdminStrings.fieldAppliesTo,
              l10n.text(
                r['appliesTo'] == 'BUS'
                    ? AdminStrings.subjectBus
                    : AdminStrings.subjectOperator,
              ),
            ),
            DetailLine(
              AdminStrings.fieldRequired,
              yesNo(l10n, r['isRequired']),
            ),
            DetailLine(
              AdminStrings.fieldRequiresExpiry,
              yesNo(l10n, r['requiresExpiry']),
            ),
            DetailLine(
              AdminStrings.fieldFileTypes,
              ((r['allowedMimeTypes'] as List<Object?>?) ?? const <Object?>[])
                  .join(', '),
            ),
            DetailLine(
              AdminStrings.fieldMaxFileSize,
              '${r['maxFileSizeMb'] ?? ''}',
            ),
            DetailLine(AdminStrings.fieldMaxFiles, '${r['maxFiles'] ?? ''}'),
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
        if (canManage) ...<RowAction>[
          RowAction(
            AdminStrings.actionEdit,
            Icons.edit_outlined,
            (context, record) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.documentTypeEditTitle),
              fields: _editFields,
              initial: record,
              onSubmit: (values) =>
                  repository.put('document-types/${record['id']}', values),
            ),
          ),
          activeToggleAction(ref, 'document-types', record),
        ],
        if (canDelete)
          deleteAction(
            repository: repository,
            path: 'document-types',
            nameOf: nameOf,
          ),
      ],
    );
  }
}
