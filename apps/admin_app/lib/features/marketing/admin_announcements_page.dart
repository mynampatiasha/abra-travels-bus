import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'marketing_mock_store.dart';

/// Announcements screen matching prototypes/admin_demo_model.html.
class AdminAnnouncementsPage extends ConsumerStatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  ConsumerState<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends ConsumerState<AdminAnnouncementsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketingState = ref.watch(marketingStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final filtered = marketingState.announcements.where((a) {
      if (_selectedStatus != 'ALL' && a.status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = a.title.toLowerCase().contains(q) ||
            a.body.toLowerCase().contains(q) ||
            a.audience.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

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
                  'Marketing',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send a message to customers by push and WhatsApp.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showNewAnnouncementDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New announcement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search announcements by title, body, or audience...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                      DropdownMenuItem(value: 'SENT', child: Text('Sent')),
                      DropdownMenuItem(
                          value: 'SCHEDULED', child: Text('Scheduled')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStatus = val ?? 'ALL');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DataTable
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No announcements match filters'),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                        ),
                        columns: const [
                          DataColumn(label: Text('Message')),
                          DataColumn(label: Text('Sent to')),
                          DataColumn(label: Text('Channel')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Reached')),
                          DataColumn(label: Text('When')),
                        ],
                        rows: filtered.map((ann) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 320,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ann.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        ann.body,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? const Color(0xFF8BA2B9)
                                              : const Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(ann.audience)),
                              DataCell(Text(ann.channel)),
                              DataCell(_buildStatusChip(ann.status, isDark)),
                              DataCell(
                                Text(
                                  ann.reach > 0 ? '${ann.reach}' : '-',
                                  style: TextStyle(
                                    fontWeight: ann.reach > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${ann.at.day}/${ann.at.month}/${ann.at.year} ${ann.at.hour}:${ann.at.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'SENT':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
      case 'SCHEDULED':
        bg = isDark ? const Color(0xFF0C2237) : const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
      case 'DRAFT':
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
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showNewAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'All customers';
    String channel = 'Push';
    String whenMode = 'now';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('New announcement'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Special festive discounts announced',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 3,
                        maxLength: 240,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Message body *',
                          hintText:
                              'Keep it concise and clear (max 240 chars)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: audience,
                        decoration: const InputDecoration(
                          labelText: 'Send to',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'All customers', child: Text('All customers')),
                          DropdownMenuItem(
                              value: 'Customers on a route',
                              child: Text('Customers on a route')),
                          DropdownMenuItem(
                              value: 'Customers of one trip',
                              child: Text('Customers of one trip')),
                          DropdownMenuItem(
                              value: 'New users', child: Text('New users')),
                          DropdownMenuItem(
                              value: 'Women travellers',
                              child: Text('Women travellers')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => audience = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: channel,
                        decoration: const InputDecoration(
                          labelText: 'Channel',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Push', child: Text('Push')),
                          DropdownMenuItem(
                              value: 'Push, WhatsApp',
                              child: Text('Push, WhatsApp')),
                          DropdownMenuItem(
                              value: 'WhatsApp', child: Text('WhatsApp')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => channel = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: whenMode,
                        decoration: const InputDecoration(
                          labelText: 'When',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'now', child: Text('Send now')),
                          DropdownMenuItem(
                              value: 'later',
                              child: Text('Schedule for later')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => whenMode = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Live Mobile Push Preview Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F1E2C)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2A3E50)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active,
                                    size: 14, color: AbraColors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  'Abra Travels • now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF8BA2B9)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              titleCtrl.text.trim().isNotEmpty
                                  ? titleCtrl.text.trim()
                                  : 'Announcement Title',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bodyCtrl.text.trim().isNotEmpty
                                  ? bodyCtrl.text.trim()
                                  : 'Message preview as passengers will receive it on mobile.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final body = bodyCtrl.text.trim();
                    if (title.isEmpty || body.isEmpty) return;

                    final newAnn = AnnouncementRecord(
                      id: 'AN${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      body: body,
                      audience: audience,
                      channel: channel,
                      status: 'DRAFT',
                      at: DateTime.now(),
                      reach: 0,
                    );
                    ref
                        .read(marketingStoreProvider.notifier)
                        .saveAnnouncement(newAnn);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Announcement saved as draft')),
                    );
                  },
                  child: const Text('Save draft'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final body = bodyCtrl.text.trim();
                    if (title.isEmpty || body.isEmpty) return;

                    final isScheduled = whenMode == 'later';
                    final newAnn = AnnouncementRecord(
                      id: 'AN${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      body: body,
                      audience: audience,
                      channel: channel,
                      status: isScheduled ? 'SCHEDULED' : 'SENT',
                      at: isScheduled
                          ? DateTime.now().add(const Duration(hours: 12))
                          : DateTime.now(),
                      reach: isScheduled ? 0 : 3400,
                    );
                    ref
                        .read(marketingStoreProvider.notifier)
                        .saveAnnouncement(newAnn);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isScheduled
                            ? 'Announcement scheduled'
                            : 'Announcement broadcasted'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(whenMode == 'later' ? 'Schedule' : 'Send now'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
