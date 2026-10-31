import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/ui/adaptive_sheet.dart';
import 'controllers/support_controller.dart';
import 'models/support_models.dart';
import 'proof_picker.dart';
import 'repositories/support_repository.dart';

/// Raise a ticket: category, subject, what went wrong, and a screenshot or other proof if the
/// customer has one. The proof is stored first, then the ticket is created with it.
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
  final _bookingController = TextEditingController();
  PickedProof? _proof;
  bool _submitting = false;
  String? _problem;

  static const _categories = <(String key, String label)>[
    ('BOOKING', 'Booking issue'),
    ('PAYMENT', 'Payment / Transaction'),
    ('REFUND', 'Refund status'),
    ('SAFETY', 'Safety / Driver conduct'),
    ('APP', 'General app query'),
  ];

  @override
  void initState() {
    super.initState();
    _bookingController.text = widget.initialBookingId ?? '';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _bookingController.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_proof != null) {
      setState(() => _proof = null);
      return;
    }
    final picked = await ref.read(proofPickerProvider)();
    if (picked != null && mounted) setState(() => _proof = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _problem = null;
    });
    try {
      final proof = _proof;
      final proofId = proof == null
          ? null
          : await ref.read(supportRepositoryProvider).uploadProof(name: proof.name, bytes: proof.bytes);
      final ticket = await ref.read(supportTicketsProvider.notifier).createTicket(
        subject: _subjectController.text.trim(),
        category: _category,
        message: _messageController.text.trim(),
        bookingId: _bookingController.text.trim(),
        attachments: <String>[?proofId],
      );
      if (mounted) Navigator.of(context).pop(ticket);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _problem = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attached = _proof != null;
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
                'Tell us what went wrong. Our team will reply here within a day.',
                style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AbraSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
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
              TextFormField(
                controller: _bookingController,
                readOnly: widget.initialBookingId != null,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Booking number (optional)',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
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
                onTap: _submitting ? null : _choose,
                borderRadius: AbraRadius.medium,
                child: Container(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: attached ? AbraColors.blue : AbraColors.border),
                    borderRadius: AbraRadius.medium,
                    color: attached ? AbraColors.lightBlue : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        attached ? Icons.check_circle : Icons.attach_file,
                        color: attached ? AbraColors.blue : AbraColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AbraSpacing.sm),
                      Expanded(
                        child: Text(
                          attached
                              ? '${_proof!.name} - tap to remove'
                              : 'Attach a screenshot or proof (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            color: attached ? AbraColors.blueDark : AbraColors.textSecondary,
                            fontWeight: attached ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_problem != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Text(_problem!, style: const TextStyle(color: AbraColors.danger)),
              ],
              const SizedBox(height: AbraSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Sending...' : 'Submit Ticket'),
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
