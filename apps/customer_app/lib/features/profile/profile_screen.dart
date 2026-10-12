import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_validation/shared_validation.dart';

import '../../app/providers.dart';
import '../../core/ui/guest_prompt_card.dart';
import '../../core/ui/section_header.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/require_sign_in.dart';
import '../authentication/gate/sign_in_intent.dart';

/// The Profile tab. Guests get a "Log in / Sign up" card on top and can
/// still change the language and read help, terms, privacy and About.
/// Signed-in customers see who is signed in, their settings and sign-out;
/// editing the profile and notification settings arrive with their backend
/// endpoints (milestone 10J).
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
    // This phone stops receiving push for this person while the session is
    // still valid, then the session ends on the server when it can be reached
    // and is always removed from this device; the tab then shows the guest card.
    await ref.read(appDependenciesProvider).notifications?.stop();
    await ref.read(sessionManagerProvider).signOut();
    if (mounted) setState(() => _isSigningOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final auth = ref.watch(authStateProvider);
    final user = auth is AuthSignedIn ? auth.user : null;

    Widget item(IconData icon, String titleKey, VoidCallback onTap) => ListTile(
      minTileHeight: AbraSizes.minTouchTarget,
      leading: Icon(icon, color: AbraColors.blue),
      title: Text(l10n.text(titleKey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth * 1.4,
      child: ListView(
        key: const PageStorageKey<String>('profile'),
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.lg),
        children: <Widget>[
          if (user != null)
            _SignedInCard(name: user.name, phone: user.phone)
          else if (auth is AuthSignedOut)
            GuestPromptCard(
              compact: true,
              icon: Icons.person_outline,
              title: l10n.text(CustomerStrings.profileGuestTitle),
              message: l10n.text(CustomerStrings.profileGuestMessage),
              actionLabel: l10n.text(CustomerStrings.gateAction),
              onAction: () => requireSignIn(
                context,
                const SignInIntent(returnLocation: AppRoutes.profile),
              ),
            ),
          if (user != null) ...<Widget>[
            SectionHeader(title: l10n.text(CustomerStrings.profileAccount)),
            AbraCard(
              padding: EdgeInsetsDirectional.zero,
              child: Column(
                children: <Widget>[
                  item(
                    Icons.edit_outlined,
                    CustomerStrings.routeProfileEditTitle,
                    () => context.push(AppRoutes.profileEdit),
                  ),
                  item(
                    Icons.notifications_none,
                    CustomerStrings.routeNotificationSettingsTitle,
                    () => context.push(AppRoutes.notificationSettings),
                  ),
                ],
              ),
            ),
          ],
          SectionHeader(title: l10n.text(CustomerStrings.profilePreferences)),
          AbraCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              children: <Widget>[
                item(
                  Icons.language,
                  CustomerStrings.languageTitle,
                  () => context.push(AppRoutes.language),
                ),
                item(
                  Icons.support_agent_outlined,
                  CustomerStrings.supportHelpTitle,
                  () => context.go(AppRoutes.support),
                ),
              ],
            ),
          ),
          SectionHeader(title: l10n.text(CustomerStrings.profileAboutSection)),
          AbraCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              children: <Widget>[
                item(
                  Icons.gavel_outlined,
                  CustomerStrings.infoTermsTitle,
                  () => context.push(AppRoutes.terms),
                ),
                item(
                  Icons.privacy_tip_outlined,
                  CustomerStrings.infoPrivacyTitle,
                  () => context.push(AppRoutes.privacy),
                ),
                item(
                  Icons.info_outline,
                  CustomerStrings.infoAboutTitle,
                  () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ),
          if (user != null) ...<Widget>[
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
        ],
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.name, required this.phone});

  final String? name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final initials = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return AbraCard(
      child: MergeSemantics(
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AbraColors.skyContainer,
                foregroundColor: AbraColors.deepBlue,
                child: initials.isEmpty
                    ? const Icon(Icons.person)
                    : Text(initials, style: textTheme.titleMedium),
              ),
            ),
            const SizedBox(width: AbraSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.text(CustomerStrings.profileSignedInAs),
                    style: textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                  if (name != null && name!.isNotEmpty)
                    Text(name!, style: textTheme.titleMedium),
                  if (phone != null)
                    Text(
                      PhoneNumbers.mask(phone!),
                      style: textTheme.bodyLarge,
                      textDirection: TextDirection.ltr,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
