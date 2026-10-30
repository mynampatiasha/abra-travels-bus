import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/ui/gradient_header.dart';
import 'profile_repository.dart';

/// Edit profile: name and email are saved to the server, the mobile number
/// is shown but cannot be changed here.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Edit profile'),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: AsyncValueView<CustomerProfile>(
          value: ref.watch(customerProfileProvider),
          onRetry: () => ref.invalidate(customerProfileProvider),
          data: (context, profile) => _ProfileForm(profile: profile),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final CustomerProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _email = TextEditingController(text: widget.profile.email);
  bool _saving = false;
  String? _emailProblem;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _emailProblem = null;
      _problem = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(name: _name.text.trim(), email: _email.text.trim());
      // The Profile tab shows the name from the signed-in user
      await ref.read(sessionManagerProvider).reloadUser();
      ref.invalidate(customerProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } on ProfileProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.field == 'email') {
          _emailProblem = problem.message;
        } else {
          _problem = problem.message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        children: <Widget>[
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: AbraRadius.medium),
            ),
            validator: (value) => value == null || value.trim().length < 2
                ? 'Please enter your full name'
                : null,
          ),
          const SizedBox(height: AbraSpacing.lg),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(borderRadius: AbraRadius.medium),
              errorText: _emailProblem,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              final looksRight = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
              return looksRight ? null : 'Please enter a valid email address';
            },
          ),
          const SizedBox(height: AbraSpacing.lg),
          TextFormField(
            initialValue: widget.profile.phone,
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: AbraRadius.medium),
              helperText: 'To change your mobile number, contact support.',
            ),
          ),
          if (_problem != null) ...<Widget>[
            const SizedBox(height: AbraSpacing.lg),
            Text(_problem!, style: const TextStyle(color: AbraColors.danger)),
          ],
          const SizedBox(height: AbraSpacing.xxl),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AbraColors.blue,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}
