import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_theme/shared_theme.dart';

import 'support_mock_store.dart';

class AdminContentPage extends ConsumerStatefulWidget {
  const AdminContentPage({super.key});

  @override
  ConsumerState<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends ConsumerState<AdminContentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contact form controllers
  late TextEditingController _phoneCtrl;
  late TextEditingController _waCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _hoursCtrl;
  late TextEditingController _emergencyCtrl;

  // FAQ filters
  String _faqStatusFilter = 'ALL';
  String _faqCategoryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final contact = ref.read(supportStoreProvider).contact;
    _phoneCtrl = TextEditingController(text: contact.phone);
    _waCtrl = TextEditingController(text: contact.whatsapp);
    _emailCtrl = TextEditingController(text: contact.email);
    _hoursCtrl = TextEditingController(text: contact.hours);
    _emergencyCtrl = TextEditingController(text: contact.emergency);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _emailCtrl.dispose();
    _hoursCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportStoreProvider);
    final faqs = supportState.faqs;
    final pages = supportState.pages;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help content and contact',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What customers read in the help centre, and how they reach you.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AbraColors.blue,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AbraColors.blue,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'FAQs (${faqs.length})'),
                  Tab(text: 'Policy pages (${pages.length})'),
                  const Tab(text: 'Contact and hours'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content Views
            IndexedStack(
              index: _tabController.index,
              children: [
                _buildFaqsTab(context, supportState),
                _buildPolicyPagesTab(context, supportState),
                _buildContactTab(context, supportState),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqsTab(BuildContext context, SupportState state) {
    final filtered = state.faqs.where((f) {
      if (_faqStatusFilter != 'ALL' && f.status != _faqStatusFilter) {
        return false;
      }
      if (_faqCategoryFilter != 'ALL' && f.category != _faqCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter and Action Bar
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _faqStatusFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                      DropdownMenuItem(
                          value: 'PUBLISHED', child: Text('Published')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    ],
                    onChanged: (v) =>
                        setState(() => _faqStatusFilter = v ?? 'ALL'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _faqCategoryFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'ALL', child: Text('All categories')),
                      DropdownMenuItem(
                          value: 'Bookings', child: Text('Bookings')),
                      DropdownMenuItem(value: 'Refunds', child: Text('Refunds')),
                      DropdownMenuItem(
                          value: 'Payments', child: Text('Payments')),
                      DropdownMenuItem(value: 'Safety', child: Text('Safety')),
                      DropdownMenuItem(value: 'Trips', child: Text('Trips')),
                      DropdownMenuItem(value: 'Offers', child: Text('Offers')),
                    ],
                    onChanged: (v) =>
                        setState(() => _faqCategoryFilter = v ?? 'ALL'),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openFaqModal(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add FAQ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // FAQs Table
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Question')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Views')),
                  DataColumn(label: Text('Updated')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filtered.map((f) {
                  return DataRow(
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Text(
                            f.question,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(Text(f.category)),
                      DataCell(_buildStatusChip(f.status)),
                      DataCell(Text('${f.views}')),
                      DataCell(
                        Text(DateFormat('MMM dd, yyyy').format(f.updated)),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit FAQ',
                              onPressed: () => _openFaqModal(context, faq: f),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(supportStoreProvider.notifier)
                                    .toggleFaqPublish(f.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      f.status == 'PUBLISHED'
                                          ? 'Unpublished from customer app'
                                          : 'Published in customer app',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                f.status == 'PUBLISHED'
                                    ? 'Unpublish'
                                    : 'Publish',
                                style: TextStyle(
                                  color: f.status == 'PUBLISHED'
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildPolicyPagesTab(BuildContext context, SupportState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: const [
              DataColumn(label: Text('Policy Page')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Version')),
              DataColumn(label: Text('Updated')),
              DataColumn(label: Text('Actions')),
            ],
            rows: state.pages.map((p) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      p.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(_buildStatusChip(p.status)),
                  DataCell(Text('v${p.version}')),
                  DataCell(Text(DateFormat('MMM dd, yyyy').format(p.updated))),
                  DataCell(
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openPolicyEditModal(context, p),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AbraColors.navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showVersionHistoryModal(context, p),
                          icon: const Icon(Icons.history, size: 14),
                          label: const Text('Versions'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AbraColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildContactTab(BuildContext context, SupportState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact details shown in the customer app',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Support phone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _waCtrl,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Support email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _hoursCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Working hours',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emergencyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Emergency number',
                    helperText: 'Shown on the SOS & safety screen',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final email = _emailCtrl.text.trim();
                if (!email.contains('@') || !email.contains('.')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid support email'),
                    ),
                  );
                  return;
                }

                ref.read(supportStoreProvider.notifier).updateContact(
                      ContactConfig(
                        phone: _phoneCtrl.text.trim(),
                        whatsapp: _waCtrl.text.trim(),
                        email: email,
                        hours: _hoursCtrl.text.trim(),
                        emergency: _emergencyCtrl.text.trim(),
                      ),
                    );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Saved. The app shows this on its next refresh.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save contact details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFaqModal(BuildContext context, {FaqRecord? faq}) {
    final qCtrl = TextEditingController(text: faq?.question ?? '');
    final aCtrl = TextEditingController(text: faq?.answer ?? '');
    String cat = faq?.category ?? 'Bookings';
    String status = faq?.status ?? 'DRAFT';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: Text(faq == null ? 'Add FAQ' : 'Edit FAQ'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Answer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Bookings', child: Text('Bookings')),
                      DropdownMenuItem(
                          value: 'Refunds', child: Text('Refunds')),
                      DropdownMenuItem(
                          value: 'Payments', child: Text('Payments')),
                      DropdownMenuItem(value: 'Safety', child: Text('Safety')),
                      DropdownMenuItem(value: 'Trips', child: Text('Trips')),
                      DropdownMenuItem(value: 'Offers', child: Text('Offers')),
                    ],
                    onChanged: (v) => setMdlState(() => cat = v ?? 'Bookings'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'PUBLISHED', child: Text('PUBLISHED')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                    ],
                    onChanged: (v) => setMdlState(() => status = v ?? 'DRAFT'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) {
                  return;
                }
                if (faq != null) {
                  ref.read(supportStoreProvider.notifier).updateFaq(
                        FaqRecord(
                          id: faq.id,
                          question: qCtrl.text.trim(),
                          answer: aCtrl.text.trim(),
                          category: cat,
                          status: status,
                          views: faq.views,
                          updated: DateTime.now(),
                        ),
                      );
                } else {
                  ref.read(supportStoreProvider.notifier).addFaq(
                        FaqRecord(
                          id: 'FAQ-${DateTime.now().millisecondsSinceEpoch % 10000}',
                          question: qCtrl.text.trim(),
                          answer: aCtrl.text.trim(),
                          category: cat,
                          status: status,
                          views: 0,
                          updated: DateTime.now(),
                        ),
                      );
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FAQ saved successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPolicyEditModal(BuildContext context, PolicyPageRecord p) {
    final titleCtrl = TextEditingController(text: p.title);
    final bodyCtrl = TextEditingController(text: p.content);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${p.title}'),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Content',
                  helperText:
                      'Publishing creates version ${p.version + 1} and retains historical revisions.',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              ref.read(supportStoreProvider.notifier).updatePolicyPage(
                    p.id,
                    bodyCtrl.text.trim(),
                    'DRAFT',
                  );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Draft saved')),
              );
            },
            child: const Text('Save draft'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(supportStoreProvider.notifier).updatePolicyPage(
                    p.id,
                    bodyCtrl.text.trim(),
                    'PUBLISHED',
                  );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Published as version ${p.version + 1}'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _showVersionHistoryModal(BuildContext context, PolicyPageRecord p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Versions of ${p.title}'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: p.version,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = p.version - i;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '$v',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AbraColors.blue,
                    ),
                  ),
                ),
                title: Text('Version $v',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  i == 0
                      ? 'Current published version'
                      : 'Archived ${i * 30} days ago',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isPub = status == 'PUBLISHED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPub ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isPub ? Colors.green.shade800 : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
