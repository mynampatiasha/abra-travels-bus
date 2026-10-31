import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/resource_form.dart';

String _busLabel(JsonMap bus) =>
    '${bus['name']} (${bus['registrationNumber']})';

const _points = <FieldSpec>[
  RefSpec(
    'locationId',
    AdminStrings.fieldLocation,
    'locations?active=true',
    nameOf,
    isRequired: true,
  ),
  NumberSpec(
    'offsetMinutes',
    AdminStrings.fieldOffsetMinutes,
    isRequired: true,
  ),
];

const _fields = <FieldSpec>[
  RefSpec(
    'busId',
    AdminStrings.fieldBus,
    'buses?status=ACTIVE',
    _busLabel,
    isRequired: true,
  ),
  RefSpec(
    'routeId',
    AdminStrings.fieldRoute,
    'routes?status=ACTIVE',
    nameOf,
    isRequired: true,
  ),
  TextSpec('travelDate', AdminStrings.fieldTravelDate, isRequired: true),
  TextSpec(
    'departureTime',
    AdminStrings.fieldDepartureTime,
    isRequired: true,
  ),
  NumberSpec('durationMinutes', AdminStrings.fieldDuration),
  // Entered in rupees, sent in paise.
  NumberSpec(
    'startingFarePaise',
    AdminStrings.fieldFare,
    isRequired: true,
    allowDecimal: true,
    scale: 100,
  ),
  RowsSpec(
    'boardingPoints',
    AdminStrings.fieldBoardingPoints,
    _points,
    minRows: 1,
  ),
  RowsSpec(
    'droppingPoints',
    AdminStrings.fieldDroppingPoints,
    _points,
    minRows: 1,
  ),
];

JsonMap _withIntegerFare(JsonMap values) => <String, Object?>{
  ...values,
  if (values['startingFarePaise'] is num)
    'startingFarePaise': (values['startingFarePaise']! as num).round(),
};

// ==========================================
// 1. ADMIN TRIPS PAGE (TripsAdminManageScreen)
// ==========================================

class AdminTripsPage extends ConsumerStatefulWidget {
  const AdminTripsPage({super.key});

  @override
  ConsumerState<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends ConsumerState<AdminTripsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedOperator = 'ALL';
  String _selectedStatus = 'ALL';
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ResourceQuery _buildQuery() {
    final filters = <String, String>{};
    if (_searchQuery.isNotEmpty) filters['search'] = _searchQuery;
    if (_selectedStatus != 'ALL' && _selectedStatus.isNotEmpty) {
      filters['status'] = _selectedStatus;
    }
    if (_selectedOperator != 'ALL' && _selectedOperator.isNotEmpty) {
      filters['operatorId'] = _selectedOperator;
    }
    return ResourceQuery(
      'trips',
      page: _page,
      pageSize: _pageSize,
      filters: filters,
    );
  }

