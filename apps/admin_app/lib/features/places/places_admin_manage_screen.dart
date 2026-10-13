import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/pages/cities_page.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/record_actions.dart';
import '../catalogue/widgets/resource_form.dart';
import '../catalogue/widgets/resource_page.dart';
import '../catalogue/widgets/server_import_dialog.dart';

// The admin "Cities and places" page (demo page `places`): three tabs, Places,
// Cities and Operator requests. Places and Cities use the catalogue lists;
// Operator requests are the place requests operators send from the client
// portal (`admin/place-requests`).

// ===== 1. MODELS =====

/// The tabs of the page, as the demo names them. `?tab=requests` opens the
/// third one (where a "Place request" notification leads).
enum PlacesTab { places, cities, requests }

/// What passengers do at a place, as the place form and the filter offer it.
const placeUses = <String, String>{
  'BOARDING': AdminStrings.placesUsedBoarding,
  'DROPPING': AdminStrings.placesUsedDropping,
  'BOTH': AdminStrings.placesUsedBoth,
};

/// The short words of the "Used for" badge.
const placeUseBadges = <String, String>{
  'BOARDING': AdminStrings.placesBadgeBoarding,
  'DROPPING': AdminStrings.placesBadgeDropping,
  'BOTH': AdminStrings.placesBadgeBoth,
};

/// How a place came into the list ("Added by").
const placeSources = <String, String>{
  'ADMIN': AdminStrings.placesSourceAdmin,
  'IMPORT': AdminStrings.placesSourceImport,
  'OPERATOR_REQUEST': AdminStrings.placesSourceRequest,
  'OPERATOR': AdminStrings.placesSourceOperator,
};

const placeRequestStatuses = <String, String>{
  'PENDING': AdminStrings.preqPending,
  'APPROVED': AdminStrings.preqApproved,
  'REJECTED': AdminStrings.preqRejected,
};

AbraStatusTone requestTone(String status) => switch (status) {
  'APPROVED' => AbraStatusTone.success,
  'REJECTED' => AbraStatusTone.danger,
  _ => AbraStatusTone.warning,
};

/// "5 min ago", "3 h ago", "2 days ago" as the demo shows when a request came.
String timeAgo(AbraLocalizations l10n, Object? iso, {DateTime? now}) {
  final at = DateTime.tryParse('${iso ?? ''}');
  if (at == null) return '';
  final minutes = (now ?? DateTime.now()).difference(at).inMinutes;
  if (minutes < 1) return l10n.text(AdminStrings.agoNow);
  if (minutes < 60) {
    return l10n.text(AdminStrings.agoMinutes, <String, Object?>{'n': minutes});
  }
  if (minutes < 24 * 60) {
    return l10n.text(AdminStrings.agoHours, <String, Object?>{
      'n': minutes ~/ 60,
    });
  }
  return l10n.text(AdminStrings.agoDays, <String, Object?>{
    'n': minutes ~/ (24 * 60),
  });
}

// ===== 2. STATE AND API =====

/// The numbers on the tabs: every place, every city, the requests waiting.
final placesTabCountsProvider = FutureProvider.autoDispose<Map<PlacesTab, int>>(
  (ref) async {
    // Reload together with the lists, after any change
    final repository = ref.watch(catalogueRepositoryProvider);
    final access = ref.watch(accessProvider);
    Future<int> total(String path) async =>
        (await repository.list(ResourceQuery(path, pageSize: 1))).total;
    final places = await total('locations');
    final cities = access.can(PermissionKeys.catalogueRead)
        ? await total('cities')
        : 0;
    final pending = access.can(PermissionKeys.catalogueRead)
        ? ((await repository.get(
                    'admin/place-requests/pending-count',
                  ))['pending']
                  as num? ??
              0)
        : 0;
    return <PlacesTab, int>{
      PlacesTab.places: places,
      PlacesTab.cities: cities,
      PlacesTab.requests: pending.toInt(),
    };
  },
);

// ===== 3. WIDGETS =====

/// The tab strip of the demo: underlined words with a grey count.
class PlacesTabStrip extends StatelessWidget {
  const PlacesTabStrip({
    required this.tabs,
    required this.current,
    required this.counts,
    required this.onSelect,
    super.key,
  });

  final List<PlacesTab> tabs;
  final PlacesTab current;
  final Map<PlacesTab, int>? counts;
  final ValueChanged<PlacesTab> onSelect;

  static const _labels = <PlacesTab, String>{
    PlacesTab.places: AdminStrings.placesTabPlaces,
    PlacesTab.cities: AdminStrings.placesTabCities,
    PlacesTab.requests: AdminStrings.placesTabRequests,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AbraColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final tab in tabs)
              Semantics(
                selected: tab == current,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(tab),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AbraSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == current
                              ? AbraColors.blue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          l10n.text(_labels[tab]!),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tab == current
                                ? AbraColors.deepBlue
                                : AbraColors.textSecondary,
                            fontWeight: tab == current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        if (counts?[tab] != null) ...<Widget>[
                          const SizedBox(width: AbraSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: AbraColors.navyContainer,
                              borderRadius: BorderRadius.all(
                                Radius.circular(99),
                              ),
                            ),
                            child: Text(
                              '${counts![tab]}',
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
              ),
          ],
        ),
      ),
    );
  }
}

