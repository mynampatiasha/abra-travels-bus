import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/failure_text.dart';
import '../../l10n/portal_strings.dart';
import '../../routing/portal_routes.dart';
import '../onboarding/onboarding_repository.dart';
import '../onboarding/status_labels.dart';
import 'add_bus_dialog.dart';

/// The owner's home: where the company stands, and the buses with the state
/// of each bus's documents.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncValueView<DashboardData>(
        value: ref.watch(dashboardProvider),
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (context, data) => _Dashboard(data: data),
      );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.data});

  final DashboardData data;

  Future<void> _openBusFile(
    BuildContext context,
    WidgetRef ref,
    JsonMap bus,
  ) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final existing = data.busFiles['${bus['id']}'];
      final id =
          existing?['id'] ??
          (await ref
              .read(onboardingRepositoryProvider)
              .busFile('${bus['id']}'))['id'];
      router.go(PortalRoutes.onboardingOf('$id'));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final company = data.company;
    final companyStatus = '${company?['status'] ?? 'DRAFT'}';
    final canAddBus = ref.watch(accessProvider).can(PermissionKeys.busesCreate);
    final approvedBuses = data.buses
        .where((bus) => bus['status'] == 'ACTIVE')
        .length;
    final waitingBuses = data.buses
        .where((bus) => bus['status'] == 'PENDING_APPROVAL')
        .length;

    return ListView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          decoration: const BoxDecoration(
            gradient: AbraGradients.brand,
            borderRadius: AbraRadius.extraLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (ref.watch(accessProvider).user?.name case final name?)
                Text(
                  'Hello, ${name.split(' ').first}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AbraColors.white,
                  ),
                ),
              Text(
                company == null
                    ? l10n.text(PortalStrings.navDashboard)
                    : '${company['companyName']}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AbraColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                'Add your buses, follow their approval and start selling seats.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AbraColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.lg),
        Wrap(
          spacing: AbraSpacing.md,
          runSpacing: AbraSpacing.md,
          children: <Widget>[
            _Tile(
              icon: Icons.business_outlined,
              color: statusColor(companyStatus),
              value: l10n.text(fileStatusKey(companyStatus)),
              label: l10n.text(PortalStrings.dashCompanyTitle),
            ),
            _Tile(
              icon: Icons.directions_bus_outlined,
              color: AbraColors.tealDark,
              value: '$approvedBuses',
              label: l10n.text(PortalStrings.dashBusesApproved),
            ),
            _Tile(
              icon: Icons.hourglass_top,
              color: AbraColors.orangeDark,
              value: '$waitingBuses',
              label: l10n.text(PortalStrings.dashBusesWaiting),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),
        AbraCard(
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AbraSpacing.md,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            l10n.text(PortalStrings.dashCompanyTitle),
                            style: theme.textTheme.titleMedium,
                          ),
                          fileStatusBadge(l10n, companyStatus),
                        ],
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      Text(l10n.text(companyMessageKey(companyStatus))),
                      if (company?['decisionNote'] != null &&
                          companyStatus == 'REJECTED')
                        Padding(
                          padding: const EdgeInsets.only(top: AbraSpacing.xs),
                          child: Text(
                            '${l10n.text(PortalStrings.obNote)}: ${company!['decisionNote']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AbraColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (company != null) ...<Widget>[
                  const SizedBox(width: AbraSpacing.md),
                  AbraButton(
                    label: l10n.text(
                      companyStatus == 'APPROVED'
                          ? PortalStrings.dashOpen
                          : PortalStrings.dashContinue,
                    ),
                    variant: companyStatus == 'APPROVED'
                        ? AbraButtonVariant.secondary
                        : AbraButtonVariant.primary,
                    onPressed: () => context.go(
                      PortalRoutes.onboardingOf('${company['id']}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.text(PortalStrings.dashBusesTitle),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (canAddBus)
              AbraButton(
                label: l10n.text(PortalStrings.dashAddBus),
                icon: Icons.add,
                onPressed: () async {
                  final busId = await showAddBusDialog(context);
                  ref.invalidate(dashboardProvider);
                  if (busId != null && context.mounted) {
                    final file = await ref
                        .read(onboardingRepositoryProvider)
                        .busFile(busId);
                    if (context.mounted) {
                      context.go(PortalRoutes.onboardingOf('${file['id']}'));
                    }
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AbraSpacing.sm),
        if (companyStatus != 'APPROVED')
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
            child: Text(
              l10n.text(PortalStrings.dashBusNeedsCompany),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (data.buses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AbraSpacing.xl),
            child: Center(child: Text(l10n.text(PortalStrings.dashNoBuses))),
          ),
        for (final bus in data.buses)
          _BusCard(
            bus: bus,
            file: data.busFiles['${bus['id']}'],
            onOpen: () => _openBusFile(context, ref, bus),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: AbraCard(
      semanticLabel: '$label: $value',
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AbraRadius.medium,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AbraColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus, required this.file, required this.onOpen});

  final JsonMap bus;
  final JsonMap? file;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final status = '${bus['status']}';
    final fileStatus = '${file?['status'] ?? 'DRAFT'}';
    final isLive = status == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.md),
      child: AbraCard(
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.directions_bus_outlined,
                size: 32,
                color: AbraColors.navySecondary,
              ),
              const SizedBox(width: AbraSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${bus['name']}', style: theme.textTheme.titleSmall),
                    Text(
                      '${bus['registrationNumber']} · ${bus['seatCapacity'] ?? '-'} ${l10n.text(PortalStrings.busSeats)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AbraSpacing.sm),
                    Wrap(
                      spacing: AbraSpacing.sm,
                      runSpacing: AbraSpacing.xs,
                      children: <Widget>[
                        AbraStatusBadge(
                          label: l10n.text(busStatusKey(status)),
                          tone: busTone(status),
                        ),
                        if (!isLive) fileStatusBadge(l10n, fileStatus),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLive)
                AbraButton(
                  label: l10n.text(
                    fileStatus == 'PENDING'
                        ? PortalStrings.dashOpen
                        : PortalStrings.dashContinue,
                  ),
                  variant: fileStatus == 'PENDING'
                      ? AbraButtonVariant.secondary
                      : AbraButtonVariant.primary,
                  onPressed: onOpen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
