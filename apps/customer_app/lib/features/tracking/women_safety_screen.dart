import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/ui/adaptive_sheet.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../booking/controllers/url_launcher_provider.dart';
import 'controllers/safety_controllers.dart';
import 'models/tracking_models.dart';
import 'repositories/tracking_repositories.dart';
import 'widgets/sos_hold_button.dart';

/// The numbers to call in an emergency: label key and the number to dial.
const List<(String labelKey, String number, String display)> helplines =
    <(String, String, String)>[
      (CustomerStrings.helplineWomen, '1091', '1091'),
      (CustomerStrings.helplinePolice, '112', '112'),
      (CustomerStrings.helplineAmbulance, '108', '108'),
      (CustomerStrings.helplineAbra, '18001234567', '1800 123 4567'),
    ];

Future<void> _dial(WidgetRef ref, String number) => ref.read(
  urlLauncherProvider,
)(Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[^\d+]'), '')));

/// Women safety: hold SOS for three seconds to alert contacts, share the live
/// location and tell the safety team; or call a helpline at once. After the
/// alert the screen says help is on the way and offers "Call 112" and
/// "I'm safe".
class WomenSafetyScreen extends ConsumerStatefulWidget {
  const WomenSafetyScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<WomenSafetyScreen> createState() => _WomenSafetyScreenState();
}

class _WomenSafetyScreenState extends ConsumerState<WomenSafetyScreen> {
  SosAlert? _alert;
  bool _sending = false;
  bool _failed = false;

  void _releasedEarly() {
    final l10n = AbraLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l10n.text(CustomerStrings.sosReleasedEarly)),
        ),
      );
  }

  Future<void> _send() async {
    if (_sending) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      final alert = await ref
          .read(safetyRepositoryProvider)
          .triggerSos(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _alert = alert;
        _sending = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failed = true;
      });
    }
  }

  Future<void> _imSafe() async {
    final l10n = AbraLocalizations.of(context);
    final alert = _alert;
    if (alert == null) return;
    final confirmed = await showAdaptiveSheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        title: l10n.text(CustomerStrings.sosSafeConfirmTitle),
        onClose: () => Navigator.of(context).pop(false),
        body: Text(
          l10n.text(CustomerStrings.sosSafeConfirmBody),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AbraButton(
              label: l10n.text(CustomerStrings.sosSafeConfirmNo),
              variant: AbraButtonVariant.primary,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AbraSpacing.sm),
            AbraButton(
              label: l10n.text(CustomerStrings.sosSafeConfirmYes),
              variant: AbraButtonVariant.secondary,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(safetyRepositoryProvider).cancelSos(alert.id);
    if (mounted) setState(() => _alert = null);
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert;
    return alert == null
        ? _Idle(
            bookingId: widget.bookingId,
            sending: _sending,
            failed: _failed,
            onTriggered: _send,
            onReleasedEarly: _releasedEarly,
          )
        : _AlertSent(alert: alert, onSafe: _imSafe);
  }
}

class _Idle extends ConsumerWidget {
  const _Idle({
    required this.bookingId,
    required this.sending,
    required this.failed,
    required this.onTriggered,
    required this.onReleasedEarly,
  });

  final String bookingId;
  final bool sending;
  final bool failed;
  final VoidCallback onTriggered;
  final VoidCallback onReleasedEarly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final contacts = ref.watch(emergencyContactsProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.sosTitle),
        subtitle: l10n.text(CustomerStrings.sosSubtitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: AbraResponsive.pagePadding(context),
            children: <Widget>[
              if (failed) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: SafetyColors.ringTrack,
                      borderRadius: AbraRadius.medium,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            l10n.text(CustomerStrings.sosFailed),
                            style: textTheme.bodyMedium?.copyWith(
                              color: SafetyColors.ring,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AbraSpacing.sm),
                          _RedButton(
                            label: l10n.text(CustomerStrings.sosCall112),
                            icon: Icons.call_rounded,
                            onPressed: () => _dial(ref, '112'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AbraSpacing.md),
              ],
              AbraCard(
                child: Column(
                  children: <Widget>[
                    Text(
                      l10n.text(CustomerStrings.sosIntro),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    sending
                        ? const SizedBox.square(
                            dimension: 176,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: SafetyColors.ring,
                              ),
                            ),
                          )
                        : SosHoldButton(
                            onTriggered: onTriggered,
                            onReleasedEarly: onReleasedEarly,
                            label: l10n.text(CustomerStrings.sosButton),
                            semanticsLabel: l10n.text(
                              CustomerStrings.sosButtonSemantics,
                            ),
                            secondsLabel: (seconds) => l10n.text(
                              CustomerStrings.sosSeconds,
                              <String, Object?>{
                                'seconds': seconds.toStringAsFixed(1),
                              },
                            ),
                          ),
                    const SizedBox(height: AbraSpacing.lg),
                    Text(
                      l10n.text(CustomerStrings.sosNote),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              AbraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.text(CustomerStrings.sosContacts),
                        style: textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    AsyncValueView<List<EmergencyContact>>(
                      value: contacts,
                      onRetry: () => ref.invalidate(emergencyContactsProvider),
                      data: (context, list) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AbraSpacing.sm,
                              ),
                              child: Text(
                                l10n.text(CustomerStrings.sosContactsEmpty),
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          for (final contact in list)
                            _CallRow(
                              title: contact.name,
                              subtitle: contact.relation,
                              tooltip: l10n.text(
                                CustomerStrings.sosCall,
                                <String, Object?>{'name': contact.name},
                              ),
                              onCall: () => _dial(ref, contact.phone),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => _addContact(context, ref),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(
                                l10n.text(CustomerStrings.sosAddContact),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              TonalButton(
                label: l10n.text(CustomerStrings.sosShareLocation),
                icon: Icons.share_location_rounded,
                expand: true,
                onPressed: () => context.push(AppRoutes.myTripShare(bookingId)),
              ),
              const SizedBox(height: AbraSpacing.md),
              AbraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.text(CustomerStrings.sosHelplines),
                        style: textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    for (final (labelKey, number, display) in helplines)
                      _CallRow(
                        title: l10n.text(labelKey),
                        subtitle: display,
                        tooltip: l10n.text(
                          CustomerStrings.sosCall,
                          <String, Object?>{'name': l10n.text(labelKey)},
                        ),
                        onCall: () => _dial(ref, number),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    await showAdaptiveSheet<bool>(
      context,
      builder: (context) => _AddContactSheet(
        onSave: (name, phone, relation) async {
          await ref
              .read(emergencyContactsProvider.notifier)
              .add(name: name, phone: phone, relation: relation);
        },
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.onCall,
  });

  final String title;
  final String subtitle;
  final String tooltip;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: textTheme.titleSmall),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: AbraColors.lightBlue,
              foregroundColor: AbraColors.blue,
              minimumSize: const Size.square(AbraSizes.minTouchTarget),
            ),
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded),
          ),
        ],
      ),
    );
  }
}

/// A filled red button (the emergency actions).
class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: SafetyColors.ring,
      foregroundColor: AbraColors.white,
      minimumSize: const Size.fromHeight(AbraSizes.buttonHeight),
      shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

/// "Help is on the way": what was done, and the two things to do now.
class _AlertSent extends ConsumerWidget {
  const _AlertSent({required this.alert, required this.onSafe});

  final SosAlert alert;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final time = l10n.formatters.time(alert.sentAt);
    final items = <String>[
      l10n.text(CustomerStrings.sosAlertContacts, <String, Object?>{
        'count': alert.contactsNotified,
      }),
      l10n.text(CustomerStrings.sosAlertLocation),
      l10n.text(CustomerStrings.sosAlertPolice),
      l10n.text(CustomerStrings.sosAlertTeam),
    ];
    return PopScope(
      // The alert is running: Back must not hide it by accident.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: SafetyColors.ring,
          foregroundColor: AbraColors.white,
          title: Semantics(
            header: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.text(CustomerStrings.sosAlertTitle),
                  style: textTheme.titleLarge?.copyWith(
                    color: AbraColors.white,
                  ),
                ),
                Text(
                  l10n.text(CustomerStrings.sosAlertSubtitle, <String, Object?>{
                    'time': time,
                  }),
                  style: textTheme.bodySmall?.copyWith(
                    color: AbraColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AbraResponsive.pagePadding(context),
              children: <Widget>[
                AbraCard(
                  child: Column(
                    children: <Widget>[
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SafetyColors.sos,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(AbraSpacing.xl),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 40,
                            color: AbraColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.md),
                      Text(
                        l10n.text(CustomerStrings.sosAlertTitle),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AbraSpacing.sm),
                      Text(
                        l10n.text(CustomerStrings.sosAlertMessage),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AbraColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AbraSpacing.md),
                AbraCard(
                  child: Column(
                    children: <Widget>[
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AbraSpacing.sm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: AbraColors.tealDark,
                              ),
                              const SizedBox(width: AbraSpacing.sm),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AbraSpacing.md),
                _RedButton(
                  label: l10n.text(CustomerStrings.sosCall112),
                  icon: Icons.call_rounded,
                  onPressed: () => _dial(ref, '112'),
                ),
                const SizedBox(height: AbraSpacing.sm),
                AbraButton(
                  label: l10n.text(CustomerStrings.sosImSafe),
                  variant: AbraButtonVariant.secondary,
                  expand: true,
                  onPressed: onSafe,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.onSave});

  final Future<void> Function(String name, String phone, String relation)
  onSave;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController();
  bool _showErrors = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  bool get _phoneValid => RegExp(
    r'^[6-9]\d{9}$',
  ).hasMatch(_phone.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || !_phoneValid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _name.text.trim(),
        '+91 ${_phone.text.replaceAll(RegExp(r'\D'), '')}',
        _relation.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return SheetScaffold(
      title: l10n.text(CustomerStrings.contactAddTitle),
      onClose: () => Navigator.of(context).pop(false),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.contactNameLabel),
              errorText: _showErrors && _name.text.trim().isEmpty
                  ? l10n.text(CustomerStrings.contactNameRequired)
                  : null,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.contactPhoneLabel),
              errorText: _showErrors && !_phoneValid
                  ? l10n.text(CustomerStrings.contactPhoneRequired)
                  : null,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          TextField(
            controller: _relation,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.contactRelationLabel),
            ),
          ),
        ],
      ),
      footer: AbraButton(
        label: l10n.text(CustomerStrings.contactSave),
        variant: AbraButtonVariant.callToAction,
        expand: true,
        isLoading: _saving,
        onPressed: _save,
      ),
    );
  }
}