/// A name with a smaller grey line under it (place and its address).
Widget twoLineCell(Object? title, Object? subtitle) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Text(
      '${title ?? ''}',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    if ('${subtitle ?? ''}'.isNotEmpty)
      Text(
        '$subtitle',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
      ),
  ],
);

/// The Places tab: Search, City, Used for and Status; Place, City, Used for,
/// Added by, Trips using it, Status.
class PlacesListTab extends ConsumerWidget {
  const PlacesListTab({super.key});

  static const _fields = <FieldSpec>[
    TextSpec('name', AdminStrings.placesFieldName, isRequired: true),
    RefSpec(
      'cityId',
      AdminStrings.fieldCity,
      'cities?active=true',
      nameOf,
      isRequired: true,
    ),
    TextSpec(
      'address',
      AdminStrings.fieldAddress,
      isRequired: true,
      fullWidth: true,
    ),
    TextSpec('landmark', AdminStrings.fieldLandmark, clearable: true),
    ChoiceSpec('usedFor', AdminStrings.placesColUsedFor, placeUses),
    NumberSpec('latitude', AdminStrings.fieldLatitude, allowDecimal: true),
    NumberSpec('longitude', AdminStrings.fieldLongitude, allowDecimal: true),
    TextSpec('contactPhone', AdminStrings.fieldContactPhone, clearable: true),
    TextSpec(
      'instructions',
      AdminStrings.placesFieldInstructions,
      clearable: true,
      fullWidth: true,
      maxLines: 2,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final repository = ref.read(catalogueRepositoryProvider);
    final canManage = access.can(PermissionKeys.routesUpdate);
    String label(Map<String, String> labels, Object? value) =>
        optionLabel(l10n, labels, value);

    return ResourcePage(
      path: 'locations',
      createLabelKey: AdminStrings.placesAdd,
      exportPath: access.can(PermissionKeys.catalogueExport)
          ? 'locations'
          : null,
      serverImport: access.can(PermissionKeys.catalogueManage)
          ? const ServerImport('locations', AdminStrings.impsWhatPlaces)
          : null,
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
        RefFilter('cityId', AdminStrings.fieldCity, 'cities', nameOf),
        ChoiceFilter('usedFor', AdminStrings.placesColUsedFor, placeUseBadges),
        ChoiceFilter(
          'active',
          AdminStrings.fieldStatus,
          CatalogueLabels.activeFilter,
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.placesColPlace,
          (_, r) => twoLineCell(r['name'], r['address']),
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldCity,
          (_, r) => LookupName('cities', r['cityId'] as String?),
        ),
        ColumnSpec(
          AdminStrings.placesColUsedFor,
          (_, r) => AbraStatusBadge(
            label: label(placeUseBadges, r['usedFor']),
            tone: AbraStatusTone.info,
          ),
          text: (r) => label(placeUses, r['usedFor']),
        ),
        ColumnSpec(
          AdminStrings.placesColAddedBy,
          (_, r) => Text(label(placeSources, r['source'])),
          text: (r) => label(placeSources, r['source']),
        ),
        ColumnSpec(
          AdminStrings.placesColTrips,
          (_, r) => Text('${r['tripsUsing'] ?? 0}'),
          isNumeric: true,
          text: (r) => '${r['tripsUsing'] ?? 0}',
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
      onCreate: access.can(PermissionKeys.routesCreate)
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.placesAdd),
              fields: _fields,
              columns: 2,
              width: 760,
              initial: const <String, Object?>{'usedFor': 'BOTH'},
              onSubmit: (values) => repository.post('locations', values),
            )
          : null,
      rowActions: (record) => <RowAction>[
        viewAction(
          repository: repository,
          path: 'locations',
          titleOf: nameOf,
          linesOf: (l10n, r) => <DetailLine>[
            DetailLine(AdminStrings.placesColPlace, nameOf(r)),
            DetailLine(AdminStrings.fieldAddress, plainText(r['address'])),
            DetailLine(AdminStrings.fieldLandmark, plainText(r['landmark'])),
            DetailLine(
              AdminStrings.placesColUsedFor,
              optionLabel(l10n, placeUses, r['usedFor']),
            ),
            DetailLine(
              AdminStrings.placesColAddedBy,
              optionLabel(l10n, placeSources, r['source']),
            ),
            DetailLine(
              AdminStrings.fieldContactPhone,
              plainText(r['contactPhone']),
            ),
            DetailLine(
              AdminStrings.placesFieldInstructions,
              plainText(r['instructions']),
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
              title: l10n.text(AdminStrings.placesEdit),
              fields: <FieldSpec>[
                for (final field in _fields)
                  if (field.key != 'cityId') field,
              ],
              columns: 2,
              width: 760,
              initial: record,
              onSubmit: (values) =>
                  repository.put('locations/${record['id']}', values),
            ),
          ),
          activeToggleAction(ref, 'locations', record),
        ],
        if (access.can(PermissionKeys.catalogueDelete))
          deleteAction(
            repository: repository,
            path: 'locations',
            nameOf: nameOf,
          ),
      ],
    );
  }
}

