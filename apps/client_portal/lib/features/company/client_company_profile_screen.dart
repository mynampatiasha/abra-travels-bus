import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/failure_text.dart';
import '../../core/widgets/portal_info_banner.dart';
import '../../core/widgets/portal_section_title.dart';

final clientCompanyProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async => (await ref.watch(appDependenciesProvider).apiClient.get('client/company'))
      .decodeObject((json) => json),
);

final _emailPattern = RegExp(r'^\S+@\S+\.\S+$');
final _gstinPattern = RegExp(r'^\d{2}[A-Za-z]{5}\d{4}[A-Za-z][A-Za-z0-9]Z[A-Za-z0-9]$');
final _accountPattern = RegExp(r'^\d{6,18}$');
final _ifscPattern = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');

class ClientCompanyProfileScreen extends ConsumerWidget {
  const ClientCompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<JsonMap>(
      value: ref.watch(clientCompanyProvider),
      onRetry: () => ref.invalidate(clientCompanyProvider),
      data: (context, company) => _ClientCompanyProfileContent(company: company),
    );
  }
}

class _ClientCompanyProfileContent extends ConsumerStatefulWidget {
  const _ClientCompanyProfileContent({required this.company});

  final JsonMap company;

  @override
  ConsumerState<_ClientCompanyProfileContent> createState() => _ClientCompanyProfileContentState();
}

class _ClientCompanyProfileContentState extends ConsumerState<_ClientCompanyProfileContent> {
  final _profileForm = GlobalKey<FormState>();
  final _bankForm = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _gstCtrl;

  late final TextEditingController _bankHolderCtrl;
  late final TextEditingController _bankAccCtrl;
  late final TextEditingController _bankIfscCtrl;

  bool _isSavingProfile = false;
  bool _isSavingBank = false;
  String? _successMessage;
  String? _errorMessage;

  JsonMap? get _bank => widget.company['bank'] is Map
      ? asJsonMap(widget.company['bank'] as Map)
      : null;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _nameCtrl = TextEditingController(text: '${c['companyName'] ?? ''}');
    _ownerCtrl = TextEditingController(text: '${c['ownerName'] ?? ''}');
    _emailCtrl = TextEditingController(text: '${c['email'] ?? ''}');
    _phoneCtrl = TextEditingController(text: '${c['supportPhone'] ?? ''}');
    _cityCtrl = TextEditingController(text: '${c['city'] ?? ''}');
    _gstCtrl = TextEditingController(text: '${c['gstin'] ?? ''}');

