import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_validation/shared_validation.dart';

import '../../app/providers.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';

/// The Profile section. For now it shows who is signed in and offers the
/// language setting and sign-out; editing the profile, privacy settings and
/// account deletion arrive with their backend endpoints (milestone 10J).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(CustomerStrings.profileSignOutConfirmTitle),
      message: l10n.text(CustomerStrings.profileSignOutConfirmMessage),
      confirmLabel: l10n.text(AbraStrings.commonSignOut),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSigningOut = true);
    // Ends the session on the server when it can be reached and always
    // removes it from this device; the router then leaves the signed-in
    // area.
    await ref.read(sessionManagerProvider).signOut();
    if (mounted) setState(() => _isSigningOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authStateProvider);
    final user = auth is AuthSignedIn ? auth.user : null;
    final name = user?.name;
    final phone = user?.phone;

    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.lg),
        children: <Widget>[
          if (user != null)
            AbraCard(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.text(CustomerStrings.profileSignedInAs),
                      style: textTheme.bodySmall?.copyWith(
                        color: AbraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    if (name != null && name.isNotEmpty)
                      Text(name, style: textTheme.titleMedium),
                    if (phone != null)
                      Text(
                        PhoneNumbers.mask(phone),
                        style: textTheme.bodyLarge,
                        textDirection: TextDirection.ltr,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AbraSpacing.lg),
          ListTile(
            minTileHeight: AbraSizes.minTouchTarget,
            leading: const Icon(Icons.language),
            title: Text(l10n.text(CustomerStrings.languageTitle)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.language),
          ),
          const SizedBox(height: AbraSpacing.xl),
          AbraButton(
            label: l10n.text(AbraStrings.commonSignOut),
            variant: AbraButtonVariant.secondary,
            icon: Icons.logout,
            expand: true,
            isLoading: _isSigningOut,
            onPressed: _signOut,
          ),
        ],
      ),
    );
  }
}