/// The Operator requests tab: Search and Status; Requested place, City,
/// Operator, Requested, Status; Approve and Reject while pending.
class PlaceRequestsTab extends ConsumerWidget {
  const PlaceRequestsTab({super.key});

  static const path = 'admin/place-requests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final repository = ref.read(catalogueRepositoryProvider);
    final canDecide = access.can(PermissionKeys.catalogueManage);

    /// Runs a decision and says what happened in the demo's words.
    Future<bool> decide(
      BuildContext context,
      Future<void> Function() action,
      String doneKey,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final container = ProviderScope.containerOf(context);
      try {
        await action();
      } on Object catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(failureText(l10n, error))),
        );
        return false;
      }
      container
        ..invalidate(resourceListProvider)
        ..invalidate(placesTabCountsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.text(doneKey))));
      return false;
    }

    return ResourcePage(
      path: path,
      exportPath: access.can(PermissionKeys.catalogueExport) ? path : null,
      filters: const <FilterSpec>[
        SearchFilter('query', AdminStrings.listSearch),
        ChoiceFilter('status', AdminStrings.fieldStatus, placeRequestStatuses),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.preqColPlace,
          (_, r) => twoLineCell(r['name'], r['address']),
          text: (r) => plainText(r['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldCity,
          (_, r) => Text(plainText(r['cityName'])),
          text: (r) => plainText(r['cityName']),
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
            DetailLine(AdminStrings.fieldCity, plainText(r['cityName'])),
            DetailLine(AdminStrings.preqColPlace, nameOf(r)),
            DetailLine(AdminStrings.fieldAddress, plainText(r['address'])),
            DetailLine(AdminStrings.fieldLandmark, plainText(r['landmark'])),
            DetailLine(
              AdminStrings.fieldStatus,
              optionLabel(l10n, placeRequestStatuses, r['status']),
            ),
            if (r['reason'] != null)
              DetailLine(AdminStrings.fieldReason, plainText(r['reason'])),
          ],
        ),
        if (canDecide && record['status'] == 'PENDING') ...<RowAction>[
          RowAction(
            AdminStrings.preqApprove,
            Icons.check,
            (context, r) => decide(
              context,
              () => repository.post('$path/${r['id']}/approve'),
              AdminStrings.preqApprovedDone,
            ),
          ),
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
            if (rejected) container.invalidate(placesTabCountsProvider);
            return rejected;
          }),
        ],
      ],
    );
  }
}

// ===== 4. THE SCREEN =====

/// Cities and places: Places, Cities and Operator requests, as in the demo.
class PlacesAdminManageScreen extends ConsumerStatefulWidget {
  const PlacesAdminManageScreen({super.key});

  @override
  ConsumerState<PlacesAdminManageScreen> createState() =>
      _PlacesAdminManageScreenState();
}

class _PlacesAdminManageScreenState
    extends ConsumerState<PlacesAdminManageScreen> {
  PlacesTab? _tab;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessProvider);
    final canSeeCatalogue = access.can(PermissionKeys.catalogueRead);
    final tabs = <PlacesTab>[
      PlacesTab.places,
      if (canSeeCatalogue) ...<PlacesTab>[PlacesTab.cities, PlacesTab.requests],
    ];
    final asked = GoRouterState.of(context).uri.queryParameters['tab'];
    final fromAddress = PlacesTab.values
        .where((tab) => tab.name == asked)
        .firstOrNull;
    final current =
        <PlacesTab?>[
          _tab,
          fromAddress,
        ].whereType<PlacesTab>().where(tabs.contains).firstOrNull ??
        tabs.first;
    final counts = ref.watch(placesTabCountsProvider).value;
    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? AbraSpacing.md : AbraSpacing.xl,
            AbraSpacing.md,
            isCompact ? AbraSpacing.md : AbraSpacing.xl,
            0,
          ),
          child: PlacesTabStrip(
            tabs: tabs,
            current: current,
            counts: counts,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        Expanded(
          child: switch (current) {
            PlacesTab.places => const PlacesListTab(),
            PlacesTab.cities => const CitiesPage(),
            PlacesTab.requests => const PlaceRequestsTab(),
          },
        ),
      ],
    );
  }
}
