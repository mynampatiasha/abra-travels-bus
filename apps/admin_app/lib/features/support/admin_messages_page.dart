import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/resource_page.dart';

/// Messages sent: WhatsApp and email log.
/// Matches the demo page in prototypes/admin_demo_model.html (reg('messages')).
/// Uses real backend endpoints:
/// - GET /admin/messages
/// - GET /admin/messages/:id
/// - POST /admin/messages/:id/resend
class AdminMessagesPage extends ConsumerWidget {
  const AdminMessagesPage({super.key});

  static String _formatDateTime(Object? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse('$iso')?.toLocal();
    if (dt == null) return '$iso';
    return DateFormat('d MMM y, h:mm a').format(dt);
  }

  static String _formatTime(Object? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse('$iso')?.toLocal();
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  static Widget _channelBadge(Object? channel) {
    final kind = '${channel ?? ''}'.toUpperCase();
    final (bg, fg, label) = switch (kind) {
      'WHATSAPP' => (const Color(0xFFE6F7ED), const Color(0xFF0D6832), 'WhatsApp'),
      'SMS' => (const Color(0xFFF3EEFD), const Color(0xFF5B3BB5), 'SMS'),
      _ => (const Color(0xFFEBF3FE), const Color(0xFF185ABC), 'Email'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _statusBadge(Object? status) {
    final s = '${status ?? ''}'.toUpperCase();
    final isFailed = s == 'FAILED';
    return AbraStatusBadge(
      label: isFailed ? 'FAILED' : 'SENT',
      tone: isFailed ? AbraStatusTone.danger : AbraStatusTone.success,
    );
  }

  static Widget _recipientCell(BuildContext context, JsonMap record) {
    final name = record['toName'] ?? record['recipientName'] ?? record['name'] ?? '';
    final address = record['address'] ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$name',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if ('$address'.isNotEmpty)
          Text(
            '$address',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  static Widget _kindCell(BuildContext context, JsonMap record, AbraLocalizations l10n) {
    final kind = '${record['kind'] ?? ''}';
    final label = switch (kind) {
      'BOOKING_CONFIRMED' => l10n.text(AdminStrings.msgKindBookingConfirmed),
      'BOOKING_CANCELLED' => l10n.text(AdminStrings.msgKindBookingCancelled),
      'REFUND_PAID' => l10n.text(AdminStrings.msgKindRefundPaid),
      'PAYMENT_FAILED' => l10n.text(AdminStrings.msgKindPaymentFailed),
      'TRIP_DELAYED' => l10n.text(AdminStrings.msgKindTripDelayed),
      'BOARDING_STARTED' => l10n.text(AdminStrings.msgKindBoardingStarted),
      'TRAVEL_REMINDER' => l10n.text(AdminStrings.msgKindTravelReminder),
      'TRIP_CANCELLED' => l10n.text(AdminStrings.msgKindTripCancelled),
      'BUS_CHANGED' => l10n.text(AdminStrings.msgKindBusChanged),
      'TRIP_FEEDBACK' => l10n.text(AdminStrings.msgKindTripFeedback),
      'SUPPORT_REPLIED' => l10n.text(AdminStrings.msgKindSupportReplied),
      'SOS_ALERT' => l10n.text(AdminStrings.msgKindSosAlert),
      'TRIP_SHARED' => l10n.text(AdminStrings.msgKindTripShared),
      'ANNOUNCEMENT' => l10n.text(AdminStrings.msgKindAnnouncement),
      'GENERAL' => l10n.text(AdminStrings.msgKindGeneral),
      _ => kind,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);

    return ResourcePage(
      path: 'admin/messages',
      exportName: 'messages',
      emptyTitle: l10n.text(AdminStrings.msgEmptyTitle),
      emptyMessage: l10n.text(AdminStrings.msgEmptyMessage),
      stats: const <StatSpec>[
        StatSpec(
          AdminStrings.msgStatSentToday,
          <String, String>{'today': 'true'},
          Icons.mail_outline,
          AbraColors.blue,
        ),
        StatSpec(
          AdminStrings.msgStatWhatsApp,
          <String, String>{'channel': 'WHATSAPP'},
          Icons.phone_android,
          AbraColors.tealDark,
        ),
        StatSpec(
          AdminStrings.msgStatEmails,
          <String, String>{'channel': 'EMAIL'},
          Icons.mail_outline,
          AbraColors.blue,
        ),
        StatSpec(
          AdminStrings.msgStatFailed,
          <String, String>{'status': 'FAILED'},
          Icons.warning_amber_rounded,
          AbraColors.danger,
        ),
      ],
      filters: const <FilterSpec>[
        SearchFilter('q', AdminStrings.msgFilterSearch),
        ChoiceFilter(
          'channel',
          AdminStrings.msgFilterChannel,
          <String, String>{
            'WHATSAPP': AdminStrings.msgChannelWhatsApp,
            'EMAIL': AdminStrings.msgChannelEmail,
          },
        ),
        ChoiceFilter(
          'kind',
          AdminStrings.msgFilterType,
          <String, String>{
            'BOOKING_CONFIRMED': AdminStrings.msgKindBookingConfirmed,
            'BOOKING_CANCELLED': AdminStrings.msgKindBookingCancelled,
            'REFUND_PAID': AdminStrings.msgKindRefundPaid,
            'PAYMENT_FAILED': AdminStrings.msgKindPaymentFailed,
            'TRIP_DELAYED': AdminStrings.msgKindTripDelayed,
            'BOARDING_STARTED': AdminStrings.msgKindBoardingStarted,
            'TRAVEL_REMINDER': AdminStrings.msgKindTravelReminder,
            'TRIP_CANCELLED': AdminStrings.msgKindTripCancelled,
            'BUS_CHANGED': AdminStrings.msgKindBusChanged,
            'TRIP_FEEDBACK': AdminStrings.msgKindTripFeedback,
            'SUPPORT_REPLIED': AdminStrings.msgKindSupportReplied,
            'SOS_ALERT': AdminStrings.msgKindSosAlert,
            'TRIP_SHARED': AdminStrings.msgKindTripShared,
            'ANNOUNCEMENT': AdminStrings.msgKindAnnouncement,
            'GENERAL': AdminStrings.msgKindGeneral,
          },
        ),
        ChoiceFilter(
          'status',
          AdminStrings.msgFilterStatus,
          <String, String>{
            'SENT': AdminStrings.msgStatusSent,
            'FAILED': AdminStrings.msgStatusFailed,
            'QUEUED': AdminStrings.msgStatusQueued,
            'SKIPPED': AdminStrings.msgStatusSkipped,
          },
        ),
      ],
      columns: <ColumnSpec>[
        ColumnSpec(
          AdminStrings.msgColWhen,
          (_, r) => Text(_formatDateTime(r['at'] ?? r['sentAt'])),
          text: (r) => _formatDateTime(r['at'] ?? r['sentAt']),
        ),
        ColumnSpec(
          AdminStrings.msgColChannel,
          (_, r) => _channelBadge(r['channel']),
          text: (r) => '${r['channel'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.msgColTo,
          (context, r) => _recipientCell(context, r),
          text: (r) => '${r['toName'] ?? r['recipientName'] ?? r['name'] ?? ''} ${r['address'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.msgColType,
          (context, r) => _kindCell(context, r, l10n),
          text: (r) => '${r['kind'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.msgColSubject,
          (_, r) => Text(
            '${r['subject'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
          text: (r) => '${r['subject'] ?? ''}',
        ),
        ColumnSpec(
          AdminStrings.msgColStatus,
          (_, r) => _statusBadge(r['status']),
          text: (r) => '${r['status'] ?? ''}',
        ),
      ],
      onRowTap: (context, record) => _openMessageDetail(context, record, ref),
    );
  }

  static Future<void> _openMessageDetail(
    BuildContext context,
    JsonMap record,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MessageDetailsDialog(record: record),
    );
  }
}

class _MessageDetailsDialog extends ConsumerStatefulWidget {
  const _MessageDetailsDialog({required this.record});

  final JsonMap record;

  @override
  ConsumerState<_MessageDetailsDialog> createState() => _MessageDetailsDialogState();
}

class _MessageDetailsDialogState extends ConsumerState<_MessageDetailsDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final record = widget.record;
    final id = '${record['id'] ?? ''}';
    final isWhatsApp = '${record['channel'] ?? ''}'.toUpperCase() == 'WHATSAPP';
    final name = record['toName'] ?? record['recipientName'] ?? record['name'] ?? '';
    final address = '${record['address'] ?? ''}';
    final subject = '${record['subject'] ?? ''}';
    final body = '${record['body'] ?? ''}';
    final kind = '${record['kind'] ?? ''}';
    final at = AdminMessagesPage._formatDateTime(record['at'] ?? record['sentAt']);
    final timeStr = AdminMessagesPage._formatTime(record['at'] ?? record['sentAt']);
    final bookingId = record['bookingId'] as String?;
    final isFailed = '${record['status'] ?? ''}'.toUpperCase() == 'FAILED';
    final canResend = ref.watch(accessProvider).can(PermissionKeys.messagesResend);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AbraSpacing.xl,
                AbraSpacing.lg,
                AbraSpacing.sm,
                AbraSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      subject.isNotEmpty ? subject : l10n.text(AdminStrings.msgDetailTitle),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.text(AdminStrings.commClose),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AbraSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Key-value list
                    _kvRow(l10n.text(AdminStrings.msgDetailChannel), isWhatsApp ? 'WhatsApp' : 'Email'),
                    _kvRow(l10n.text(AdminStrings.msgDetailTo), '$name - $address'),
                    _kvRow(l10n.text(AdminStrings.msgDetailType), kind),
                    _kvRow(l10n.text(AdminStrings.msgDetailSent), at),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 120,
                            child: Text(
                              l10n.text(AdminStrings.msgDetailStatus),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ),
                          AbraStatusBadge(
                            label: isFailed ? 'FAILED' : 'SENT',
                            tone: isFailed ? AbraStatusTone.danger : AbraStatusTone.success,
                          ),
                        ],
                      ),
                    ),
                    _kvRow(l10n.text(AdminStrings.msgDetailBooking), bookingId ?? '-'),
                    const SizedBox(height: AbraSpacing.lg),
                    Text(
                      l10n.text(AdminStrings.msgDetailReceived),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    if (isWhatsApp)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 360),
                          padding: const EdgeInsets.all(AbraSpacing.md),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCF8C6),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                              bottomLeft: Radius.circular(2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SelectableText(
                                body,
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  '$timeStr ✓✓',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF111111).withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AbraSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AbraColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SelectableText(
                              subject,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: AbraSpacing.md),
                            SelectableText(
                              body,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.text(AdminStrings.commClose)),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  AbraButton(
                    label: l10n.text(AdminStrings.msgActionSendAgain),
                    icon: Icons.send,
                    isLoading: _busy,
                    onPressed: !canResend
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await ref
                                  .read(catalogueRepositoryProvider)
                                  .post('admin/messages/$id/resend');
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.text(
                                        AdminStrings.msgSentAgainToast,
                                        <String, Object?>{'address': address},
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } on Object catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(failureText(l10n, e)),
                                    backgroundColor: AbraColors.danger,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kvRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
