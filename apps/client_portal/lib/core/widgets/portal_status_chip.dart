import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Pill status chip matching the demo .st class.
class PortalStatusChip extends StatelessWidget {
  const PortalStatusChip({
    required this.status,
    this.label,
    super.key,
  });

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(status);
    final colors = AbraStatusColors.from(context).of(tone);
    final displayLabel = label ?? _label(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: BorderRadius.circular(AbraRadius.pill),
      ),
      child: Text(
        displayLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static AbraStatusTone _tone(String status) {
    const success = {'ACTIVE','APPROVED','PUBLISHED','PAID','COMPLETED','CONFIRMED','VERIFIED','RESOLVED','ACCEPTED','LIVE','ARRIVED'};
    const warning = {'PENDING','PENDING_APPROVAL','UNDER_REVIEW','INITIATED','PROCESSING','ON_HOLD','DELAYED','OPEN','SCHEDULED','BOARDING','MAINTENANCE','SENT'};
    const danger = {'REJECTED','FAILED','SUSPENDED','BLOCKED','ESCALATED','SIGNAL_LOST','CANCELLED','EXPIRED','NEW'};
    const info = {'IN_TRANSIT','IN_PROGRESS','ACKNOWLEDGED','INVITED','DRAFT'};
    if (success.contains(status)) return AbraStatusTone.success;
    if (warning.contains(status)) return AbraStatusTone.warning;
    if (danger.contains(status)) return AbraStatusTone.danger;
    if (info.contains(status)) return AbraStatusTone.info;
    return AbraStatusTone.neutral;
  }

  static String _label(String status) =>
      status.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(
        RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
}
