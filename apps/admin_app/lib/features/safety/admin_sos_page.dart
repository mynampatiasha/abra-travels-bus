import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'safety_mock_store.dart';

/// SOS Emergency Board matching prototypes/admin_demo_model.html.
class AdminSosPage extends ConsumerStatefulWidget {
  const AdminSosPage({super.key});

  @override
  ConsumerState<AdminSosPage> createState() => _AdminSosPageState();
}

class _AdminSosPageState extends ConsumerState<AdminSosPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safetyState = ref.watch(safetyStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final alerts = List<SosAlert>.from(safetyState.alerts)
      ..sort((a, b) => b.at.compareTo(a.at));

    final selectedAlert = alerts.firstWhere(
      (a) => a.id == safetyState.selectedAlertId,
      orElse: () => alerts.isNotEmpty ? alerts.first : alerts.first,
    );

    final hasNewAlerts = alerts.any((a) => a.status == 'NEW');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text(
                  'Safety',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'SOS board',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header: Title & Sound Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS board',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alerts customers sent from the app. Act on the newest first.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    final newVal = !safetyState.soundOn;
                    ref.read(safetyStoreProvider.notifier).toggleSound(newVal);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newVal ? 'Sound on (demo)' : 'Sound off'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                      color: surfaceColor,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: safetyState.soundOn,
                          onChanged: (val) {
                            ref
                                .read(safetyStoreProvider.notifier)
                                .toggleSound(val ?? true);
                          },
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sound on new alert',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Alert banner
            if (hasNewAlerts)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF381519)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          ),
                          children: [
                            const TextSpan(
                              text: 'New SOS waiting. ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  'Acknowledge within ${safetyState.config.ackMinutes} minutes or it escalates to the safety lead.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0E2E1D)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF166534)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No new alerts. All open ones are being handled.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Two-column layout (Alerts List & Alert Detail)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (!isWide) {
                  return Column(
                    children: [
                      _buildAlertsList(
                        alerts,
                        selectedAlert.id,
                        safetyState.config.ackMinutes,
                        surfaceColor,
                        borderColor,
                        isDark,
                      ),
                      const SizedBox(height: 24),
                      _buildAlertDetail(
                        selectedAlert,
                        surfaceColor,
                        borderColor,
                        isDark,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left list (approx 380px)
                    SizedBox(
                      width: 380,
                      child: _buildAlertsList(
                        alerts,
                        selectedAlert.id,
                        safetyState.config.ackMinutes,
                        surfaceColor,
                        borderColor,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right detail
                    Expanded(
                      child: _buildAlertDetail(
                        selectedAlert,
                        surfaceColor,
                        borderColor,
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(
    List<SosAlert> alerts,
    String? selectedId,
    int ackMinutes,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      children: alerts.map((alert) {
        final isSelected = alert.id == selectedId;
        final isOverdue = alert.isOverdue(ackMinutes);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AbraColors.blue
                  : (alert.status == 'NEW'
                      ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
                      : borderColor),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxBarHelper.shadow(
                      AbraColors.blue.withValues(alpha: 0.15),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref.read(safetyStoreProvider.notifier).selectAlert(alert.id);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (alert.status == 'NEW')
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                              )
                            else
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDark
                                    ? const Color(0xFF8BA2B9)
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              alert.fromDriver
                                  ? alert.customer
                                  : alert.customer,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        _buildStatusChip(alert.status, isDark),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Raised by badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: alert.fromDriver
                            ? (isDark ? const Color(0xFF2C220E) : const Color(0xFFFEF3C7))
                            : (isDark ? const Color(0xFF0C2237) : const Color(0xFFE0F2FE)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.fromDriver ? 'Raised by driver' : 'Raised by customer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: alert.fromDriver
                              ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                              : (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Route - bus
                    Text(
                      '${alert.route} - bus ${alert.bus}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Driver and client
                    Text(
                      'Driver: ${alert.driver}    Client: ${alert.operator}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Time and Overdue warning
                    Row(
                      children: [
                        Text(
                          formatRelativeTime(alert.at),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Overdue to acknowledge',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertDetail(
    SosAlert alert,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    final isActive = [
      'NEW',
      'ACKNOWLEDGED',
      'RESPONDING',
      'ESCALATED',
    ].contains(alert.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & ID + Status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${alert.customer} - ${alert.id}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildStatusChip(alert.status, isDark),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Key Value List
          _buildDetailRow('Raised by', alert.fromDriver ? 'Driver: ${alert.customer}' : 'Customer: ${alert.customer}', isDark),
          _buildDetailRow('Phone', alert.phone, isDark),
          _buildDetailRow('Trip', '${alert.trip} (${alert.route})', isDark, isLink: true),
          _buildDetailRow('Bus', alert.bus, isDark),
          _buildDetailRow('Driver', alert.driver, isDark),
          _buildDetailRow('Client (bus company)', alert.operator, isDark, isLink: true),
          _buildDetailRow('Note', alert.note, isDark, isBoldValue: true),
          _buildDetailRow(
            'Raised',
            '${formatDateTime(alert.at)} (${formatRelativeTime(alert.at)})',
            isDark,
          ),
          _buildDetailRow('Handled by', alert.assignee.isNotEmpty ? alert.assignee : 'Nobody yet', isDark),

          const SizedBox(height: 20),

          // Interactive Map Box
          _buildMapBox(alert, isDark),
          const SizedBox(height: 6),
          Text(
            'Live location updates every 10 seconds (simulated telemetry)',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 24),

          // Contacts Alerted section
          Text(
            'Contacts alerted',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...alert.contacts.map((contact) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.perm_contact_calendar_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        contact,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _simulateCall(contact),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Quick Call Action triggers
          Text(
            'Call',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _simulateCall('Customer (${alert.customer})'),
                icon: const Icon(Icons.phone, size: 14),
                label: const Text('Customer'),
              ),
              OutlinedButton.icon(
                onPressed: () => _simulateCall('Driver (${alert.driver})'),
                icon: const Icon(Icons.phone, size: 14),
                label: const Text('Driver'),
              ),
              OutlinedButton.icon(
                onPressed: () => _simulateCall('Operator (${alert.operator})'),
                icon: const Icon(Icons.phone, size: 14),
                label: const Text('Operator'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final police = ref.read(safetyStoreProvider).config.police;
                  _simulateCall('Police Control Room $police');
                },
                icon: const Icon(Icons.local_police, size: 14),
                label: const Text('Police'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // History timeline
          Text(
            'History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alert.log.map((log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AbraColors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDateTime(log.at),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                              ),
                            ),
                            if (log.proofFiles.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: log.proofFiles.map((pf) {
                                  return Chip(
                                    label: Text(pf, style: const TextStyle(fontSize: 11)),
                                    avatar: const Icon(Icons.attach_file, size: 14),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          if (isActive) ...[
            const Divider(height: 1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (alert.status == 'NEW')
                  ElevatedButton.icon(
                    onPressed: () {
                      ref
                          .read(safetyStoreProvider.notifier)
                          .acknowledgeAlert(alert.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acknowledged SOS alert'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Acknowledge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showAddNoteDialog(alert.id),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Add note'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(safetyStoreProvider.notifier).escalateAlert(alert.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Escalated. Safety lead & police notified.'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  },
                  icon: const Icon(Icons.priority_high, size: 16),
                  label: const Text('Escalate'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showResolveDialog(alert.id),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showFalseAlarmDialog(alert.id),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('False alarm'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isLink = false,
    bool isBoldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                color: isLink
                    ? AbraColors.blue
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBox(SosAlert alert, bool isDark) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E2C) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3E50) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Stack(
        children: [
          // Simulated map grid styling
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(isDark: isDark),
            ),
          ),

          // SOS Location pin (Red)
          Positioned(
            left: (alert.x / 100) * 300 + 40,
            top: (alert.y / 100) * 140 + 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_pin, color: Colors.white, size: 18),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SOS location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bus Location pin (Green)
          Positioned(
            left: (alert.x / 100) * 300 + 75,
            top: (alert.y / 100) * 140 + 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 16),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert.bus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map legend / overlay
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black54 : Colors.white70,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Lat: ${(17.3850 + (alert.x * 0.01)).toStringAsFixed(4)}° N, Lon: ${(78.4867 + (alert.y * 0.01)).toStringAsFixed(4)}° E',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'NEW':
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
      case 'ACKNOWLEDGED':
      case 'RESPONDING':
        bg = isDark ? const Color(0xFF0C2237) : const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
      case 'ESCALATED':
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
      case 'RESOLVED':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
      case 'FALSE_ALARM':
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _simulateCall(String party) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.phone_in_talk, color: AbraColors.blue),
              const SizedBox(width: 8),
              Text('Calling $party'),
            ],
          ),
          content: Text(
            'Simulating high-priority cellular / VoIP bridge to $party...\n\nCall active (Audio stream connected). Press end when done.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('End call'),
            ),
          ],
        );
      },
    );
  }

  void _showAddNoteDialog(String alertId) {
    final noteController = TextEditingController();
    final proofController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note *',
                  hintText: 'Enter incident updates or dispatch notes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proofController,
                decoration: const InputDecoration(
                  labelText: 'Attach file name (optional)',
                  hintText: 'e.g. driver_reply.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_file),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final note = noteController.text.trim();
                if (note.isEmpty) return;
                final proofs = proofController.text.trim().isNotEmpty
                    ? [proofController.text.trim()]
                    : <String>[];
                ref
                    .read(safetyStoreProvider.notifier)
                    .addAlertNote(alertId, note, proofs);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note added')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResolveDialog(String alertId) {
    final resController = TextEditingController();
    final proofController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Resolve SOS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'How was it resolved? *',
                  hintText: 'Explain the actions taken and confirmed safety...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proofController,
                decoration: const InputDecoration(
                  labelText: 'Proof file *',
                  hintText: 'e.g. police_signed_clearance.pdf',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final res = resController.text.trim();
                final proof = proofController.text.trim();
                if (res.isEmpty) return;
                ref.read(safetyStoreProvider.notifier).resolveAlert(
                  alertId,
                  res,
                  proof.isNotEmpty ? [proof] : ['resolution_log.pdf'],
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert marked as resolved'),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Resolve'),
            ),
          ],
        );
      },
    );
  }

  void _showFalseAlarmDialog(String alertId) {
    final reasonController = TextEditingController();
    final proofController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mark as false alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Use this only after speaking directly to the customer.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What did the customer say? *',
                  hintText: 'e.g. Passenger confirmed phone fell and pressed SOS',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proofController,
                decoration: const InputDecoration(
                  labelText: 'Proof (call recording, screenshot) *',
                  hintText: 'e.g. customer_call_recording.mp3',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_file),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                final proof = proofController.text.trim();
                if (reason.isEmpty) return;
                ref.read(safetyStoreProvider.notifier).markFalseAlarm(
                  alertId,
                  reason,
                  proof.isNotEmpty ? [proof] : ['call_confirmation.pdf'],
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked as false alarm')),
                );
              },
              child: const Text('Mark false alarm'),
            ),
          ],
        );
      },
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark ? const Color(0xFF1E3246) : const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF2A4259) : const Color(0xFF94A3B8)
      ..strokeWidth = 3.0;

    // Grid lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Simulated highway curve
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.2,
        size.width,
        size.height * 0.5,
      );
    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoxBarHelper {
  static BoxShadow shadow(Color color) {
    return BoxShadow(
      color: color,
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }
}
