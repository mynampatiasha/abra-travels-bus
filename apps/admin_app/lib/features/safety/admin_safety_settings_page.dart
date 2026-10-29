import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Safety Settings configuration screen matching prototypes/admin_demo_model.html.
class AdminSafetySettingsPage extends ConsumerStatefulWidget {
  const AdminSafetySettingsPage({super.key});

  @override
  ConsumerState<AdminSafetySettingsPage> createState() =>
      _AdminSafetySettingsPageState();
}

class _AdminSafetySettingsPageState
    extends ConsumerState<AdminSafetySettingsPage> {
  final _ackController = TextEditingController(text: '3');
  final _escController = TextEditingController(text: '7');
  final _policeController = TextEditingController(text: '112');
  final _templateController = TextEditingController(
    text: 'Abra Safety: We have received your emergency alert. Our team is contacting local assistance.',
  );

  @override
  void dispose() {
    _ackController.dispose();
    _escController.dispose();
    _policeController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Settings',
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
                      'Rules for responding to SOS alerts, police contacts, and customer notifications.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Settings Form Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AbraSpacing.md),
                    decoration: BoxDecoration(
                      color: AbraColors.skyContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Not connected yet - built in Phase 5',
                      style: TextStyle(
                        color: AbraColors.deepBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('SLA & Auto Escalation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Max minutes to acknowledge SOS:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _ackController,
                              enabled: false,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Auto-escalate to emergency manager (minutes):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _escController,
                              enabled: false,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Emergency Contacts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Police Control Room Number:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _policeController,
                    enabled: false,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  const Text('Passenger SMS / WhatsApp Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _templateController,
                    enabled: false,
                    maxLines: 3,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
