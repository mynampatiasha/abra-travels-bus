import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/onboarding/client_kyc_based_screen.dart';
import '../l10n/portal_strings.dart';
import '../routing/portal_routes.dart';

/// Frame of the portal: a navy top bar with the Abra Travels mark, the
/// notification bell, the signed-in person and sign-out. Pages fill the rest.
class PortalShell extends ConsumerWidget {
  const PortalShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(AbraStrings.commonSignOut),
      message: l10n.text(PortalStrings.appName),
      confirmLabel: l10n.text(AbraStrings.commonSignOut),
    );
    if (confirmed) {
      // While the session is valid: this device stops receiving this person's push
      await ref.read(notificationCenterProvider).stop();
      await ref.read(sessionManagerProvider).signOut();
    }
  }

  /// Takes the person to what a notification is about: the documents it names.
  static void _openNotification(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
  ) {
    final route = item.route;
    if (route != null && route.startsWith(PortalRoutes.onboardingPrefix)) {
      ref.invalidate(clientKycProvider);
      context.go(item.data['subjectType'] == 'BUS' ? route : '/kyc');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final breakpoint = AbraBreakpoint.of(context);
    final userName = access.user?.name;

    return _NotificationLifecycle(
      onOpen: (item) => _openNotification(context, ref, item),
      child: Scaffold(
        backgroundColor: AbraColors.lightGray,
        appBar: AppBar(
          backgroundColor: AbraColors.navy,
          foregroundColor: AbraColors.white,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 64,
          titleSpacing: AbraSpacing.lg,
          title: InkWell(
            onTap: () => context.go(PortalRoutes.dashboard),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.directions_bus_filled_outlined),
                const SizedBox(width: AbraSpacing.md),
                Flexible(
                  child: Text(
                    breakpoint.isTabletOrWider
                        ? l10n.text(PortalStrings.appName)
                        : 'Abra Travels',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AbraColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Login methods',
              onPressed: () => showClientLoginMethods(context),
            ),
            IconButton(
              icon: const Icon(Icons.inbox_outlined),
              tooltip: 'Notification inbox',
              onPressed: () => context.go('/notifications'),
            ),
            NotificationBell(
              center: ref.watch(notificationCenterProvider),
              color: AbraColors.white,
              onOpen: (item) => _openNotification(context, ref, item),
            ),
            if (userName != null && breakpoint.isTabletOrWider) ...<Widget>[
              const SizedBox(width: AbraSpacing.md),
              Center(
                child: Text(
                  userName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AbraColors.onNavyMuted,
                  ),
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: l10n.text(AbraStrings.commonSignOut),
              onPressed: () => _signOut(context, ref),
            ),
            const SizedBox(width: AbraSpacing.sm),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: <Widget>[
                  PushPermissionBanner(
                    center: ref.watch(notificationCenterProvider),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts the notifications once the person is in (live socket and push) and
/// shows a toast when one arrives while the page is open. Stops them when the
/// session ends.
class _NotificationLifecycle extends ConsumerStatefulWidget {
  const _NotificationLifecycle({required this.child, required this.onOpen});

  final Widget child;
  final void Function(NotificationItem item) onOpen;

  @override
  ConsumerState<_NotificationLifecycle> createState() =>
      _NotificationLifecycleState();
}

class _NotificationLifecycleState
    extends ConsumerState<_NotificationLifecycle> {
  StreamSubscription<NotificationItem>? _toasts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = ref.read(notificationCenterProvider);
      unawaited(center.start(ref.read(sessionManagerProvider).accessToken));
      _toasts = center.arrivals.listen(_toast);
    });
  }

  void _toast(NotificationItem item) {
    ref.invalidate(clientKycProvider);
    unawaited(ref.read(accessProvider.notifier).refreshApproval());
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '${item.title}: ${item.body}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => widget.onOpen(item),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_toasts?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A session that ends by itself (expired, signed out elsewhere) also ends the live channel
    ref.listen(authStateProvider, (previous, next) {
      if (next is AuthSignedOut) {
        unawaited(ref.read(notificationCenterProvider).stop());
      }
    });
    return widget.child;
  }
}
