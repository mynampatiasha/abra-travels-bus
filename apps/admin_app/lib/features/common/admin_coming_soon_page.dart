import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Pixel-perfect placeholder for demo screens being connected.
class AdminComingSoonPage extends StatelessWidget {
  const AdminComingSoonPage({
    required this.title,
    required this.subtitle,
    required this.groupName,
    this.kpis = const <Map<String, String>>[],
    this.actions = const <String>[],
    super.key,
  });

  final String title;
  final String subtitle;
  final String groupName;
  final List<Map<String, String>> kpis;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Breadcrumb
            Row(
              children: <Widget>[
                Text(
                  groupName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AbraColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' / ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  Wrap(
                    spacing: AbraSpacing.sm,
                    children: actions.map((label) {
                      return FilledButton.tonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label action simulated (Demo model)'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AbraColors.blueContainer,
                          foregroundColor: AbraColors.deepBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AbraSpacing.lg,
                            vertical: AbraSpacing.sm,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Demo KPI preview cards if any
            if (kpis.isNotEmpty) ...<Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 4
                      : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AbraSpacing.md,
                      mainAxisSpacing: AbraSpacing.md,
                      mainAxisExtent: 88,
                    ),
                    itemCount: kpis.length,
                    itemBuilder: (context, index) {
                      final item = kpis[index];
                      return Container(
                        padding: const EdgeInsets.all(AbraSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(14)),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AbraColors.skyContainer,
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              child: const Icon(
                                Icons.insights,
                                color: AbraColors.deepBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item['value'] ?? '-',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFFE6EEF5)
                                          : AbraColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    item['label'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF9FB6C9)
                                          : AbraColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AbraSpacing.lg),
            ],

            // Content preview container
            Container(
              padding: const EdgeInsets.all(AbraSpacing.xxl),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A12304A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AbraColors.skyContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: AbraColors.deepBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.lg),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.xs),
                  Text(
                    'Connected to demo route $title. Full interactive UI for this screen will be implemented with mock state.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.xl),
                  Wrap(
                    spacing: AbraSpacing.md,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export CSV triggered (Demo)'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filter updated (Demo)'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh data'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AbraColors.blue,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                    ],
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
