import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import 'resource_form.dart';
import 'resource_page.dart';

/// A value as plain text for the export; nothing is an empty cell.
String plainText(Object? value) => value == null ? '' : '$value';

/// Label keys and badge tones of the status values of the catalogue.
abstract final class CatalogueLabels {
  static const documentSubjects = <String, String>{
    'OPERATOR': AdminStrings.subjectOperator,
    'BUS': AdminStrings.subjectBus,
  };

  /// File types a document may be uploaded as, by MIME type.
  static const documentFileTypes = <String, String>{
    'application/pdf': 'PDF',
    'image/jpeg': 'JPG photo',
    'image/png': 'PNG photo',
  };

  static const berthTypes = <String, String>{
    'SEATER': AdminStrings.berthSeater,
    'SLEEPER': AdminStrings.berthSleeper,
    'SEMI_SLEEPER': AdminStrings.berthSemiSleeper,
    'MIXED': AdminStrings.berthMixed,
  };

  static const operatorStatuses = <String, String>{
    'PENDING_APPROVAL': AdminStrings.operatorPending,
    'ACTIVE': AdminStrings.operatorActive,
    'REJECTED': AdminStrings.operatorRejected,
    'SUSPENDED': AdminStrings.operatorSuspended,
  };

  /// What an operator in each status can become (state-machines.md). Only
  /// decides what the form offers; the backend refuses anything else.
  static const operatorTransitions = <String, List<String>>{
    'PENDING_APPROVAL': <String>['ACTIVE', 'REJECTED'],
    'ACTIVE': <String>['SUSPENDED'],
    'SUSPENDED': <String>['ACTIVE'],
    'REJECTED': <String>[],
  };

  static const busStatuses = <String, String>{
    'PENDING_APPROVAL': AdminStrings.operatorPending,
    'ACTIVE': AdminStrings.busActive,
    'MAINTENANCE': AdminStrings.busMaintenance,
    'RETIRED': AdminStrings.busRetired,
  };

  static const routeStatuses = <String, String>{
    'ACTIVE': AdminStrings.statusActive,
    'INACTIVE': AdminStrings.statusInactive,
  };

  static const tripStatuses = <String, String>{
    'DRAFT': AdminStrings.tripDraft,
    'SCHEDULED': AdminStrings.tripScheduled,
    'BOARDING': AdminStrings.tripBoarding,
    'DEPARTED': AdminStrings.tripDeparted,
    'IN_TRANSIT': AdminStrings.tripInTransit,
    'ARRIVED': AdminStrings.tripArrived,
    'DELAYED': AdminStrings.tripDelayed,
    'CANCELLED': AdminStrings.tripCancelled,
  };

  static const activeFilter = <String, String>{
    'true': AdminStrings.statusActive,
    'false': AdminStrings.statusInactive,
  };

  static const amenities = <String>[
    'WIFI',
    'CHARGING_POINT',
    'BLANKET',
    'PILLOW',
    'WATER_BOTTLE',
    'READING_LIGHT',
    'CCTV',
    'GPS_TRACKING',
    'TOILET',
    'ENTERTAINMENT',
    'SNACKS',
    'EMERGENCY_EXIT',
    'FIRST_AID',
  ];

  /// `CHARGING_POINT` as "Charging point".
  static String readable(String key) {
    final words = key.toLowerCase().split('_').join(' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }

  static AbraStatusTone toneOf(String status) => switch (status) {
    'ACTIVE' || 'SCHEDULED' || 'ARRIVED' => AbraStatusTone.success,
    'DRAFT' || 'PENDING_APPROVAL' || 'MAINTENANCE' => AbraStatusTone.warning,
    'CANCELLED' || 'REJECTED' || 'SUSPENDED' => AbraStatusTone.danger,
    'BOARDING' ||
    'DEPARTED' ||
    'IN_TRANSIT' ||
    'DELAYED' => AbraStatusTone.info,
    _ => AbraStatusTone.neutral,
  };
}

/// A status as a badge: the word is always shown, colour only supports it.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, this.labels, {super.key});

  /// For a yes/no state.
  const StatusBadge.active({required bool isActive, super.key})
    : status = isActive ? 'ACTIVE' : 'INACTIVE',
      labels = CatalogueLabels.routeStatuses;

  final String status;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final key = labels[status];
    return AbraStatusBadge(
      label: key == null
          ? CatalogueLabels.readable(status)
          : AbraLocalizations.of(context).text(key),
      tone: CatalogueLabels.toneOf(status),
    );
  }
}

