import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/portal_strings.dart';

/// Words and colours for the state of a documents file, a document and a bus,
/// used by the dashboard and the documents screen alike.

String fileStatusKey(String status) => switch (status) {
  'PENDING' => PortalStrings.statusPending,
  'APPROVED' => PortalStrings.statusApproved,
  'REJECTED' => PortalStrings.statusRejected,
  _ => PortalStrings.statusDraft,
};

AbraStatusTone fileTone(String status) => switch (status) {
  'APPROVED' => AbraStatusTone.success,
  'PENDING' => AbraStatusTone.warning,
  'REJECTED' => AbraStatusTone.danger,
  _ => AbraStatusTone.neutral,
};

Color statusColor(String status) => switch (status) {
  'APPROVED' => AbraColors.tealDark,
  'PENDING' => AbraColors.orangeDark,
  'REJECTED' => AbraColors.danger,
  _ => AbraColors.navySecondary,
};

Widget fileStatusBadge(AbraLocalizations l10n, String status) =>
    AbraStatusBadge(
      label: l10n.text(fileStatusKey(status)),
      tone: fileTone(status),
    );

String companyMessageKey(String status) => switch (status) {
  'PENDING' => PortalStrings.dashCompanyPending,
  'APPROVED' => PortalStrings.dashCompanyApproved,
  'REJECTED' => PortalStrings.dashCompanyRejected,
  _ => PortalStrings.dashCompanyDraft,
};

String busStatusKey(String status) => switch (status) {
  'ACTIVE' => PortalStrings.busStatusActive,
  'MAINTENANCE' => PortalStrings.busStatusMaintenance,
  'RETIRED' => PortalStrings.busStatusRetired,
  _ => PortalStrings.busStatusPending,
};

AbraStatusTone busTone(String status) => switch (status) {
  'ACTIVE' => AbraStatusTone.success,
  'PENDING_APPROVAL' => AbraStatusTone.warning,
  'MAINTENANCE' => AbraStatusTone.info,
  _ => AbraStatusTone.neutral,
};
