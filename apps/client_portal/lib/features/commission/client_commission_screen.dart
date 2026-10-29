import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/widgets/portal_section_title.dart';

class ClientCommissionScreen extends StatelessWidget {
  const ClientCommissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionTitle(
            title: 'Commission rules',
            subtitle: 'Rules agreed with Abra Travels for platform ticketing',
            breadcrumbs: ['Money', 'Commission'],
          ),
          const SizedBox(height: AbraSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(AbraSpacing.lg),
                  child: Text('Active commission rule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Divider(height: 1, color: AbraColors.divider),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.percent, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: 12),
                        Text(
                          'Not connected yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Commission rules for operators are built in Phase 2.',
                          style: TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Interactive calculator
          Container(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live fare & payout calculator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 12),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Not connected yet',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AbraColors.textSecondary),
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
}
