import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Live Bus Tracking page matching prototypes/admin_demo_model.html.
class AdminTrackingPage extends ConsumerStatefulWidget {
  const AdminTrackingPage({super.key});

  @override
  ConsumerState<AdminTrackingPage> createState() => _AdminTrackingPageState();
}

class _AdminTrackingPageState extends ConsumerState<AdminTrackingPage> {
  String _selectedOperator = 'ALL';
  String _selectedState = 'ALL';

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
                  'Operations',
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
                  'Live tracking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Row with Operator and State Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live tracking',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every running bus. Real-time telemetry, location and speed.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedOperator,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All operators')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedOperator = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedState,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                          DropdownMenuItem(value: 'ON_TIME', child: Text('On time')),
                          DropdownMenuItem(value: 'DELAYED', child: Text('Delayed')),
                          DropdownMenuItem(value: 'STOPPED', child: Text('Stopped')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedState = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tracking Container
            Container(
              height: 540,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.near_me_outlined, size: 48, color: AbraColors.textDisabled),
                    SizedBox(height: AbraSpacing.md),
                    Text(
                      'Not connected yet - built in Phase 5',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
