import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../core/async_value_view.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import '../widgets/catalogue_common.dart';
import '../widgets/resource_form.dart';
import '../widgets/resource_page.dart';

String _busLabel(JsonMap bus) =>
    '${bus['name']} (${bus['registrationNumber']})';

/// Trips: drafts, trips on sale and their history, for the operators the
/// user may see.
class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  static const _points = <FieldSpec>[
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

  static const _fields = <FieldSpec>[
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

  /// The body for an edit: the form sends whole numbers of paise.
  static JsonMap _withIntegerFare(JsonMap values) => <String, Object?>{
    ...values,
    if (values['startingFarePaise'] is num)
      'startingFarePaise': (values['startingFarePaise']! as num).round(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    final repository = ref.read(catalogueRepositoryProvider);

    return ResourcePage(
      path: 'trips',
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
          CatalogueLabels.tripStatuses,
        ),
        const SearchFilter('travelDate', AdminStrings.fieldTravelDate),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(AdminStrings.fieldDate, (_, r) => textCell(r['travelDate'])),
        ColumnSpec(
          AdminStrings.fieldDeparture,
          (_, r) => textCell(r['departureTime']),
        ),
        ColumnSpec(
          AdminStrings.fieldRoute,
          (_, r) => LookupName('routes', r['routeId'] as String?),
        ),
        ColumnSpec(
          AdminStrings.fieldBus,
          (_, r) => textCell((r['bus'] as JsonMap?)?['name']),
        ),
        ColumnSpec(
          AdminStrings.fieldFare,
          (_, r) => Text(
            l10n.formatters.currencyFromMinor(r['startingFarePaise']! as int),
          ),
          isNumeric: true,
        ),
        ColumnSpec(
          AdminStrings.fieldStatus,
          (_, r) =>
              StatusBadge(r['status']! as String, CatalogueLabels.tripStatuses),
        ),
      ],
      onCreate: access.can(PermissionKeys.tripsCreate)
          ? (context) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.tripCreateTitle),
              fields: _fields,
              onSubmit: (values) =>
                  repository.post('trips', _withIntegerFare(values)),
            )
          : null,
      rowActions: (record) => <RowAction>[
        RowAction(
          AdminStrings.actionView,
          Icons.visibility_outlined,
          (context, record) async =>
              await showDialog<bool>(
                context: context,
                builder: (context) =>
                    TripDetailDialog(tripId: record['id']! as String),
              ) ??
              false,
        ),
        if (record['status'] == 'DRAFT' &&
            access.can(PermissionKeys.tripsUpdate))
          RowAction(
            AdminStrings.actionEdit,
            Icons.edit_outlined,
            (context, record) => showResourceForm(
              context,
              title: l10n.text(AdminStrings.tripEditTitle),
              fields: _fields,
              initial: record,
              onSubmit: (values) => repository.put(
                'trips/${record['id']}',
                _withIntegerFare(values),
              ),
            ),
          ),
      ],
    );
  }
}

/// What the dialog loads besides the trip, to show the publishing
/// requirements as they are now.
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
      // A related record the user cannot read is simply left unknown.
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
          for (final point in list! as List<Object?>)
            if ((point! as JsonMap)['locationId'] != null)
              (point as JsonMap)['locationId']! as String,
      };
      final results = await Future.wait(<Future<JsonMap?>>[
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

/// One trip with its lifecycle actions. Closes with true when the trip
/// changed, so the list behind it reloads.
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
      // The backend's reason, exactly as it gave it.
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
    final seats = trip['seatCounts']! as JsonMap;
    final bus = trip['bus']! as JsonMap;

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
    String points(String key) => <String>[
      for (final point in (trip[key]! as List<Object?>).cast<JsonMap>())
        '${point['name']} (+${point['offsetMinutes']})',
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        row(AdminStrings.fieldDate, '${trip['travelDate']}'),
        row(AdminStrings.fieldDeparture, '${trip['departureTime']}'),
        row(AdminStrings.fieldDuration, '${trip['durationMinutes']}'),
        row(AdminStrings.fieldBus, _busLabel(bus)),
        row(AdminStrings.fieldBusType, '${bus['busTypeName']}'),
        row(
          AdminStrings.fieldFare,
          l10n.formatters.currencyFromMinor(trip['startingFarePaise']! as int),
        ),
        row(
          AdminStrings.fieldSeats,
          l10n.text(AdminStrings.tripSeatsValue, <String, Object?>{
            'available': seats['available'],
            'total': seats['total'],
          }),
        ),
        row(AdminStrings.fieldBoardingPoints, points('boardingPoints')),
        row(AdminStrings.fieldDroppingPoints, points('droppingPoints')),
        if (trip['cancellationReason'] != null)
          row(AdminStrings.formReason, '${trip['cancellationReason']}'),
      ],
    );
  }
}

/// The requirements the backend checks on publishing, with their state as
/// far as the app can read it. It is an aid, not a rule engine: the backend
/// decides, and requirements the app cannot read are marked as such.
class _PublishChecklist extends StatelessWidget {
  const _PublishChecklist({required this.data});

  final _TripContext data;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final trip = data.trip;

    bool? pointsActive(String key) {
      final ids = <String?>[
        for (final point in trip[key]! as List<Object?>)
          (point! as JsonMap)['locationId'] as String?,
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
      // Not readable here: decided by the backend alone.
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
              // The state is always in words, never by colour alone.
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
