import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

// ===== 1. MODELS =====
enum SosCategory {
  accident('Accident'),
  breakdown('Breakdown'),
  medical('Medical emergency'),
  threat('Threat or fight');

  const SosCategory(this.label);
  final String label;
}

// ===== 2. CONTROLLER & SHEET =====
class SosDriverSheet extends ConsumerStatefulWidget {
  const SosDriverSheet({
    required this.tripId,
    super.key,
  });

  final String tripId;

  static Future<void> show(BuildContext context, String tripId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SosDriverSheet(tripId: tripId),
    );
  }

  @override
  ConsumerState<SosDriverSheet> createState() => _SosDriverSheetState();
}

class _SosDriverSheetState extends ConsumerState<SosDriverSheet> {
  SosCategory _selectedCategory = SosCategory.accident;
  bool _hasPhoto = false;
  bool _sending = false;

  void _submitSos() {
    setState(() => _sending = true);
    final db = ref.read(driverMockDbProvider);
    db.sendSos(
      tripId: widget.tripId,
      reason: _selectedCategory.label,
      note: _hasPhoto ? 'Photo evidence attached' : '',
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'SOS alert sent. Abra safety team is calling you immediately.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Emergency SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What happened?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          for (final cat in SosCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _selectedCategory == cat
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFF8FAFC),
                    border: Border.all(
                      color: _selectedCategory == cat
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedCategory == cat
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _selectedCategory == cat
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedCategory == cat
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Abra's safety team and your company get your location at once. Call 112 if anyone is hurt.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Proof photo simulation
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
              _hasPhoto ? Icons.check_circle : Icons.camera_alt_outlined,
              color: _hasPhoto ? const Color(0xFF10B981) : const Color(0xFF64748B),
            ),
            label: Text(
              _hasPhoto ? 'Photo attached (photo_situation.jpg)' : 'Attach situation photo (optional)',
              style: TextStyle(
                color: _hasPhoto ? const Color(0xFF10B981) : const Color(0xFF334155),
              ),
            ),
            onPressed: () {
              setState(() => _hasPhoto = !_hasPhoto);
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.emergency_rounded),
                  label: _sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Send SOS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  onPressed: _sending ? null : _submitSos,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
