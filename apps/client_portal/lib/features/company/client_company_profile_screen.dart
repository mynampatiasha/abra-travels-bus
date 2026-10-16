import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_info_banner.dart';
import '../../core/widgets/portal_section_title.dart';

class ClientCompanyProfileScreen extends StatefulWidget {
  const ClientCompanyProfileScreen({super.key});

  @override
  State<ClientCompanyProfileScreen> createState() => _ClientCompanyProfileScreenState();
}

class _ClientCompanyProfileScreenState extends State<ClientCompanyProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _bankHolderCtrl;
  late final TextEditingController _bankAccCtrl;
  late final TextEditingController _bankIfscCtrl;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final me = kMockMe;
    _nameCtrl = TextEditingController(text: '${me['name']}');
    _ownerCtrl = TextEditingController(text: '${me['owner']}');
    _emailCtrl = TextEditingController(text: '${me['email']}');
    _phoneCtrl = TextEditingController(text: '${me['phone']}');
    _cityCtrl = TextEditingController(text: '${me['city']}');
    _gstCtrl = TextEditingController(text: '${me['gst']}');
    final bank = me['bank'] as Map<String, dynamic>? ?? {};
    _bankHolderCtrl = TextEditingController(text: '${bank['holder'] ?? ''}');
    _bankAccCtrl = TextEditingController(text: '${bank['acc'] ?? ''}');
    _bankIfscCtrl = TextEditingController(text: '${bank['ifsc'] ?? ''}');
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

  @override
  Widget build(BuildContext context) {
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
          if (_isSaved) ...[
            const PortalInfoBanner(
              message: 'Company profile details updated successfully.',
              tone: PortalBannerTone.success,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: AbraSpacing.lg),
          ],
          _card(
            context,
            title: 'Company information',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _field('Company name *', _nameCtrl)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: _field('Owner name *', _ownerCtrl)),
                  ],
                ),
                const SizedBox(height: AbraSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field('Contact email *', _emailCtrl)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: _field('Contact phone *', _phoneCtrl)),
                  ],
                ),
                const SizedBox(height: AbraSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field('Headquarters city *', _cityCtrl)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: _field('GSTIN', _gstCtrl)),
                  ],
                ),
                const SizedBox(height: AbraSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                    onPressed: () {
                      setState(() => _isSaved = true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved profile')));
                    },
                    child: const Text('Save details'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          _card(
            context,
            title: 'Payout bank account',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _field('Account holder *', _bankHolderCtrl)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: _field('Account number *', _bankAccCtrl)),
                  ],
                ),
                const SizedBox(height: AbraSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field('IFSC code *', _bankIfscCtrl)),
                    const SizedBox(width: AbraSpacing.md),
                    const Expanded(
                      child: Text('Settlement mode: Automatic daily (Abra verified)',
                        style: TextStyle(color: AbraColors.tealDark, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
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

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md), borderSide: const BorderSide(color: AbraColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