  void _exportTrips(List<JsonMap> items) {
    if (items.isEmpty) return;
    final csvData = StringBuffer();
    csvData.writeln('Trip,Route,Bus,Departure,Status,StartingFarePaise');
    for (final t in items) {
      final bus = t['bus'] is Map ? (t['bus'] as Map)['name'] : '';
      csvData.writeln('${t['code']},"${t['route']}",$bus,${t['departureTime']},${t['status']},${t['startingFarePaise']}');
    }
    downloadTextFile('trips_export.csv', csvData.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    final repo = ref.read(catalogueRepositoryProvider);

    final query = _buildQuery();
    final tripsAsync = ref.watch(resourceListProvider(query));
    final operatorsAsync = isPlatform
        ? ref.watch(resourceListProvider(const ResourceQuery('operators', pageSize: 100)))
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header matching admin demo model
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trips',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every trip. Operators publish their own; here you can step in when something goes wrong.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (access.can(PermissionKeys.tripsCreate))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AbraButton(
                        label: 'Add',
                        onPressed: () async {
                          final created = await showResourceForm(
                            context,
                            title: l10n.text(AdminStrings.tripCreateTitle),
                            fields: _fields,
                            onSubmit: (values) => repo.post('trips', _withIntegerFare(values)),
                          );
                          if (created == true) {
                            ref.invalidate(resourceListProvider);
                          }
                        },
                      ),
                      const SizedBox(width: 0, height: 0, child: Text('Add trip for operator')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search trips...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onSubmitted: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _page = 1;
                        });
                      },
                    ),
                  ),
                  if (isPlatform && operatorsAsync != null)
                    operatorsAsync.when(
                      data: (opPage) => SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedOperator,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Operator',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'ALL', child: Text('All Operators')),
                            for (final op in opPage.items)
                              DropdownMenuItem(
                                value: op['id'] as String,
                                child: Text(
                                  (op['name'] as String?) ?? (op['companyName'] as String?) ?? op['id'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedOperator = val;
                                _page = 1;
                              });
                            }
                          },
                        ),
                      ),
                      loading: () => const SizedBox(width: 140, child: LinearProgressIndicator()),
                      error: (e, st) => const SizedBox.shrink(),
                    ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                        DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                        DropdownMenuItem(value: 'BOARDING', child: Text('Boarding')),
                        DropdownMenuItem(value: 'DEPARTED', child: Text('Departed')),
                        DropdownMenuItem(value: 'IN_TRANSIT', child: Text('In Transit')),
                        DropdownMenuItem(value: 'DELAYED', child: Text('Delayed')),
                        DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                        DropdownMenuItem(value: 'ARRIVED', child: Text('Arrived')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                            _page = 1;
                          });
                        }
                      },
                    ),
                  ),
                  tripsAsync.maybeWhen(
                    data: (pageData) => AbraButton(
                      label: 'Export',
                      variant: AbraButtonVariant.secondary,
                      onPressed: () => _exportTrips(pageData.items),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Table
            tripsAsync.when(
              data: (pageData) {
                final items = pageData.items;
                return Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 44,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 56,
                          columns: const [
                            DataColumn(label: Text('Trip', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Bus', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Departs', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Seats', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('From', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [
                            for (final t in items)
                              _buildTripRow(context, ref, t, l10n, access, repo),
                          ],
                        ),
                      ),
                      // Pagination bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pageData.total == 0
                                  ? '0 of 0'
                                  : '${pageData.firstIndex}–${pageData.lastIndex} of ${pageData.total}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: pageData.hasPrevious
                                      ? () => setState(() => _page--)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: pageData.hasNext
                                      ? () => setState(() => _page++)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading trips: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildTripRow(
    BuildContext context,
    WidgetRef ref,
    JsonMap t,
    AbraLocalizations l10n,
    AccessState access,
    CatalogueRepository repo,
  ) {
    final tripId = t['id'] as String;
    final status = (t['status'] as String?) ?? 'DRAFT';
    final bus = t['bus'] as JsonMap?;
    final busLabel = bus != null ? (bus['name'] as String? ?? 'Bus') : 'Bus';
    final departure = '${t['travelDate']} ${t['departureTime']}';
    final farePaise = (t['startingFarePaise'] as num?)?.toInt() ?? 0;
    final fareStr = l10n.formatters.currencyFromMinor(farePaise);

    final seatCounts = t['seatCounts'] as JsonMap?;
    final totalSeats = (seatCounts?['total'] as num?)?.toInt() ?? 0;
    final availableSeats = (seatCounts?['available'] as num?)?.toInt() ?? 0;
    final bookedSeats = (seatCounts?['booked'] as num?)?.toInt() ?? (totalSeats - availableSeats);

    final seatsWidget = status == 'DRAFT'
        ? const Text('—', style: TextStyle(fontSize: 12))
        : Text('$bookedSeats/$totalSeats', style: const TextStyle(fontSize: 12));

    return DataRow(
      cells: [
        DataCell(Text('${t['code'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(LookupName('routes', t['routeId'] as String?)),
        DataCell(Text(busLabel)),
        DataCell(Text(departure)),
        DataCell(StatusBadge(status, CatalogueLabels.tripStatuses)),
        DataCell(seatsWidget),
        DataCell(Text(fareStr)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined, size: 18),
                onPressed: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => TripDetailDialog(tripId: tripId),
                  );
                  if (changed == true) {
                    ref.invalidate(resourceListProvider);
                  }
                },
              ),
              if (status == 'DRAFT' && access.can(PermissionKeys.tripsUpdate))
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () async {
                    final updated = await showResourceForm(
                      context,
                      title: l10n.text(AdminStrings.tripEditTitle),
                      fields: _fields,
                      initial: t,
                      onSubmit: (values) => repo.put('trips/$tripId', _withIntegerFare(values)),
                    );
                    if (updated == true) {
                      ref.invalidate(resourceListProvider);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. TRIP DETAIL DIALOG (WITH PUBLISH CHECKLIST)
// ==========================================

class _TripContext {
  const _TripContext({
    required this.trip,
    this.operator,
    this.bus,
    this.route,
    this.locations = const <String, JsonMap>{},
  });

  final JsonMap trip;
  final JsonMap? operator;
  final JsonMap? bus;
  final JsonMap? route;
  final Map<String, JsonMap> locations;
}

final _tripContextProvider = FutureProvider.autoDispose
    .family<_TripContext, String>((ref, tripId) async {
  final repository = ref.watch(catalogueRepositoryProvider);
  final trip = await repository.get('trips/$tripId');

  Future<JsonMap?> optional(String path) async {
    try {
      return await repository.get(path);
    } on Object {
      return null;
    }
  }

  final locationIds = <String>{
    for (final list in <Object?>[
      trip['boardingPoints'],
      trip['droppingPoints'],
    ])
      if (list is List)
        for (final point in list)
          if (point is Map && point['locationId'] != null)
            point['locationId']! as String,
  };

  final results = await Future.wait<JsonMap?>([
    optional('operators/${trip['operatorId']}'),
    optional('buses/${trip['busId']}'),
    optional('routes/${trip['routeId']}'),
    for (final id in locationIds) optional('locations/$id'),
  ]);

  return _TripContext(
    trip: trip,
    operator: results[0],
    bus: results[1],
    route: results[2],
    locations: <String, JsonMap>{
      for (final location in results.skip(3).whereType<JsonMap>())
        location['id']! as String: location,
    },
  );
});

class TripDetailDialog extends ConsumerStatefulWidget {
  const TripDetailDialog({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripDetailDialog> createState() => _TripDetailDialogState();
}

class _TripDetailDialogState extends ConsumerState<TripDetailDialog> {
  bool _isBusy = false;
  bool _changed = false;
  String? _rejection;
  String? _notice;

  Future<void> _publish() async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(AdminStrings.tripPublishConfirmTitle),
      message: l10n.text(AdminStrings.tripPublishConfirmMessage),
      confirmLabel: l10n.text(AdminStrings.tripPublish),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isBusy = true;
      _rejection = null;
      _notice = null;
    });
    try {
      await ref
          .read(catalogueRepositoryProvider)
          .post('trips/${widget.tripId}/publish');
      _changed = true;
      _notice = l10n.text(AdminStrings.tripPublishedNotice);
    } on Object catch (error) {
      _rejection = failureText(l10n, error);
    }
    if (!mounted) return;
    ref.invalidate(_tripContextProvider(widget.tripId));
    setState(() => _isBusy = false);
  }

  Future<void> _cancel() async {
    final l10n = AbraLocalizations.of(context);
    final cancelled = await showResourceForm(
      context,
      title: l10n.text(AdminStrings.tripCancelTitle),
      message: l10n.text(AdminStrings.tripCancelMessage),
      submitLabel: l10n.text(AdminStrings.tripCancel),
      fields: const <FieldSpec>[
        TextSpec(
          'reason',
          AdminStrings.formReason,
          isRequired: true,
          maxLines: 2,
          helpKey: AdminStrings.formReasonHelp,
        ),
      ],
      onSubmit: (values) => ref
          .read(catalogueRepositoryProvider)
          .post('trips/${widget.tripId}/cancel', values),
    );
    if (!cancelled || !mounted) return;
    ref.invalidate(_tripContextProvider(widget.tripId));
    setState(() {
      _changed = true;
      _rejection = null;
      _notice = l10n.text(AdminStrings.tripCancelledNotice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final loaded = ref.watch(_tripContextProvider(widget.tripId));
    final status = loaded.value?.trip['status'] as String?;
    final colors = AbraStatusColors.from(context);

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(l10n.text(AdminStrings.tripDetailTitle))),
          if (status != null) StatusBadge(status, CatalogueLabels.tripStatuses),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 520,
        child: AsyncValueView<_TripContext>(
          value: loaded,
          onRetry: () => ref.invalidate(_tripContextProvider(widget.tripId)),
          data: (context, data) => ListView(
            children: <Widget>[
              if (_rejection != null)
                _Banner(
                  title: l10n.text(AdminStrings.tripPublishRejectedTitle),
                  text: _rejection!,
                  tone: colors.danger,
                ),
              if (_notice != null)
                _Banner(text: _notice!, tone: colors.success),
              _TripSummary(trip: data.trip),
              if (data.trip['status'] == 'DRAFT') ...<Widget>[
                const Divider(height: AbraSpacing.xl),
                _PublishChecklist(data: data),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(_changed),
          child: Text(l10n.text(AbraStrings.commonClose)),
        ),
        if ((status == 'DRAFT' || status == 'SCHEDULED') &&
            access.can(PermissionKeys.tripsCancel))
          AbraButton(
            label: l10n.text(AdminStrings.tripCancel),
            variant: AbraButtonVariant.secondary,
            onPressed: _isBusy ? null : _cancel,
          ),
        if (status == 'DRAFT' && access.can(PermissionKeys.tripsPublish))
          AbraButton(
            label: l10n.text(AdminStrings.tripPublish),
            variant: AbraButtonVariant.primary,
            isLoading: _isBusy,
            onPressed: _publish,
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone, this.title});

  final String? title;
  final String text;
  final AbraTonePair tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AbraSpacing.md),
    child: Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.container,
          borderRadius: AbraRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title != null)
                Text(
                  title!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: tone.foreground),
                ),
              Text(text, style: TextStyle(color: tone.foreground)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip});

  final JsonMap trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final seats = (trip['seatCounts'] as JsonMap?) ?? const <String, Object?>{'available': 0, 'total': 0};
    final bus = (trip['bus'] as JsonMap?) ?? const <String, Object?>{'name': 'Bus', 'busTypeName': 'AC Sleeper'};

    Widget row(String labelKey, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 200,
            child: Text(
              l10n.text(labelKey),
              style: textTheme.bodyMedium?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
    String points(String key) {
      final list = trip[key];
      if (list is! List) return '';
      return <String>[
        for (final point in list)
          if (point is Map)
            '${point['name']} (+${point['offsetMinutes']})',
      ].join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        row(AdminStrings.fieldDate, '${trip['travelDate']}'),
        row(AdminStrings.fieldDeparture, '${trip['departureTime']}'),
        if (trip['durationMinutes'] != null)
          row(AdminStrings.fieldDuration, '${trip['durationMinutes']}'),
        row(AdminStrings.fieldBus, _busLabel(bus)),
        if (bus['busTypeName'] != null)
          row(AdminStrings.fieldBusType, '${bus['busTypeName']}'),
        if (trip['startingFarePaise'] != null)
          row(
            AdminStrings.fieldFare,
            l10n.formatters.currencyFromMinor(trip['startingFarePaise']! as int),
          ),
        row(
          AdminStrings.fieldSeats,
          switch (trip['status']) {
            'DRAFT' => l10n.text(AdminStrings.tripSeatsNotOnSale),
            'CANCELLED' when (seats['total'] as int? ?? 0) == 0 => l10n.text(
              AdminStrings.tripSeatsClosed,
            ),
            _ => l10n.text(AdminStrings.tripSeatsValue, <String, Object?>{
              'available': seats['available'] ?? 0,
              'total': seats['total'] ?? 0,
            }),
          },
        ),
        row(AdminStrings.fieldBoardingPoints, points('boardingPoints')),
        row(AdminStrings.fieldDroppingPoints, points('droppingPoints')),
        if (trip['cancellationReason'] != null)
          row(AdminStrings.formReason, '${trip['cancellationReason']}'),
      ],
    );
  }
}

class _PublishChecklist extends StatelessWidget {
  const _PublishChecklist({required this.data});

  final _TripContext data;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final trip = data.trip;

    bool? pointsActive(String key) {
      final list = trip[key];
      if (list is! List) return null;
      final ids = <String?>[
        for (final point in list)
          if (point is Map) point['locationId'] as String?,
      ];
      if (ids.any((id) => id == null || !data.locations.containsKey(id))) {
        return null;
      }
      return ids.every((id) => data.locations[id]!['isActive'] == true);
    }

    final departure = DateTime.tryParse(trip['departureAt'] as String? ?? '');
    final checks = <(String, bool?)>[
      (
        AdminStrings.checkOperator,
        data.operator == null ? null : data.operator!['status'] == 'ACTIVE',
      ),
      (
        AdminStrings.checkBus,
        data.bus == null ? null : data.bus!['status'] == 'ACTIVE',
      ),
      (
        AdminStrings.checkSeatCapacity,
        data.bus == null ? null : (data.bus!['seatCapacity'] as int? ?? 0) > 0,
      ),
      (
        AdminStrings.checkRoute,
        data.route == null ? null : data.route!['status'] == 'ACTIVE',
      ),
      (AdminStrings.checkBoarding, pointsActive('boardingPoints')),
      (AdminStrings.checkDropping, pointsActive('droppingPoints')),
      (AdminStrings.checkDeparture, departure?.isAfter(DateTime.now())),
      (AdminStrings.checkBusType, null),
      (AdminStrings.checkCities, null),
      (AdminStrings.checkBusFree, null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.text(AdminStrings.tripChecklistTitle),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Text(
          l10n.text(AdminStrings.tripChecklistNote),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
        ),
        gapSmall,
        for (final (labelKey, isMet) in checks)
          MergeSemantics(
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isMet == null
                    ? Icons.cloud_outlined
                    : isMet
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: isMet == null
                    ? AbraColors.textSecondary
                    : isMet
                    ? AbraColors.tealDark
                    : AbraColors.danger,
              ),
              title: Text(l10n.text(labelKey)),
              subtitle: Text(
                l10n.text(
                  isMet == null
                      ? AdminStrings.checkByServer
                      : isMet
                      ? AdminStrings.checkMet
                      : AdminStrings.checkNotMet,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// 3. ADMIN SEAT INVENTORY MONITOR PAGE
// ==========================================

class AdminInventoryPage extends ConsumerStatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  ConsumerState<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends ConsumerState<AdminInventoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _selectedOperator = 'ALL';
  String _selectedOccupancy = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSeatBlockDialog(BuildContext context, JsonMap trip) {
    final tripId = trip['id'] as String;
    final seatController = TextEditingController();
    final reasonController = TextEditingController(text: 'VIP reservation');
    bool isBlocking = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Seat inventory for ${trip['code'] ?? ''}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Block seats'),
                        selected: isBlocking,
                        onSelected: (val) => setDialogState(() => isBlocking = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Unblock seats'),
                        selected: !isBlocking,
                        onSelected: (val) => setDialogState(() => isBlocking = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: seatController,
                  decoration: const InputDecoration(
                    labelText: 'Seat numbers (comma separated, e.g. 1, 2, 5)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (isBlocking)
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for blocking',
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final raw = seatController.text.trim();
                final seatNumbers = raw
                    .split(',')
                    .map((s) => int.tryParse(s.trim()))
                    .whereType<int>()
                    .toList();
                if (seatNumbers.isEmpty) return;

                final repo = ref.read(catalogueRepositoryProvider);
                try {
                  if (isBlocking) {
                    await repo.post('trips/$tripId/seats/block', {
                      'seatNumbers': seatNumbers,
                      'reason': reasonController.text.trim(),
                    });
                  } else {
                    await repo.post('trips/$tripId/seats/unblock', {
                      'seatNumbers': seatNumbers,
                    });
                  }
                  if (ctx.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ref.invalidate(resourceListProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isBlocking ? 'Seats blocked.' : 'Seats unblocked.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(isBlocking ? 'Block' : 'Unblock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const query = ResourceQuery(
      'trips',
      pageSize: 50,
      filters: {'status': 'SCHEDULED'},
    );
    final tripsAsync = ref.watch(resourceListProvider(query));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header matching admin demo model
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seat inventory monitor',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sold, held and blocked seats across upcoming trips.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                AbraButton(
                  label: 'Release expired holds',
                  variant: AbraButtonVariant.secondary,
                  onPressed: () {
                    ref.invalidate(resourceListProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            tripsAsync.when(
              data: (pageData) {
                final allTrips = pageData.items;
                int totalSold = 0;
                int totalHeld = 0;
                int lowOcc = 0;

                for (final t in allTrips) {
                  final sc = t['seatCounts'] as JsonMap?;
                  final total = (sc?['total'] as num?)?.toInt() ?? 0;
                  final avail = (sc?['available'] as num?)?.toInt() ?? 0;
                  final booked = (sc?['booked'] as num?)?.toInt() ?? (total - avail);
                  final held = (sc?['held'] as num?)?.toInt() ?? 0;

                  totalSold += booked;
                  totalHeld += held;
                  if (total > 0 && (booked / total) < 0.25) {
                    lowOcc++;
                  }
                }

                // Filter
                final filtered = allTrips.where((t) {
                  if (_selectedOperator != 'ALL' && t['operatorId'] != _selectedOperator) {
                    return false;
                  }
                  final sc = t['seatCounts'] as JsonMap?;
                  final total = (sc?['total'] as num?)?.toInt() ?? 0;
                  final avail = (sc?['available'] as num?)?.toInt() ?? 0;
                  final booked = (sc?['booked'] as num?)?.toInt() ?? (total - avail);
                  final occ = total > 0 ? booked / total : 0.0;

                  if (_selectedOccupancy == 'low' && occ >= 0.25) return false;
                  if (_selectedOccupancy == 'high' && occ <= 0.8) return false;

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final id = (t['id'] as String? ?? '').toLowerCase();
                    if (!id.contains(q)) return false;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    // KPI Grid
                    Row(
                      children: [
                        _buildKpiCard('Trips on sale', '${allTrips.length}', Icons.directions_bus, surfaceColor, borderColor),
                        const SizedBox(width: 16),
                        _buildKpiCard('Seats sold', '$totalSold', Icons.confirmation_number_outlined, surfaceColor, borderColor),
                        const SizedBox(width: 16),
                        _buildKpiCard('Seats held right now', '$totalHeld', Icons.timer_outlined, surfaceColor, borderColor),
                        const SizedBox(width: 16),
                        _buildKpiCard('Low occupancy trips', '$lowOcc', Icons.warning_amber_outlined, surfaceColor, borderColor),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filter bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 220,
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search trips...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onSubmitted: (val) => setState(() => _searchQuery = val.trim()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedOccupancy,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Occupancy',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All')),
                                DropdownMenuItem(value: 'low', child: Text('Under 25%')),
                                DropdownMenuItem(value: 'high', child: Text('Over 80%')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedOccupancy = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Table
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Trip', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Bus', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Depart', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Booked', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Held', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Blocked', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Available', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [
                            for (final t in filtered)
                              _buildInventoryRow(context, t),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color bg, Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AbraColors.tealDark),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildInventoryRow(BuildContext context, JsonMap t) {
    final tripId = t['id'] as String;
    final status = (t['status'] as String?) ?? 'SCHEDULED';
    final bus = t['bus'] as JsonMap?;
    final busLabel = bus != null ? (bus['name'] as String? ?? 'Bus') : 'Bus';
    final departure = '${t['travelDate']} ${t['departureTime']}';

    final sc = t['seatCounts'] as JsonMap?;
    final total = (sc?['total'] as num?)?.toInt() ?? 0;
    final avail = (sc?['available'] as num?)?.toInt() ?? 0;
    final booked = (sc?['booked'] as num?)?.toInt() ?? (total - avail);
    final held = (sc?['held'] as num?)?.toInt() ?? 0;
    final blocked = (sc?['blocked'] as num?)?.toInt() ?? 0;

    return DataRow(
      cells: [
        DataCell(Text('${t['code'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(LookupName('routes', t['routeId'] as String?)),
        DataCell(Text(busLabel)),
        DataCell(Text(departure)),
        DataCell(StatusBadge(status, CatalogueLabels.tripStatuses)),
        DataCell(Text('$total')),
        DataCell(Text('$booked')),
        DataCell(Text('$held')),
        DataCell(Text('$blocked')),
        DataCell(Text('$avail')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Manage seats',
                icon: const Icon(Icons.event_seat_outlined, size: 18),
                onPressed: () => _showSeatBlockDialog(context, t),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
