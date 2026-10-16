import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../routing/admin_routes.dart';
import 'support_mock_store.dart';

class AdminTicketsPage extends ConsumerStatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  ConsumerState<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends ConsumerState<AdminTicketsPage> {
  String _selectedStatus = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedPriority = 'ALL';
  String _selectedAssignee = 'ALL';
  String _searchQuery = '';
  TicketRecord? _selectedTicket;

  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportStoreProvider);
    final tickets = supportState.tickets;

    if (_selectedTicket != null) {
      // Find latest version from state
      final current = tickets.firstWhere(
        (t) => t.id == _selectedTicket!.id,
        orElse: () => _selectedTicket!,
      );
      return _buildTicketDetailView(context, current, supportState);
    }

    final openCount = tickets.where((t) => t.status == 'OPEN').length;
    final inProgressCount =
        tickets.where((t) => t.status == 'IN_PROGRESS').length;
    final overdueCount = tickets.where((t) => t.isPastSla).length;
    final resolvedCount =
        tickets.where((t) => t.status == 'RESOLVED' || t.status == 'CLOSED').length;

    final filtered = tickets.where((t) {
      if (_selectedStatus != 'ALL' && t.status != _selectedStatus) return false;
      if (_selectedCategory != 'ALL' && t.category != _selectedCategory) {
        return false;
      }
      if (_selectedPriority != 'ALL' && t.priority != _selectedPriority) {
        return false;
      }
      if (_selectedAssignee != 'ALL') {
        if (_selectedAssignee == 'UNASSIGNED' && t.assignee != null) return false;
        if (_selectedAssignee != 'UNASSIGNED' &&
            !(t.assignee?.contains(_selectedAssignee) ?? false)) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.id.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.customer.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Support inbox',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Questions and problems from customers.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(AdminRoutes.content),
                  icon: const Icon(Icons.book_outlined, size: 16),
                  label: const Text('Help content and contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AbraColors.navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Open',
                    value: '$openCount',
                    icon: Icons.help_outline,
                    color: AbraColors.blue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'In progress',
                    value: '$inProgressCount',
                    icon: Icons.schedule,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Past time limit',
                    value: '$overdueCount',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    isAlert: overdueCount > 0,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Resolved',
                    value: '$resolvedCount',
                    icon: Icons.check_circle_outline,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search tickets or passengers...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    _buildFilterDropdown(
                      label: 'Status',
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                        DropdownMenuItem(
                            value: 'IN_PROGRESS', child: Text('In progress')),
                        DropdownMenuItem(
                            value: 'RESOLVED', child: Text('Resolved')),
                        DropdownMenuItem(
                            value: 'CLOSED', child: Text('Closed')),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val ?? 'ALL'),
                    ),
                    _buildFilterDropdown(
                      label: 'Category',
                      value: _selectedCategory,
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All categories')),
                        DropdownMenuItem(
                            value: 'BOOKING', child: Text('Booking')),
                        DropdownMenuItem(
                            value: 'PAYMENT', child: Text('Payment')),
                        DropdownMenuItem(
                            value: 'REFUND', child: Text('Refund')),
                        DropdownMenuItem(
                            value: 'SAFETY', child: Text('Safety')),
                        DropdownMenuItem(value: 'APP', child: Text('App bug')),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val ?? 'ALL'),
                    ),
                    _buildFilterDropdown(
                      label: 'Priority',
                      value: _selectedPriority,
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All priorities')),
                        DropdownMenuItem(
                            value: 'URGENT', child: Text('Urgent')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High')),
                        DropdownMenuItem(
                            value: 'MEDIUM', child: Text('Medium')),
                        DropdownMenuItem(value: 'LOW', child: Text('Low')),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedPriority = val ?? 'ALL'),
                    ),
                    _buildFilterDropdown(
                      label: 'Assigned',
                      value: _selectedAssignee,
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All assignees')),
                        DropdownMenuItem(
                            value: 'UNASSIGNED', child: Text('Unassigned')),
                        DropdownMenuItem(
                            value: 'Divya', child: Text('Divya')),
                        DropdownMenuItem(
                            value: 'Kiran', child: Text('Kiran')),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedAssignee = val ?? 'ALL'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tickets Data Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: filtered.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No tickets found',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your search query or filters.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey.shade100,
                          ),
                          columns: const [
                            DataColumn(label: Text('Ticket')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Priority')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Assigned to')),
                            DataColumn(label: Text('Time limit')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: filtered.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _selectedTicket = t),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            t.id,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AbraColors.blue,
                                            ),
                                          ),
                                          Text(
                                            t.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(t.customer)),
                                DataCell(_buildCategoryBadge(t.category)),
                                DataCell(_buildPriorityBadge(t.priority)),
                                DataCell(_buildStatusBadge(t.status)),
                                DataCell(
                                  Text(
                                    t.assignee ?? 'Nobody',
                                    style: TextStyle(
                                      color: t.assignee == null
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade800,
                                      fontStyle: t.assignee == null
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  t.status == 'OPEN' || t.status == 'IN_PROGRESS'
                                      ? (t.isPastSla
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: Colors.red.shade300),
                                              ),
                                              child: const Text(
                                                'Overdue',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              DateFormat('hh:mm a')
                                                  .format(t.sla),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ))
                                      : const Text('-'),
                                ),
                                DataCell(
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _selectedTicket = t),
                                    icon: const Icon(Icons.chat_bubble_outline,
                                        size: 14),
                                    label: const Text('Open'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AbraColors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketDetailView(
    BuildContext context,
    TicketRecord ticket,
    SupportState supportState,
  ) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AbraColors.navy),
          onPressed: () => setState(() => _selectedTicket = null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(ticket.status),
                const SizedBox(width: 6),
                _buildPriorityBadge(ticket.priority),
              ],
            ),
            Text(
              'Ticket ID: ${ticket.id} • Created ${DateFormat('MMM dd, yyyy • hh:mm a').format(ticket.at)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _openAssignModal(context, ticket),
            icon: const Icon(Icons.person_add_alt_1, size: 15),
            label: Text(ticket.assignee ?? 'Assign'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AbraColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),
          if (ticket.status != 'RESOLVED' && ticket.status != 'CLOSED')
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(supportStoreProvider.notifier)
                    .setTicketStatus(ticket.id, 'RESOLVED');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Resolved. The customer can reply to reopen.'),
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 15),
              label: const Text('Mark resolved'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(supportStoreProvider.notifier)
                    .setTicketStatus(ticket.id, 'OPEN');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ticket reopened as OPEN')),
                );
              },
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Reopen'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Conversation Thread & Reply Composer
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AbraColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Messages stream
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ticket.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final m = ticket.messages[index];
                      final isAgent = m.sender == 'agent';

                      return Align(
                        alignment: isAgent
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 620),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isAgent
                                ? AbraColors.skyBlue.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isAgent
                                  ? AbraColors.blue.withValues(alpha: 0.3)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isAgent ? 'Support Agent' : ticket.customer,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isAgent
                                          ? AbraColors.blue
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, hh:mm a').format(m.at),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                m.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              if (m.attachments.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: m.attachments.map((file) {
                                    return Chip(
                                      avatar: const Icon(
                                        Icons.attach_file,
                                        size: 14,
                                      ),
                                      label: Text(file,
                                          style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.grey.shade100,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Reply Box
                  if (ticket.status != 'CLOSED')
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Write a reply',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _replyController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText:
                                    'Type instructions or message to customer...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Canned reply picker
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      hintText: 'Use a canned reply...',
                                    ),
                                    items: supportState.cannedReplies
                                        .map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(
                                                r,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        _replyController.text = val;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final text = _replyController.text.trim();
                                    if (text.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Write a reply first'),
                                        ),
                                      );
                                      return;
                                    }
                                    ref
                                        .read(supportStoreProvider.notifier)
                                        .addTicketReply(ticket.id, text);
                                    _replyController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Reply sent to the customer',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text('Send reply'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AbraColors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Right: Details Panel
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Customer', ticket.customer),
                _buildDetailRow('Category', ticket.category),
                _buildDetailRow('Priority', ticket.priority),
                _buildDetailRow(
                    'Assigned', ticket.assignee ?? 'Nobody'),
                _buildDetailRow(
                  'Time limit',
                  ticket.isPastSla
                      ? 'Overdue'
                      : DateFormat('MMM dd, hh:mm a').format(ticket.sla),
                  color: ticket.isPastSla ? Colors.red : null,
                ),
                const Divider(height: 32),
                if (ticket.bookingId != null) ...[
                  const Text(
                    'Linked booking',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AbraColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Booking ID', ticket.bookingId!),
                  _buildDetailRow('Route', 'Hyderabad to Bengaluru'),
                  _buildDetailRow('Amount', '₹1,290'),
                  _buildDetailRow('Status', 'CONFIRMED'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AdminRoutes.bookings),
                    icon: const Icon(Icons.open_in_new, size: 13),
                    label: const Text('Open booking in Sales'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AbraColors.blue,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAssignModal(BuildContext context, TicketRecord ticket) {
    String? selected = ticket.assignee;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: const Text('Assign ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Assign to',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Nobody')),
                  DropdownMenuItem(
                      value: 'Divya (Support)', child: Text('Divya (Support)')),
                  DropdownMenuItem(
                      value: 'Kiran (Support)', child: Text('Kiran (Support)')),
                ],
                onChanged: (val) => setMdlState(() => selected = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(supportStoreProvider.notifier)
                    .assignTicket(ticket.id, selected);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Assigned to ${selected ?? "Nobody"}')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAlert ? Colors.red.shade900 : Colors.grey.shade600,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red.shade900 : AbraColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'OPEN':
        bg = Colors.blue.shade50;
        fg = AbraColors.blue;
        break;
      case 'IN_PROGRESS':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'RESOLVED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'CLOSED':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
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
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    switch (priority) {
      case 'URGENT':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'HIGH':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'MEDIUM':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'LOW':
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        cat,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? AbraColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
