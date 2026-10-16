import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/ui/gradient_header.dart';
import '../../routing/app_routes.dart';
import '../my_trips/controllers/trips_controller.dart';
import '../my_trips/models/trip_models.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _deleting = false;

  Future<void> _delete() async {
    if (!_confirmed || _deleting) return;
    setState(() => _deleting = true);
    await ref.read(sessionManagerProvider).signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your account has been deleted.'),
        backgroundColor: AbraColors.danger,
      ),
    );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    final upcomingCount = bookingsAsync.value
            ?.where((b) => b.status == BookingStatus.confirmed)
            .length ??
        0;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Delete account',
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          children: <Widget>[
            // Legal notice alert
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
                      style: TextStyle(
                        color: AbraColors.danger,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),

            if (upcomingCount > 0) ...<Widget>[
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
                        'You have $upcomingCount upcoming trip(s). You must cancel them or complete your travel before deleting your account.',
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
              onChanged: upcomingCount > 0
                  ? null
                  : (val) => setState(() => _confirmed = val ?? false),
              title: const Text(
                'I understand that this action cannot be undone.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AbraSpacing.xxl),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AbraColors.danger,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: (_confirmed && upcomingCount == 0 && !_deleting)
                  ? _delete
                  : null,
              child: _deleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }
}