/// The name of a record referred to by id, looked up in a list the user may
/// see. Shows a dash while loading or when the record is not among them.
class LookupName extends ConsumerWidget {
  const LookupName(this.path, this.id, {this.labelOf, super.key});

  final String path;
  final String? id;
  final String Function(JsonMap record)? labelOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const Text('—');
    final records = ref.watch(optionsProvider(path)).value;
    final record = records?.where((item) => item['id'] == id).firstOrNull;
    return Text(
      record == null ? '—' : (labelOf ?? nameOf)(record),
      overflow: TextOverflow.ellipsis,
    );
  }
}

String nameOf(JsonMap record) => record['name'] as String? ?? '';

String operatorNameOf(JsonMap record) =>
    (record['displayName'] ?? record['companyName']) as String? ?? '';

Text textCell(Object? value) => Text(value?.toString() ?? '—');

/// Asks for confirmation, then enables or disables a record
/// (`POST <path>/<id>/active`).
Future<bool> confirmSetActive(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required JsonMap record,
  required bool active,
  String Function(JsonMap record) labelOf = nameOf,
}) async {
  final l10n = AbraLocalizations.of(context);
  final confirmed = await showAbraConfirmDialog(
    context,
    title: l10n.text(
      active
          ? AdminStrings.confirmEnableTitle
          : AdminStrings.confirmDisableTitle,
      <String, Object?>{'name': labelOf(record)},
    ),
    message: l10n.text(AdminStrings.confirmStatusMessage),
    confirmLabel: l10n.text(
      active ? AdminStrings.actionEnable : AdminStrings.actionDisable,
    ),
    isDestructive: !active,
  );
  if (confirmed != true) return false;
  await ref.read(catalogueRepositoryProvider).post(
    '$path/${record['id']}/active',
    <String, Object?>{'active': active},
  );
  return true;
}

/// The enable/disable action for a record with an `isActive` flag. [labelOf] names the record
/// in the confirmation (its `name` by default).
RowAction activeToggleAction(
  WidgetRef ref,
  String path,
  JsonMap record, {
  String Function(JsonMap record) labelOf = nameOf,
}) {
  final isActive = record['isActive'] as bool? ?? false;
  return RowAction(
    isActive ? AdminStrings.actionDisable : AdminStrings.actionEnable,
    isActive ? Icons.block : Icons.check_circle_outline,
    (context, record) => confirmSetActive(
      context,
      ref,
      path: path,
      record: record,
      active: !isActive,
      labelOf: labelOf,
    ),
  );
}

/// Opens a form that changes a status, with a reason.
Future<bool> showStatusForm(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String path,
  required Map<String, String> options,
  required bool reasonRequired,
  String? current,
}) => showResourceForm(
  context,
  title: title,
  message: AbraLocalizations.of(
    context,
  ).text(AdminStrings.confirmStatusMessage),
  fields: <FieldSpec>[
    ChoiceSpec('status', AdminStrings.fieldStatus, options, isRequired: true),
    TextSpec(
      'reason',
      AdminStrings.formReason,
      isRequired: reasonRequired,
      maxLines: 2,
      helpKey: AdminStrings.formReasonHelp,
    ),
  ],
  initial: current == null || !options.containsKey(current)
      ? const <String, Object?>{}
      : <String, Object?>{'status': current},
  onSubmit: (values) =>
      ref.read(catalogueRepositoryProvider).post(path, values),
);

const Widget gapSmall = SizedBox(height: AbraSpacing.sm);
