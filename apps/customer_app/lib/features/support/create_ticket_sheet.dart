import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/ui/adaptive_sheet.dart';
import 'models/support_models.dart';

class CreateTicketSheet extends ConsumerStatefulWidget {
  const CreateTicketSheet({this.initialBookingId, super.key});

  final String? initialBookingId;

  static Future<SupportTicket?> show(
    BuildContext context, {
    String? bookingId,
  }) {
    return showAdaptiveSheet<SupportTicket>(
      context,
      builder: (context) => CreateTicketSheet(initialBookingId: bookingId),
    );
  }

  @override
  ConsumerState<CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.initialBookingId != null ? 'BOOKING' : 'APP';
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _hasScreenshot = false;

  static const _categories = <(String key, String label)>[
    ('BOOKING', 'Booking issue'),
    ('PAYMENT', 'Payment / Transaction'),
    ('REFUND', 'Refund status'),
    ('SAFETY', 'Safety / Driver conduct'),
    ('APP', 'General app query'),
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Create a support ticket',
      onClose: () => Navigator.of(context).pop(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Tell us what went wrong and our team will get back to you within a few hours.',
                style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AbraSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c.$1, child: Text(c.$2));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: AbraSpacing.md),
              if (widget.initialBookingId != null) ...[
                TextFormField(
                  initialValue: widget.initialBookingId,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Linked Booking',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                  ),
                ),
                const SizedBox(height: AbraSpacing.md),
              ],
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Refund not received',
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 4) {
                    return 'Please enter a subject (min 4 chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  alignLabelWithHint: true,
                  hintText: 'Please share details so we can help faster...',
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 8) {
                    return 'Please describe the problem with more details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AbraSpacing.md),
              InkWell(
                onTap: () => setState(() => _hasScreenshot = !_hasScreenshot),
                borderRadius: AbraRadius.medium,
                child: Container(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _hasScreenshot
                          ? AbraColors.blue
                          : AbraColors.border,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: AbraRadius.medium,
                    color: _hasScreenshot ? AbraColors.lightBlue : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasScreenshot
                            ? Icons.check_circle
                            : Icons.attach_file,
                        color: _hasScreenshot
                            ? AbraColors.blue
                            : AbraColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AbraSpacing.sm),
                      Expanded(
                        child: Text(
                          _hasScreenshot
                              ? 'Screenshot attached (screenshot.png)'
                              : 'Attach screenshot or proof (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hasScreenshot
                                ? AbraColors.blueDark
                                : AbraColors.textSecondary,
                            fontWeight: _hasScreenshot
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  const Expanded(
                    child: Tooltip(
                      message: 'Not connected yet',
                      child: FilledButton(
                        onPressed: null,
                        child: Text('Submit Ticket'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
