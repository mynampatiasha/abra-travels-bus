import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../../routing/portal_routes.dart';

class ClientKycVerificationScreen extends StatefulWidget {
  const ClientKycVerificationScreen({super.key});

  @override
  State<ClientKycVerificationScreen> createState() =>
      _ClientKycVerificationScreenState();
}

class _ClientKycVerificationScreenState
    extends State<ClientKycVerificationScreen> {
  int _wizardStep = 1;

  // Wizard state (DRAFT)
  final TextEditingController _companyNameController =
      TextEditingController(text: 'New Horizon Travels');
  final Map<String, dynamic> _answers = {
    'business_type': 'Company',
    'fleet_size': '3-5',
    'ac_type': 'Both AC and Non-AC',
    'gst_registered': 'Yes',
  };
  final Map<String, String> _draftDocs = {
    'company_reg': 'incorporation_certificate.pdf',
    'pan': 'company_pan_card.pdf',
    'bank': 'cancelled_cheque.pdf',
  };

  // REJECTED state mock documents
  final List<Map<String, dynamic>> _rejectedDocs = [
    {
      'key': 'gst',
      'name': 'GST Registration Certificate',
      'file': 'gst_reg_06_scan.pdf',
      'status': 'REJECTED',
      'reason': 'Document is blurry. Upload a clear scan.',
      'fixed': false,
    },
    {
      'key': 'pan',
      'name': 'Company PAN Card',
      'file': 'kaveri_pan_card.pdf',
      'status': 'ACCEPTED',
      'reason': '',
      'fixed': false,
    },
    {
      'key': 'company_reg',
      'name': 'Company Registration',
      'file': 'certificate_of_incorp.pdf',
      'status': 'ACCEPTED',
      'reason': '',
      'fixed': false,
    },
    {
      'key': 'bank',
      'name': 'Cancelled Cheque',
      'file': 'cancelled_cheque.pdf',
      'status': 'ACCEPTED',
      'reason': '',
      'fixed': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    kActiveKycStateNotifier.addListener(_onKycStateChanged);
  }

  @override
  void dispose() {
    kActiveKycStateNotifier.removeListener(_onKycStateChanged);
    _companyNameController.dispose();
    super.dispose();
  }

  void _onKycStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = kActiveKycState;
    final subtitle = st == 'APPROVED'
        ? 'Verified'
        : st == 'PENDING'
            ? 'Waiting for Abra'
            : st == 'REJECTED'
                ? 'Needs fixing'
                : 'Step $_wizardStep of 3';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'KYC verification',
            subtitle: subtitle,
            breadcrumbs: const ['Company', 'KYC'],
          ),
          const SizedBox(height: AbraSpacing.lg),

          // Portal lock banner shown when company is not approved
          if (st != 'APPROVED') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AbraColors.skyContainer,
                borderRadius: BorderRadius.circular(AbraRadius.md),
                border: Border.all(color: AbraColors.blue.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: AbraColors.deepBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dashboard, buses, trips and sales open after Abra approves your company.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AbraColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.xl),
          ],

          if (st == 'APPROVED') _buildApprovedView(),
          if (st == 'PENDING') _buildPendingView(),
          if (st == 'REJECTED') _buildRejectedView(),
          if (st == 'DRAFT') _buildDraftWizardView(),
        ],
      ),
    );
  }


  // ==========================================
  // 1. APPROVED VIEW
  // ==========================================
  Widget _buildApprovedView() {
    final me = kMockMe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          decoration: BoxDecoration(
            color: AbraColors.tealContainer,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.teal.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, color: AbraColors.teal, size: 28),
              const SizedBox(width: AbraSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your company is verified.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AbraColors.tealDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Buses, trips, staff and sales are open.',
                      style: TextStyle(
                        color: AbraColors.tealDark,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.dashboard_outlined, size: 16),
                label: const Text('Open Dashboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: AbraColors.tealDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => context.go(PortalRoutes.dashboard),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.border),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your documents',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Verified by Abra team',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AbraColors.tealDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              _docRow('Certificate of Incorporation', 'Expires 2030-01-01', 'ACCEPTED'),
              const Divider(height: 20),
              _docRow('Company PAN Card (29AABCK1234A1Z5)', 'Permanent', 'ACCEPTED'),
              const Divider(height: 20),
              _docRow('GST Registration Certificate', 'Verified on GST portal', 'ACCEPTED'),
              const Divider(height: 20),
              _docRow(
                'Bank Account / Cancelled Cheque (${(me['bank'] as Map<String, dynamic>?)?['ifsc'] ?? 'HDFC0001234'})',
                'Account verified for automatic payouts',
                'ACCEPTED',
              ),
              const SizedBox(height: AbraSpacing.lg),
              const Text(
                'To change a verified document, contact Abra support. Bus documents are managed in Fleet > Buses.',
                style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. PENDING VIEW
  // ==========================================
  Widget _buildPendingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.border),
            boxShadow: AbraShadows.soft,
          ),
          child: Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AbraColors.orangeContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    size: 36,
                    color: AbraColors.orangeDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Under verification',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 520,
                  child: Text(
                    'The Abra team is reviewing your documents, usually within 1 to 2 working days. This screen updates by itself when they decide.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AbraColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Vertical Timeline
                Container(
                  width: 460,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AbraColors.lightGray,
                    borderRadius: BorderRadius.circular(AbraRadius.md),
                  ),
                  child: Column(
                    children: [
                      _timelineStep(
                        'Submitted',
                        '14 Oct 2026, 10:00 AM',
                        isCompleted: true,
                        isActive: false,
                      ),
                      _timelineStep(
                        'Review in progress',
                        'Abra Compliance Team is inspecting scans',
                        isCompleted: false,
                        isActive: true,
                      ),
                      _timelineStep(
                        'Decision pending',
                        'You will be notified here, by email and on WhatsApp',
                        isCompleted: false,
                        isActive: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.border),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What you sent',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AbraSpacing.md),
              _submittedDocRow('Company Registration', 'certificate_of_incorp.pdf', 'In review'),
              const Divider(height: 20),
              _submittedDocRow('PAN Card', 'kaveri_pan_card.pdf', 'In review'),
              const Divider(height: 20),
              _submittedDocRow('Cancelled Cheque', 'cancelled_cheque.pdf', 'In review'),
              const Divider(height: 20),
              _submittedDocRow('GST Certificate', 'gst_registration_cert.pdf', 'In review'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _submittedDocRow(String name, String fileName, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined, color: AbraColors.blue, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(fileName, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AbraColors.orangeContainer,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AbraColors.orangeDark,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. REJECTED VIEW
  // ==========================================
  Widget _buildRejectedView() {
    final unreplacedCount = _rejectedDocs
        .where((d) => d['status'] == 'REJECTED' && d['fixed'] != true)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          decoration: BoxDecoration(
            color: AbraColors.dangerContainer,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AbraColors.danger, size: 28),
              SizedBox(width: AbraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Some documents need fixing.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AbraColors.danger,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Replace only the rejected ones, then send them again. Accepted documents and your answers are locked.',
                      style: TextStyle(color: AbraColors.danger, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            return Wrap(
              spacing: AbraSpacing.md,
              runSpacing: AbraSpacing.md,
              children: _rejectedDocs.map((d) {
                final isRejected = d['status'] == 'REJECTED';
                final isFixed = d['fixed'] == true;
                final width = isNarrow ? constraints.maxWidth : (constraints.maxWidth - AbraSpacing.md) / 2;

                return SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(AbraSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AbraRadius.lg),
                      border: Border.all(
                        color: isRejected && !isFixed
                            ? AbraColors.danger.withValues(alpha: 0.4)
                            : AbraColors.border,
                      ),
                      boxShadow: AbraShadows.soft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                d['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            if (isFixed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AbraColors.skyContainer,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'Replaced',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AbraColors.blue,
                                  ),
                                ),
                              )
                            else
                              PortalStatusChip(status: d['status'] as String),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (isRejected && !isFixed) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AbraColors.dangerContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Reason: ${d['reason']}',
                              style: const TextStyle(fontSize: 12, color: AbraColors.danger),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: const Text('Replace'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AbraColors.danger,
                              side: const BorderSide(color: AbraColors.danger),
                            ),
                            onPressed: () {
                              _showUploadDialog(
                                title: 'Replace ${d['name']}',
                                info: 'Reason from Abra: ${d['reason']}',
                                onFileSelected: (filename) {
                                  setState(() {
                                    d['file'] = filename;
                                    d['fixed'] = true;
                                  });
                                },
                              );
                            },
                          ),
                        ] else ...[
                          Text(
                            '${d['file']}${d['status'] == 'ACCEPTED' ? ' · locked' : ''}',
                            style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                          ),
                          if (isFixed) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.check_circle, size: 14, color: AbraColors.teal),
                                SizedBox(width: 4),
                                Text(
                                  'New file ready for review',
                                  style: TextStyle(fontSize: 11, color: AbraColors.tealDark, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: AbraSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.md),
            border: Border.all(color: AbraColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unreplacedCount > 0
                    ? '$unreplacedCount document(s) still to replace'
                    : 'All corrections are ready.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: unreplacedCount > 0 ? AbraColors.danger : AbraColors.tealDark,
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: unreplacedCount == 0 ? AbraColors.blue : Colors.grey.shade400,
                ),
                onPressed: unreplacedCount == 0
                    ? () {
                        for (final d in _rejectedDocs) {
                          if (d['fixed'] == true) {
                            d['status'] = 'PENDING';
                            d['reason'] = '';
                            d['fixed'] = false;
                          }
                        }
                        kActiveKycState = 'PENDING';
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Corrections sent for review'),
                            backgroundColor: AbraColors.tealDark,
                          ),
                        );
                      }
                    : null,
                child: const Text('Send corrections'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. DRAFT WIZARD VIEW (3-Step Pipeline)
  // ==========================================
  Widget _buildDraftWizardView() {
    // Evaluate active document requirements based on answers
    final isGstRegistered = _answers['gst_registered'] == 'Yes';
    final activeDocTypes = kMockDocTypes.where((doc) {
      if (doc['key'] == 'gst' && !isGstRegistered) return false;
      return true;
    }).toList();

    final allQuestionsAnswered = _companyNameController.text.trim().isNotEmpty &&
        kMockKycQuestions.every((q) {
          if (q['required'] == true) {
            final ans = _answers[q['key']];
            return ans != null && ans.toString().isNotEmpty;
          }
          return true;
        });

    final allRequiredDocsUploaded = activeDocTypes.every((doc) {
      final isReq = doc['required'] == true || (doc['key'] == 'gst' && isGstRegistered);
      if (isReq) {
        return _draftDocs.containsKey(doc['key']);
      }
      return true;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3-step indicator matching prototype
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            border: Border.all(color: AbraColors.border),
          ),
          child: Row(
            children: [
              _stepItem(1, 'Your company'),
              const Expanded(child: Divider(indent: 12, endIndent: 12)),
              _stepItem(2, 'Documents'),
              const Expanded(child: Divider(indent: 12, endIndent: 12)),
              _stepItem(3, 'Review & Submit'),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),

        // STEP 1: Questions configured by Admin
        if (_wizardStep == 1) ...[
          Container(
            padding: const EdgeInsets.all(AbraSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _companyNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Company name *',
                    hintText: 'e.g. New Horizon Travels',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AbraSpacing.xl),
                // Dynamic Questionnaire configured in admin KYC
                ...kMockKycQuestions.map((q) {
                  final key = q['key'] as String;
                  final label = q['label'] as String;
                  final opts = (q['opts'] as List<dynamic>).cast<String>();
                  final currentVal = _answers[key] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: opts.map((opt) {
                            final sel = currentVal == opt;
                            return ChoiceChip(
                              label: Text(opt),
                              selected: sel,
                              selectedColor: AbraColors.blue,
                              labelStyle: TextStyle(
                                color: sel ? Colors.white : AbraColors.textPrimary,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _answers[key] = opt);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'These questions are set by Abra (admin app, KYC questionnaire). Your answers decide which documents you need.',
                  style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Save and see documents'),
                style: FilledButton.styleFrom(
                  backgroundColor: allQuestionsAnswered ? AbraColors.blue : Colors.grey.shade400,
                ),
                onPressed: allQuestionsAnswered
                    ? () => setState(() => _wizardStep = 2)
                    : null,
              ),
              if (!allQuestionsAnswered) ...[
                const SizedBox(width: 12),
                const Text(
                  'Answer all required questions (*)',
                  style: TextStyle(fontSize: 12, color: AbraColors.danger),
                ),
              ],
            ],
          ),
        ],

        // STEP 2: Document Rules Pipeline
        if (_wizardStep == 2) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              return Wrap(
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.md,
                children: activeDocTypes.map((doc) {
                  final key = doc['key'] as String;
                  final name = doc['name'] as String;
                  final isReq = doc['required'] == true || (key == 'gst' && isGstRegistered);
                  final instr = doc['instr'] as String;
                  final types = doc['types'] as String;
                  final maxMb = doc['maxMb'];
                  final uploadedFile = _draftDocs[key];
                  final width = isNarrow ? constraints.maxWidth : (constraints.maxWidth - AbraSpacing.md) / 2;

                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(AbraSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AbraRadius.lg),
                        border: Border.all(color: AbraColors.border),
                        boxShadow: AbraShadows.soft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$name${isReq ? ' *' : ' (optional)'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              PortalStatusChip(
                                status: uploadedFile != null ? 'UPLOADED' : 'PENDING',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$instr · $types, up to $maxMb MB',
                            style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary),
                          ),
                          if (uploadedFile != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: AbraColors.teal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    uploadedFile,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AbraColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: Text(uploadedFile != null ? 'Replace' : 'Upload'),
                            onPressed: () {
                              _showUploadDialog(
                                title: '${uploadedFile != null ? 'Replace' : 'Upload'} $name',
                                info: '$instr $types, up to $maxMb MB.',
                                onFileSelected: (filename) {
                                  setState(() {
                                    _draftDocs[key] = filename;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AbraSpacing.xl),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Edit answers'),
                onPressed: () => setState(() => _wizardStep = 1),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Review and submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: allRequiredDocsUploaded ? AbraColors.blue : Colors.grey.shade400,
                ),
                onPressed: allRequiredDocsUploaded
                    ? () => setState(() => _wizardStep = 3)
                    : null,
              ),
              if (!allRequiredDocsUploaded) ...[
                const SizedBox(width: 12),
                const Text(
                  'Upload all required documents (*)',
                  style: TextStyle(fontSize: 12, color: AbraColors.danger),
                ),
              ],
            ],
          ),
        ],

        // STEP 3: Review and Submission
        if (_wizardStep == 3) ...[
          Container(
            padding: const EdgeInsets.all(AbraSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AbraSpacing.md),
                _statRow('Company name', _companyNameController.text.trim()),
                for (final q in kMockKycQuestions)
                  _statRow(q['label'].toString().replaceAll(' *', ''), _answers[q['key']]?.toString() ?? '-'),
                const Divider(height: 28),
                Text(
                  'Uploaded Documents (${_draftDocs.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 10),
                for (final entry in _draftDocs.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AbraColors.teal),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AbraColors.skyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.md),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AbraColors.deepBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After you submit, your answers and documents are locked until Abra decides.',
                    style: TextStyle(fontSize: 12, color: AbraColors.deepBlue, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                onPressed: () => setState(() => _wizardStep = 2),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit for verification'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.tealDark),
                onPressed: () {
                  kActiveKycState = 'PENDING';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sent. Abra is reviewing your documents.'),
                      backgroundColor: AbraColors.tealDark,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ==========================================
  // UPLOAD DIALOG (Matching prototypes/client_demo_model.html lines 730-734)
  // ==========================================
  void _showUploadDialog({
    required String title,
    required String info,
    required void Function(String filename) onFileSelected,
  }) {
    String? selectedOption = 'ok'; // 'ok', 'type', 'big'
    String? errorMessage;
    String? successMessage = 'scan.pdf is ready to upload.';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  const Text('Pick a sample file:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 8),
                  _sampleFileTile(
                    label: 'scan.pdf · 1.2 MB',
                    isSelected: selectedOption == 'ok',
                    onTap: () {
                      setDialogState(() {
                        selectedOption = 'ok';
                        errorMessage = null;
                        successMessage = 'scan.pdf is ready to upload.';
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  _sampleFileTile(
                    label: 'photo.heic · 2 MB (wrong type)',
                    isSelected: selectedOption == 'type',
                    onTap: () {
                      setDialogState(() {
                        selectedOption = 'type';
                        errorMessage = 'This file type is not allowed. Use PDF, JPG or PNG.';
                        successMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  _sampleFileTile(
                    label: 'scan.pdf · 18 MB (too large)',
                    isSelected: selectedOption == 'big',
                    onTap: () {
                      setDialogState(() {
                        selectedOption = 'big';
                        errorMessage = 'The file is larger than 5 MB.';
                        successMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AbraColors.dangerContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AbraColors.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(fontSize: 11, color: AbraColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (successMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AbraColors.tealContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: AbraColors.tealDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              successMessage!,
                              style: const TextStyle(fontSize: 11, color: AbraColors.tealDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: selectedOption == 'ok' ? AbraColors.blue : Colors.grey.shade400,
                ),
                onPressed: selectedOption == 'ok'
                    ? () {
                        Navigator.pop(ctx);
                        onFileSelected('scan.pdf');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Uploaded scan.pdf'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                child: const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sampleFileTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AbraRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AbraColors.lightBlue : AbraColors.lightGray,
          borderRadius: BorderRadius.circular(AbraRadius.sm),
          border: Border.all(
            color: isSelected ? AbraColors.blue : AbraColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 16,
              color: isSelected ? AbraColors.blue : AbraColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AbraColors.deepBlue : AbraColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: AbraColors.blue),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHARED HELPERS
  // ==========================================
  Widget _stepItem(int step, String label) {
    final isDone = _wizardStep > step;
    final isCurrent = _wizardStep == step;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone ? AbraColors.teal : (isCurrent ? AbraColors.blue : AbraColors.border),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
            color: isCurrent ? AbraColors.navy : AbraColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _docRow(String name, String sub, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined, color: AbraColors.blue, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(sub, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
        PortalStatusChip(status: status),
      ],
    );
  }

  Widget _timelineStep(
    String title,
    String subtitle, {
    required bool isCompleted,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : isActive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
            size: 18,
            color: isCompleted
                ? AbraColors.teal
                : isActive
                    ? AbraColors.orangeDark
                    : AbraColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isActive ? AbraColors.orangeDark : AbraColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
