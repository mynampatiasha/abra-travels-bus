import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/ui/gradient_header.dart';
import '../../routing/app_routes.dart';
import 'profile_repository.dart';

/// Delete account. The server decides: it refuses with a clear sentence
/// while a booking is still to be travelled on, and that sentence is shown
/// here as it is.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _deleting = false;
  String? _problem;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _problem = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      // The server already ended every session; this clears the device
      await ref.read(sessionManagerProvider).signOut();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on ProfileProblem catch (problem) {
      if (mounted) setState(() => _problem = problem.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Delete account'),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: AbraColors.dangerContainer,
                borderRadius: AbraRadius.medium,
                border: Border.all(color: AbraColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: AbraColors.danger),
                  SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: Text(
                      'Deleting your account removes your profile, saved passenger details, and emergency contacts. Booking records are legally retained for 8 years as required by financial regulations.',
                      style: TextStyle(color: AbraColors.danger, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            if (_problem != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: BoxDecoration(
                  color: AbraColors.orangeContainer,
                  borderRadius: AbraRadius.medium,
                  border: Border.all(color: AbraColors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.info_outline, color: AbraColors.orangeDark),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: Text(
                        _problem!,
                        style: const TextStyle(
                          color: AbraColors.orangeDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AbraColors.danger,
              value: _confirmed,
              onChanged: _deleting ? null : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'I understand that this action cannot be undone.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AbraColors.danger,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _confirmed && !_deleting ? _delete : null,
              child: Text(_deleting ? 'Deleting...' : 'Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }
}
