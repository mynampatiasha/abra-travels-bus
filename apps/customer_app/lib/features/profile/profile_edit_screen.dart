import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/ui/gradient_header.dart';
import '../home/widgets/home_offers_slider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    final user = auth is AuthSignedIn ? auth.user : null;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final phone = (auth is AuthSignedIn) ? auth.user.phone : '';

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Edit profile',
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            children: [
              const HomeNotConnectedCard(
                icon: Icons.cloud_off_outlined,
                text: 'Not connected yet - built in Phase 7',
              ),
              const SizedBox(height: AbraSpacing.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AbraSpacing.lg),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                ),
                validator: (val) {
                  if (val == null || !val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AbraSpacing.lg),
              TextFormField(
                initialValue: phone,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: AbraRadius.medium),
                  helperText: 'To change your mobile number, contact support.',
                ),
              ),
              const SizedBox(height: AbraSpacing.xxl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AbraColors.blue,
                  minimumSize: const Size.fromHeight(48),
                ),
                // Saving needs the server: not connected yet.
                onPressed: null,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