    final bank = _bank;
    _bankHolderCtrl = TextEditingController(text: '${bank?['holderName'] ?? ''}');
    _bankAccCtrl = TextEditingController();
    _bankIfscCtrl = TextEditingController(text: '${bank?['ifsc'] ?? ''}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _gstCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankAccCtrl.dispose();
    _bankIfscCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_profileForm.currentState?.validate() ?? false)) return;
    setState(() {
      _isSavingProfile = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(appDependenciesProvider).apiClient.put(
        'client/company',
        body: <String, Object?>{
          'companyName': _nameCtrl.text.trim(),
          'ownerName': _ownerCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'supportPhone': _phoneCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'gstin': _gstCtrl.text.trim(),
        },
      );
      ref.invalidate(clientCompanyProvider);
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _successMessage = 'Company details updated successfully.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved profile details')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _errorMessage = failureText(AbraLocalizations.of(context), e);
        });
      }
    }
  }

  Future<void> _saveBank() async {
    if (!(_bankForm.currentState?.validate() ?? false)) return;
    setState(() {
      _isSavingBank = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(appDependenciesProvider).apiClient.put(
        'client/company/bank',
        body: <String, Object?>{
          'holderName': _bankHolderCtrl.text.trim(),
          'accountNumber': _bankAccCtrl.text.trim(),
          'ifsc': _bankIfscCtrl.text.trim().toUpperCase(),
        },
      );
      _bankAccCtrl.clear();
      ref.invalidate(clientCompanyProvider);
      if (mounted) {
        setState(() {
          _isSavingBank = false;
          _successMessage = 'Bank account saved. Abra will verify the account.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details submitted for verification')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSavingBank = false;
          _errorMessage = failureText(AbraLocalizations.of(context), e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(accessProvider).can(PermissionKeys.operatorsUpdate);
    final bank = _bank;
    final status = '${bank?['status'] ?? 'PENDING'}';
    final note = '${bank?['note'] ?? ''}';
    final isAuto = widget.company['payoutMode'] == 'AUTO_SPLIT';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionTitle(
            title: 'Company profile',
            subtitle: 'Your public and payout details',
            breadcrumbs: ['Company', 'Profile'],
          ),
          const SizedBox(height: AbraSpacing.xl),
          if (_successMessage != null) ...[
            PortalInfoBanner(
              message: _successMessage!,
              tone: PortalBannerTone.success,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: AbraSpacing.lg),
          ],
          if (_errorMessage != null) ...[
            PortalInfoBanner(
              message: _errorMessage!,
              tone: PortalBannerTone.warning,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: AbraSpacing.lg),
          ],
          _card(
            context,
            title: 'Company information',
            child: Form(
              key: _profileForm,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Company name *',
                          _nameCtrl,
                          enabled: canEdit && !_isSavingProfile,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: _field(
                          'Owner name *',
                          _ownerCtrl,
                          enabled: canEdit && !_isSavingProfile,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Contact email *',
                          _emailCtrl,
                          enabled: canEdit && !_isSavingProfile,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) => _emailPattern.hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: _field(
                          'Contact phone',
                          _phoneCtrl,
                          enabled: canEdit && !_isSavingProfile,
                          keyboard: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Headquarters city',
                          _cityCtrl,
                          enabled: canEdit && !_isSavingProfile,
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: _field(
                          'GSTIN',
                          _gstCtrl,
                          enabled: canEdit && !_isSavingProfile,
                          validator: (v) => (v == null || v.trim().isEmpty || _gstinPattern.hasMatch(v.trim()))
                              ? null
                              : 'Looks wrong, e.g. 36ABCDE1234F1Z5',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.lg),
                  if (canEdit)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        child: _isSavingProfile
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save details'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          _card(
            context,
            title: 'Payout bank account',
            child: Form(
              key: _bankForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AbraSpacing.md),
                    decoration: BoxDecoration(
                      color: AbraColors.orangeContainer,
                      borderRadius: BorderRadius.circular(AbraRadius.md),
                    ),
                    child: const Text(
                      'Changing the bank account pauses payouts until Abra verifies it.',
                      style: TextStyle(color: AbraColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Account holder *',
                          _bankHolderCtrl,
                          enabled: canEdit && !_isSavingBank,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: _field(
                          'Account number *',
                          _bankAccCtrl,
                          enabled: canEdit && !_isSavingBank,
                          keyboard: TextInputType.number,
                          helperText: bank == null
                              ? null
                              : 'Saved: XXXXXX${bank['accountLast4']}. Type number again to change.',
                          validator: (v) => _accountPattern.hasMatch((v ?? '').trim()) ? null : 'Enter 6 to 18 digits',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          'IFSC code *',
                          _bankIfscCtrl,
                          enabled: canEdit && !_isSavingBank,
                          validator: (v) => _ifscPattern.hasMatch((v ?? '').trim().toUpperCase())
                              ? null
                              : 'Looks wrong, e.g. HDFC0001234',
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Verification status: ', style: TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
                                  AbraStatusBadge(
                                    label: bank == null
                                        ? 'Not added'
                                        : switch (status) {
                                            'VERIFIED' => 'Verified',
                                            'FAILED' => 'Failed',
                                            _ => 'Pending',
                                          },
                                    tone: bank == null
                                        ? AbraStatusTone.neutral
                                        : switch (status) {
                                            'VERIFIED' => AbraStatusTone.success,
                                            'FAILED' => AbraStatusTone.danger,
                                            _ => AbraStatusTone.warning,
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Settlement mode: ${isAuto ? 'Automatic (Razorpay Route)' : 'Manual settlement'}',
                                style: const TextStyle(color: AbraColors.tealDark, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: AbraSpacing.sm),
                    Text(
                      'Abra could not verify it: $note',
                      style: const TextStyle(color: AbraColors.danger, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: AbraSpacing.lg),
                  if (canEdit)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                        onPressed: _isSavingBank ? null : _saveBank,
                        child: _isSavingBank
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save bank details'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
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
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AbraSpacing.lg),
          child,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    TextInputType? keyboard,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            helperText: helperText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AbraRadius.md),
              borderSide: const BorderSide(color: AbraColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

