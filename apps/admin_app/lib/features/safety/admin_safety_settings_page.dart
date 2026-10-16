import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'safety_mock_store.dart';

/// Safety Settings configuration screen matching prototypes/admin_demo_model.html.
class AdminSafetySettingsPage extends ConsumerStatefulWidget {
  const AdminSafetySettingsPage({super.key});

  @override
  ConsumerState<AdminSafetySettingsPage> createState() =>
      _AdminSafetySettingsPageState();
}

class _AdminSafetySettingsPageState
    extends ConsumerState<AdminSafetySettingsPage> {
  late TextEditingController _ackController;
  late TextEditingController _escController;
  late TextEditingController _policeController;
  late TextEditingController _templateController;

  String? _ackError;
  String? _escError;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(safetyStoreProvider).config;
    _ackController = TextEditingController(text: cfg.ackMinutes.toString());
    _escController =
        TextEditingController(text: cfg.escalateMinutes.toString());
    _policeController = TextEditingController(text: cfg.police);
    _templateController = TextEditingController(text: cfg.template);
  }

  @override
  void dispose() {
    _ackController.dispose();
    _escController.dispose();
    _policeController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    setState(() {
      _ackError = null;
      _escError = null;
    });

    final ack = int.tryParse(_ackController.text.trim()) ?? 0;
    final esc = int.tryParse(_escController.text.trim()) ?? 0;

    if (ack < 1) {
      setState(() => _ackError = 'At least 1 minute required');
      return;
    }
    if (esc <= ack) {
      setState(() => _escError = 'Must be longer than acknowledge time');
      return;
    }

    ref.read(safetyStoreProvider.notifier).updateConfig(
          ackMinutes: ack,
          escalateMinutes: esc,
          police: _policeController.text.trim(),
          template: _templateController.text.trim(),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety settings saved successfully'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safetyState = ref.watch(safetyStoreProvider);
    final cfg = safetyState.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

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
                  'Safety settings',
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
                      'Safety settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How SOS alerts are handled. Legal review is still needed for these contacts.',
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
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2-Column Responsive Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 850;
                if (!isWide) {
                  return Column(
                    children: [
                      _buildEscalationTimingCard(
                          cfg, surfaceColor, borderColor, isDark),
                      const SizedBox(height: 20),
                      _buildWhoIsAlertedCard(
                          cfg, surfaceColor, borderColor, isDark),
                      const SizedBox(height: 20),
                      _buildSafetyTeamCard(
                          cfg, surfaceColor, borderColor, isDark),
                      const SizedBox(height: 20),
                      _buildMessageTemplateCard(
                          cfg, surfaceColor, borderColor, isDark),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildEscalationTimingCard(
                              cfg, surfaceColor, borderColor, isDark),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildWhoIsAlertedCard(
                              cfg, surfaceColor, borderColor, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSafetyTeamCard(cfg, surfaceColor, borderColor, isDark),
                    const SizedBox(height: 20),
                    _buildMessageTemplateCard(
                        cfg, surfaceColor, borderColor, isDark),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEscalationTimingCard(
    SafetyConfig cfg,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
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
          Text(
            'Escalation timing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ackController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Acknowledge within (minutes) *',
              errorText: _ackError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _escController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Escalate to safety lead after (minutes) *',
              errorText: _escError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _policeController,
            decoration: const InputDecoration(
              labelText: 'Police control room number *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_police_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0C2237)
                  : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF0369A1)
                    : const Color(0xFFBAE6FD),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The customer holds the SOS button for ${cfg.sosHold} seconds to send. This is fixed in the app and cannot be changed here.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoIsAlertedCard(
    SafetyConfig cfg,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
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
          Text(
            'Who is alerted',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            'SMS to emergency contacts',
            'Send instant SMS broadcast with tracking URL',
            cfg.smsOn,
            (v) => ref.read(safetyStoreProvider.notifier).toggleSms(v),
            isDark,
          ),
          const Divider(),
          _buildToggleRow(
            'WhatsApp to emergency contacts',
            'Send interactive WhatsApp distress alert template',
            cfg.whatsOn,
            (v) => ref.read(safetyStoreProvider.notifier).toggleWhatsApp(v),
            isDark,
          ),
          const Divider(),
          _buildToggleRow(
            'Tell the operator',
            'Trigger high-priority popover in Operator Portal',
            cfg.notifyOperator,
            (v) => ref.read(safetyStoreProvider.notifier).toggleNotifyOperator(v),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AbraColors.blue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTeamCard(
    SafetyConfig cfg,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Safety team (receives alerts)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddTeamMemberDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add person'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...cfg.team.asMap().entries.map((entry) {
            final idx = entry.key;
            final member = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        member,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFDC2626)),
                    tooltip: 'Remove',
                    onPressed: () {
                      if (cfg.team.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Keep at least one person on safety team'),
                          ),
                        );
                        return;
                      }
                      ref
                          .read(safetyStoreProvider.notifier)
                          .removeTeamMember(idx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed team member')),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageTemplateCard(
    SafetyConfig cfg,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
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
          Text(
            'Message sent to emergency contacts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Available variables: {customer}, {route}, {bus}, {link}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _templateController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Template *',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTeamMemberDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add to safety team'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name and role *',
              hintText: 'e.g. Anand Kumar (Duty Officer)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                ref.read(safetyStoreProvider.notifier).addTeamMember(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to safety team')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
