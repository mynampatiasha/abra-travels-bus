import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/failure_text.dart';
import '../../l10n/admin_strings.dart';
import 'settings_repository.dart';

/// Settings and integrations: matches prototypes/admin_demo_model.html (reg('settings')).
/// 5 tabs: Integrations (default), Company, Booking rules, Security, Message templates.
/// Anyone with `settings.read` can view; `settings.update` can change and test.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _Section {
  const _Section({
    required this.channel,
    required this.labelKey,
    required this.hintKey,
    required this.icon,
    required this.color,
    required this.keywords,
  });

  final SettingsChannel channel;
  final String labelKey;
  final String hintKey;
  final IconData icon;
  final Color color;
  final List<String> keywords;
}

const _sections = <_Section>[
  _Section(
    channel: SettingsChannel.whatsapp,
    labelKey: AdminStrings.settingsSectionWhatsApp,
    hintKey: AdminStrings.settingsSectionWhatsAppHint,
    icon: Icons.chat_outlined,
    color: AbraColors.tealDark,
    keywords: <String>[
      'whatsapp',
      'meta',
      'token',
      'otp',
      'template',
      'notification',
      'message',
    ],
  ),
  _Section(
    channel: SettingsChannel.email,
    labelKey: AdminStrings.settingsSectionEmail,
    hintKey: AdminStrings.settingsSectionEmailHint,
    icon: Icons.mail_outline,
    color: AbraColors.blue,
    keywords: <String>['email', 'smtp', 'mail', 'sender', 'password', 'host'],
  ),
  _Section(
    channel: SettingsChannel.sms,
    labelKey: AdminStrings.settingsSectionSms,
    hintKey: AdminStrings.settingsSectionSmsHint,
    icon: Icons.sms_outlined,
    color: AbraColors.orange,
    keywords: <String>['sms', 'msg91', 'twilio', 'gupshup', 'fallback', 'otp', 'codes'],
  ),
  _Section(
    channel: SettingsChannel.razorpay,
    labelKey: AdminStrings.settingsSectionRazorpay,
    hintKey: AdminStrings.settingsSectionRazorpayHint,
    icon: Icons.payment_outlined,
    color: AbraColors.navy,
    keywords: <String>['razorpay', 'payment', 'payout', 'gateway', 'key', 'webhook'],
  ),
  _Section(
    channel: SettingsChannel.maps,
    labelKey: AdminStrings.settingsSectionMaps,
    hintKey: AdminStrings.settingsSectionMapsHint,
    icon: Icons.map_outlined,
    color: AbraColors.teal,
    keywords: <String>['maps', 'google', 'mappls', 'tracking', 'location', 'api'],
  ),
  _Section(
    channel: SettingsChannel.push,
    labelKey: AdminStrings.settingsSectionPush,
    hintKey: AdminStrings.settingsSectionPushHint,
    icon: Icons.notifications_active_outlined,
    color: AbraColors.orangeDark,
    keywords: <String>['push', 'firebase', 'notifications', 'fcm', 'service account'],
  ),
];

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _tab = 'int';
  var _query = '';
  final Map<SettingsChannel, DateTime> _testedAt = {};

  Future<void> _open(_Section section) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SettingsDialog(section: section),
    );
    ref.invalidate(settingsProvider(section.channel));
  }

  Future<void> _testChannel(SettingsChannel channel) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.text(AdminStrings.settingsTestRunning))),
    );
    try {
      final res = await ref.read(settingsRepositoryProvider).test(channel);
      setState(() => _testedAt[channel] = DateTime.now());
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ??
                (res['ok'] == true
                    ? l10n.text(AdminStrings.settingsConnectionWorks)
                    : 'Failed'),
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final canEdit = ref.watch(accessProvider).can(PermissionKeys.settingsUpdate);
    final needle = _query.trim().toLowerCase();
    final shown = <_Section>[
      for (final section in _sections)
        if (needle.isEmpty ||
            l10n.text(section.labelKey).toLowerCase().contains(needle) ||
            l10n.text(section.hintKey).toLowerCase().contains(needle) ||
            section.keywords.any((word) => word.contains(needle)))
          section,
    ];

    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;

    return ListView(
      padding: EdgeInsets.all(isCompact ? AbraSpacing.md : AbraSpacing.xl),
      children: <Widget>[
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.text(AdminStrings.settingsPageTitle),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.xs),
                  Text(
                    l10n.text(AdminStrings.settingsPageSubtitle),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),

        // Read-only banner if user lacks update permission

        // Horizontal tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _tabButton('int', l10n.text(AdminStrings.settingsTabIntegrations)),
              _tabButton('gen', l10n.text(AdminStrings.settingsTabCompany)),
              _tabButton('bk', l10n.text(AdminStrings.settingsTabBookingRules)),
              _tabButton('sec', l10n.text(AdminStrings.settingsTabSecurity)),
              _tabButton('tpl', l10n.text(AdminStrings.settingsTabTemplates)),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: AbraSpacing.xl),

        // Tab content
        if (_tab == 'int') ...<Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.settingsSearch),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          if (shown.isEmpty)
            Text(l10n.text(AdminStrings.settingsNoMatch))
          else
            Wrap(
              spacing: AbraSpacing.lg,
              runSpacing: AbraSpacing.lg,
              children: <Widget>[
                for (final section in shown)
                  _SettingsCard(
                    section: section,
                    onTap: () => _open(section),
                    onTest: () => _testChannel(section.channel),
                    lastTested: _testedAt[section.channel],
                  ),
              ],
            ),
        ] else if (_tab == 'gen')
          _CompanyTab(canEdit: canEdit)
        else if (_tab == 'bk')
          _BookingRulesTab(canEdit: canEdit)
        else if (_tab == 'sec')
          _SecurityTab(canEdit: canEdit)
        else if (_tab == 'tpl')
          const _TemplatesTab(),
      ],
    );
  }

  Widget _tabButton(String key, String label) {
    final selected = _tab == key;
    return InkWell(
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AbraColors.navy : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AbraColors.navy : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({
    required this.section,
    required this.onTap,
    required this.onTest,
    this.lastTested,
  });

  final _Section section;
  final VoidCallback onTap;
  final VoidCallback onTest;
  final DateTime? lastTested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final canEdit = ref.watch(accessProvider).can(PermissionKeys.settingsUpdate);
    final status = ref
        .watch(settingsProvider(section.channel))
        .value?['status'];
    final badge = switch ('$status') {
      'READY' || 'Connected' => (
        AdminStrings.settingsStatusReady,
        AbraStatusTone.success,
      ),
      'Test mode' => (
        AdminStrings.settingsCardTestMode,
        AbraStatusTone.warning,
      ),
      'DISABLED' => (
        AdminStrings.settingsStatusDisabled,
        AbraStatusTone.neutral,
      ),
      _ => (
        AdminStrings.settingsStatusIncomplete,
        AbraStatusTone.warning,
      ),
    };
    final testedText = lastTested != null
        ? l10n.text(AdminStrings.settingsCardLastTested, <String, Object?>{
            'time': '${lastTested!.hour.toString().padLeft(2, '0')}:${lastTested!.minute.toString().padLeft(2, '0')}',
          })
        : l10n.text(AdminStrings.settingsCardNeverTested);

    return SizedBox(
      width: 290,
      child: InkWell(
        borderRadius: AbraRadius.medium,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          decoration: BoxDecoration(
            color: AbraColors.white,
            borderRadius: AbraRadius.medium,
            border: Border.all(color: AbraColors.divider),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.text(section.labelKey),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AbraStatusBadge(label: l10n.text(badge.$1), tone: badge.$2),
                ],
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                l10n.text(section.hintKey),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              Text(
                testedText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.xs,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(l10n.text(AdminStrings.settingsCardSetUp)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: canEdit ? onTest : null,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text(l10n.text(AdminStrings.settingsTestConnection)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AbraSpacing.xl,
                AbraSpacing.lg,
                AbraSpacing.sm,
                AbraSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(section.icon, color: section.color),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.text(section.labelKey),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.text(AdminStrings.settingsClose),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _ChannelTab(channel: section.channel)),
          ],
        ),
      ),
    );
  }
}

class _ChannelTab extends ConsumerWidget {
  const _ChannelTab({required this.channel});

  final SettingsChannel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(settingsProvider(channel)),
    onRetry: () => ref.invalidate(settingsProvider(channel)),
    data: (context, view) => SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: switch (channel) {
            SettingsChannel.whatsapp => _WhatsAppForm(initial: view),
            SettingsChannel.email => _EmailForm(initial: view),
            SettingsChannel.sms => _SmsForm(initial: view),
            SettingsChannel.razorpay => _RazorpayForm(initial: view),
            SettingsChannel.maps => _MapsForm(initial: view),
            SettingsChannel.push => _PushForm(initial: view),
          },
        ),
      ),
    ),
  );
}

class _Outcome {
  const _Outcome({required this.ok, required this.message});

  final bool ok;
  final String message;
}

mixin _FormSupport<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  SettingsChannel get channel;

  JsonMap view = const <String, Object?>{};
  bool busy = false;
  _Outcome? outcome;
  final reason = TextEditingController();
  final secret = TextEditingController();

  bool get canEdit =>
      ref.read(accessProvider).can(PermissionKeys.settingsUpdate);

  AbraLocalizations get l10n => AbraLocalizations.of(context);

  String? text(String key) {
    final value = view[key];
    return value is String ? value : null;
  }

  void initSupport(JsonMap initial) {
    view = initial;
    reason.text = '';
  }

  void disposeSupport() {
    reason.dispose();
    secret.dispose();
  }

  Future<void> run(Future<_Outcome> Function() action) async {
    setState(() {
      busy = true;
      outcome = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => outcome = result);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () =>
              outcome = _Outcome(ok: false, message: failureText(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<_Outcome> save(JsonMap body) async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .save(channel, <String, Object?>{
          ...body,
          'reason': reason.text.trim().length >= 3
              ? reason.text.trim()
              : l10n.text(AdminStrings.settingsDefaultReason),
        });
    if (mounted) {
      setState(() {
        view = saved;
        secret.clear();
      });
    }
    return _Outcome(ok: true, message: l10n.text(AdminStrings.formSaved));
  }

  Future<_Outcome> test({
    String action = '/test-connection',
    JsonMap body = const <String, Object?>{},
  }) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .test(channel, action: action, body: body);
    return _Outcome(
      ok: result['ok'] == true,
      message: '${result['message'] ?? ''}',
    );
  }

  String? orNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}

const _missingLabels = <String, String>{
  'accessToken': AdminStrings.fieldAccessToken,
  'phoneNumberId': AdminStrings.fieldPhoneNumberId,
  'otpTemplateName': AdminStrings.fieldOtpTemplateName,
  'otpTemplateLanguage': AdminStrings.fieldOtpTemplateLanguage,
  'host': AdminStrings.fieldHost,
  'port': AdminStrings.fieldPort,
  'fromAddress': AdminStrings.fieldFromAddress,
  'password': AdminStrings.fieldPassword,
};

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.view, required this.help});

  final JsonMap view;
  final String help;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final status = '${view['status']}';
    final (label, tone) = switch (status) {
      'READY' => (AdminStrings.settingsStatusReady, AbraStatusTone.success),
      'DISABLED' => (
        AdminStrings.settingsStatusDisabled,
        AbraStatusTone.neutral,
      ),
      _ => (AdminStrings.settingsStatusIncomplete, AbraStatusTone.warning),
    };
    final missing = (view['missing'] as List<Object?>? ?? const <Object?>[]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            AbraStatusBadge(label: l10n.text(label), tone: tone),
            if (missing.isNotEmpty && status != 'DISABLED') ...<Widget>[
              const SizedBox(width: AbraSpacing.md),
              Flexible(
                child: Text(
                  l10n.text(
                    AdminStrings.settingsStillMissing,
                    <String, Object?>{
                      'items': <String>[
                        for (final name in missing)
                          _missingLabels[name] == null
                              ? '$name'
                              : l10n.text(_missingLabels[name]!),
                      ].join(', '),
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AbraSpacing.md),
        Text(help, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AbraSpacing.lg),
      ],
    );
  }
}

class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({required this.outcome});

  final _Outcome? outcome;

  @override
  Widget build(BuildContext context) {
    final current = outcome;
    if (current == null || current.message.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = current.ok ? AbraColors.tealDark : AbraColors.danger;
    return Padding(
      padding: const EdgeInsets.only(top: AbraSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AbraSpacing.md),
        decoration: BoxDecoration(
          color: current.ok
              ? AbraColors.tealContainer
              : AbraColors.dangerContainer,
          borderRadius: AbraRadius.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              current.ok ? Icons.check_circle_outline : Icons.error_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: AbraSpacing.sm),
            Expanded(
              child: SelectableText(
                current.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _gap() => const SizedBox(height: AbraSpacing.md);

// ---------------------------------------------------------------- WhatsApp

class _WhatsAppForm extends ConsumerStatefulWidget {
  const _WhatsAppForm({required this.initial});

  final JsonMap initial;

  @override
  ConsumerState<_WhatsAppForm> createState() => _WhatsAppFormState();
}

class _WhatsAppFormState extends ConsumerState<_WhatsAppForm>
    with _FormSupport<_WhatsAppForm> {
  @override
  SettingsChannel get channel => SettingsChannel.whatsapp;

  final _businessAccountId = TextEditingController();
  final _phoneDisplay = TextEditingController();
  final _webhookVerifyToken = TextEditingController();
  final _phoneNumberId = TextEditingController();
  final _templateName = TextEditingController();
  final _templateLanguage = TextEditingController();
  final _notificationTemplate = TextEditingController();
  final _notificationLanguage = TextEditingController();
  bool _enabled = true;
  bool _fallbackToSms = true;

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _fill();
  }

  void _fill() {
    _enabled = view['enabled'] != false;
    _fallbackToSms = view['otpFallbackToSms'] != false;
    _businessAccountId.text = text('businessAccountId') ?? '';
    _phoneDisplay.text = text('phoneDisplay') ?? '';
    _webhookVerifyToken.clear();
    _phoneNumberId.text = text('phoneNumberId') ?? '';
    _templateName.text = text('otpTemplateName') ?? '';
    _templateLanguage.text = text('otpTemplateLanguage') ?? '';
    _notificationTemplate.text = text('notificationTemplateName') ?? '';
    _notificationLanguage.text = text('notificationTemplateLanguage') ?? '';
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _businessAccountId,
      _phoneDisplay,
      _webhookVerifyToken,
      _phoneNumberId,
      _templateName,
      _templateLanguage,
      _notificationTemplate,
      _notificationLanguage,
    ]) {
      controller.dispose();
    }
    disposeSupport();
    super.dispose();
  }

  String _tokenHint() {
    final token = view['accessToken'];
    if (token is! Map || token['configured'] != true) {
      return l10n.text(AdminStrings.secretNotSet);
    }
    if (token['source'] == 'ADMIN' && token['lastFour'] is String) {
      return l10n.text(AdminStrings.secretSavedEnding, <String, Object?>{
        'lastFour': token['lastFour'],
      });
    }
    return l10n.text(AdminStrings.secretFromServer);
  }

  @override
  Future<_Outcome> save(JsonMap body) async {
    final result = await super.save(body);
    if (mounted) setState(_webhookVerifyToken.clear);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsHelpWhatsApp),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable
              ? (value) => setState(() => _enabled = value)
              : null,
        ),
        _gap(),
        Text(
          l10n.text(AdminStrings.settingsWhatsAppConnection),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _gap(),
        TextField(
          controller: _phoneDisplay,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldPhoneDisplay),
            hintText: '+91 90000 00000',
            helperText: l10n.text(AdminStrings.settingsPhoneDisplayHelp),
            helperMaxLines: 2,
          ),
        ),
        _gap(),
        TextField(
          controller: _businessAccountId,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldBusinessAccountId),
          ),
        ),
        _gap(),
        TextField(
          controller: _phoneNumberId,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldPhoneNumberId),
          ),
        ),
        _gap(),
        TextField(
          controller: _webhookVerifyToken,
          enabled: editable,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldWebhookVerifyToken),
            helperText:
                '${l10n.text(view['webhookVerifyToken'] is Map && (view['webhookVerifyToken'] as Map)['configured'] == true ? AdminStrings.secretSaved : AdminStrings.secretNotSet)} ${l10n.text(AdminStrings.settingsWebhookHelp)}',
            helperMaxLines: 4,
          ),
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldAccessToken),
            helperText: _tokenHint(),
          ),
        ),
        _gap(),
        const Divider(height: AbraSpacing.xl),
        Text(
          l10n.text(AdminStrings.settingsWhatsAppOtp),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _gap(),
        Text(l10n.text(AdminStrings.settingsOtpHelp)),
        _gap(),
        TextField(
          controller: _templateName,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldOtpTemplateName),
            hintText: 'abra_travels_login_otp',
          ),
        ),
        _gap(),
        TextField(
          controller: _templateLanguage,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldOtpTemplateLanguage),
            hintText: 'en',
          ),
        ),
        _gap(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldOtpFallbackSms)),
          value: _fallbackToSms,
          onChanged: editable
              ? (value) => setState(() => _fallbackToSms = value)
              : null,
        ),
        const Divider(height: AbraSpacing.xl),
        Text(
          l10n.text(AdminStrings.settingsWhatsAppNotifications),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _gap(),
        TextField(
          controller: _notificationTemplate,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldNotificationTemplate),
            helperText: l10n.text(AdminStrings.settingsNotificationHelp),
            helperMaxLines: 2,
          ),
        ),
        _gap(),
        TextField(
          controller: _notificationLanguage,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldNotificationLanguage),
            hintText: 'en',
          ),
        ),
        if (editable) ...<Widget>[
          _gap(),
          TextField(
            controller: reason,
            decoration: InputDecoration(
              labelText: l10n.text(AdminStrings.fieldReason),
              hintText: l10n.text(AdminStrings.settingsDefaultReason),
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.md,
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.save_outlined,
                isLoading: busy,
                onPressed: () => run(
                  () => save(<String, Object?>{
                    'enabled': _enabled,
                    'businessAccountId': orNull(_businessAccountId),
                    'phoneDisplay': orNull(_phoneDisplay),
                    if (_webhookVerifyToken.text.trim().isNotEmpty)
                      'webhookVerifyToken': _webhookVerifyToken.text.trim(),
                    'phoneNumberId': orNull(_phoneNumberId),
                    if (secret.text.trim().isNotEmpty)
                      'accessToken': secret.text.trim(),
                    'otpTemplateName': orNull(_templateName),
                    'otpTemplateLanguage': orNull(_templateLanguage),
                    'notificationTemplateName': orNull(_notificationTemplate),
                    'notificationTemplateLanguage': orNull(
                      _notificationLanguage,
                    ),
                    'otpFallbackToSms': _fallbackToSms,
                  }),
                ),
              ),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(AdminStrings.settingsSaveFirst),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}

// ------------------------------------------------------------------- Email

/// Asks which address the test email goes to. Owns its text controller, so
/// the controller lives exactly as long as the dialog (including while it
/// animates out).
class _TestEmailDialog extends StatefulWidget {
  const _TestEmailDialog();

  @override
  State<_TestEmailDialog> createState() => _TestEmailDialogState();
}

class _TestEmailDialogState extends State<_TestEmailDialog> {
  final _to = TextEditingController();

  @override
  void dispose() {
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.text(AdminStrings.settingsSendTestEmail)),
      content: TextField(
        controller: _to,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: l10n.text(AdminStrings.settingsTestEmailTo),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_to.text.trim()),
          child: Text(l10n.text(AdminStrings.settingsSendTestEmail)),
        ),
      ],
    );
  }
}

class _EmailForm extends ConsumerStatefulWidget {
  const _EmailForm({required this.initial});

  final JsonMap initial;

  @override
  ConsumerState<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends ConsumerState<_EmailForm>
    with _FormSupport<_EmailForm> {
  @override
  SettingsChannel get channel => SettingsChannel.email;

  static const _securityLabels = <String, String>{
    'SSL': AdminStrings.securitySsl,
    'STARTTLS': AdminStrings.securityStarttls,
    'NONE': AdminStrings.securityNone,
  };

  final _host = TextEditingController();
  final _port = TextEditingController();
  final _username = TextEditingController();
  final _fromName = TextEditingController();
  final _fromAddress = TextEditingController();
  final _replyTo = TextEditingController();
  bool _enabled = true;
  String _security = 'STARTTLS';

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _enabled = view['enabled'] != false;
    final security = text('security');
    _security = _securityLabels.containsKey(security) ? security! : 'STARTTLS';
    _host.text = text('host') ?? '';
    _port.text = view['port'] == null ? '' : '${view['port']}';
    _username.text = text('username') ?? '';
    _fromName.text = text('fromName') ?? '';
    _fromAddress.text = text('fromAddress') ?? '';
    _replyTo.text = text('replyTo') ?? '';
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _host,
      _port,
      _username,
      _fromName,
      _fromAddress,
      _replyTo,
    ]) {
      controller.dispose();
    }
    disposeSupport();
    super.dispose();
  }

  String _passwordHint() {
    final password = view['password'];
    return password is Map && password['configured'] == true
        ? l10n.text(AdminStrings.secretSaved)
        : l10n.text(AdminStrings.secretNotSet);
  }

  Future<void> _sendTestEmail() async {
    final address = await showDialog<String>(
      context: context,
      builder: (context) => const _TestEmailDialog(),
    );
    if (address == null || address.isEmpty || !mounted) return;
    await run(
      () => test(action: '/test-email', body: <String, Object?>{'to': address}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsHelpEmail),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable
              ? (value) => setState(() => _enabled = value)
              : null,
        ),
        _gap(),
        TextField(
          controller: _host,
          enabled: editable,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldHost),
            hintText: 'smtp.example.com',
          ),
        ),
        _gap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _port,
                enabled: editable,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.fieldPort),
                  hintText: '587',
                ),
              ),
            ),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _security,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.fieldSecurity),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final entry in _securityLabels.entries)
                    DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        l10n.text(entry.value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: editable
                    ? (value) => setState(() => _security = value ?? _security)
                    : null,
              ),
            ),
          ],
        ),
        _gap(),
        TextField(
          controller: _username,
          enabled: editable,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldUsername),
          ),
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldPassword),
            helperText: _passwordHint(),
          ),
        ),
        _gap(),
        TextField(
          controller: _fromName,
          enabled: editable,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldFromName),
          ),
        ),
        _gap(),
        TextField(
          controller: _fromAddress,
          enabled: editable,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldFromAddress),
          ),
        ),
        _gap(),
        TextField(
          controller: _replyTo,
          enabled: editable,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.text(AdminStrings.fieldReplyTo),
          ),
        ),
        if (editable) ...<Widget>[
          _gap(),
          TextField(
            controller: reason,
            decoration: InputDecoration(
              labelText: l10n.text(AdminStrings.fieldReason),
              hintText: l10n.text(AdminStrings.settingsDefaultReason),
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.md,
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.save_outlined,
                isLoading: busy,
                onPressed: () => run(
                  () => save(<String, Object?>{
                    'enabled': _enabled,
                    'host': orNull(_host),
                    'port': int.tryParse(_port.text.trim()),
                    'security': _security,
                    'username': orNull(_username),
                    if (secret.text.isNotEmpty) 'password': secret.text,
                    'fromName': orNull(_fromName),
                    'fromAddress': orNull(_fromAddress),
                    'replyTo': orNull(_replyTo),
                  }),
                ),
              ),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
              AbraButton(
                label: l10n.text(AdminStrings.settingsSendTestEmail),
                icon: Icons.outgoing_mail,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: _sendTestEmail,
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(AdminStrings.settingsSaveFirst),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}




// ---------------------------------------------------------------- SMS
class _SmsForm extends ConsumerStatefulWidget {
  const _SmsForm({required this.initial});
  final JsonMap initial;
  @override
  ConsumerState<_SmsForm> createState() => _SmsFormState();
}

class _SmsFormState extends ConsumerState<_SmsForm> with _FormSupport<_SmsForm> {
  @override
  SettingsChannel get channel => SettingsChannel.sms;

  String _provider = 'MSG91';
  final _senderId = TextEditingController();
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _enabled = view['enabled'] != false;
    _provider = text('provider') ?? 'MSG91';
    _senderId.text = text('senderId') ?? '';
  }

  @override
  void dispose() {
    _senderId.dispose();
    disposeSupport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsSectionSmsHint),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable ? (v) => setState(() => _enabled = v) : null,
        ),
        _gap(),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(labelText: 'Provider'),
          items: const [
            DropdownMenuItem(value: 'MSG91', child: Text('MSG91')),
            DropdownMenuItem(value: 'Twilio', child: Text('Twilio')),
            DropdownMenuItem(value: 'Gupshup', child: Text('Gupshup')),
          ],
          onChanged: editable ? (v) => setState(() => _provider = v ?? 'MSG91') : null,
        ),
        _gap(),
        TextField(
          controller: _senderId,
          enabled: editable,
          decoration: const InputDecoration(labelText: 'Sender ID'),
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: view['apiKey'] is Map && (view['apiKey'] as Map)['configured'] == true
                ? l10n.text(AdminStrings.secretSaved)
                : l10n.text(AdminStrings.secretNotSet),
          ),
        ),
        _gap(),
        _secretHelpBox(context, l10n),
        _gap(),
        if (editable)
          Row(
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.check,
                isLoading: busy,
                onPressed: () => run(() => save(<String, Object?>{
                  'enabled': _enabled,
                  'provider': _provider,
                  'senderId': orNull(_senderId),
                  if (secret.text.isNotEmpty) 'apiKey': secret.text,
                })),
              ),
              const SizedBox(width: AbraSpacing.md),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
            ],
          ),
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}

// ---------------------------------------------------------------- Razorpay
class _RazorpayForm extends ConsumerStatefulWidget {
  const _RazorpayForm({required this.initial});
  final JsonMap initial;
  @override
  ConsumerState<_RazorpayForm> createState() => _RazorpayFormState();
}

class _RazorpayFormState extends ConsumerState<_RazorpayForm>
    with _FormSupport<_RazorpayForm> {
  @override
  SettingsChannel get channel => SettingsChannel.razorpay;

  final _keyId = TextEditingController();
  final _webhookSecret = TextEditingController();
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _enabled = view['enabled'] != false;
    _keyId.text = text('keyId') ?? '';
  }

  @override
  void dispose() {
    _keyId.dispose();
    _webhookSecret.dispose();
    disposeSupport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsSectionRazorpayHint),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable ? (v) => setState(() => _enabled = v) : null,
        ),
        _gap(),
        TextField(
          controller: _keyId,
          enabled: editable,
          decoration: const InputDecoration(labelText: 'Key ID'),
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Key secret',
            hintText: view['keySecret'] is Map && (view['keySecret'] as Map)['configured'] == true
                ? l10n.text(AdminStrings.secretSaved)
                : l10n.text(AdminStrings.secretNotSet),
          ),
        ),
        _gap(),
        TextField(
          controller: _webhookSecret,
          enabled: editable,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Webhook secret',
            hintText: view['webhookSecret'] is Map && (view['webhookSecret'] as Map)['configured'] == true
                ? l10n.text(AdminStrings.secretSaved)
                : l10n.text(AdminStrings.secretNotSet),
          ),
        ),
        _gap(),
        _secretHelpBox(context, l10n),
        _gap(),
        if (editable)
          Row(
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.check,
                isLoading: busy,
                onPressed: () => run(() => save(<String, Object?>{
                  'enabled': _enabled,
                  'keyId': orNull(_keyId),
                  if (secret.text.isNotEmpty) 'keySecret': secret.text,
                  if (_webhookSecret.text.isNotEmpty) 'webhookSecret': _webhookSecret.text,
                })),
              ),
              const SizedBox(width: AbraSpacing.md),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
            ],
          ),
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}

// ---------------------------------------------------------------- Maps
class _MapsForm extends ConsumerStatefulWidget {
  const _MapsForm({required this.initial});
  final JsonMap initial;
  @override
  ConsumerState<_MapsForm> createState() => _MapsFormState();
}

class _MapsFormState extends ConsumerState<_MapsForm>
    with _FormSupport<_MapsForm> {
  @override
  SettingsChannel get channel => SettingsChannel.maps;

  String _provider = 'Google Maps';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _enabled = view['enabled'] != false;
    _provider = text('provider') ?? 'Google Maps';
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsSectionMapsHint),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable ? (v) => setState(() => _enabled = v) : null,
        ),
        _gap(),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(labelText: 'Provider'),
          items: const [
            DropdownMenuItem(value: 'Google Maps', child: Text('Google Maps')),
            DropdownMenuItem(value: 'Mappls', child: Text('Mappls')),
          ],
          onChanged: editable ? (v) => setState(() => _provider = v ?? 'Google Maps') : null,
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: view['apiKey'] is Map && (view['apiKey'] as Map)['configured'] == true
                ? l10n.text(AdminStrings.secretSaved)
                : l10n.text(AdminStrings.secretNotSet),
          ),
        ),
        _gap(),
        _secretHelpBox(context, l10n),
        _gap(),
        if (editable)
          Row(
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.check,
                isLoading: busy,
                onPressed: () => run(() => save(<String, Object?>{
                  'enabled': _enabled,
                  'provider': _provider,
                  if (secret.text.isNotEmpty) 'apiKey': secret.text,
                })),
              ),
              const SizedBox(width: AbraSpacing.md),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
            ],
          ),
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}

// ---------------------------------------------------------------- Push
class _PushForm extends ConsumerStatefulWidget {
  const _PushForm({required this.initial});
  final JsonMap initial;
  @override
  ConsumerState<_PushForm> createState() => _PushFormState();
}

class _PushFormState extends ConsumerState<_PushForm>
    with _FormSupport<_PushForm> {
  @override
  SettingsChannel get channel => SettingsChannel.push;

  final _projectId = TextEditingController();
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    initSupport(widget.initial);
    _enabled = view['enabled'] != false;
    _projectId.text = text('projectId') ?? '';
  }

  @override
  void dispose() {
    _projectId.dispose();
    disposeSupport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusHeader(
          view: view,
          help: l10n.text(AdminStrings.settingsSectionPushHint),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Text(l10n.text(AdminStrings.settingsReadOnly)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.text(AdminStrings.fieldEnabled)),
          value: _enabled,
          onChanged: editable ? (v) => setState(() => _enabled = v) : null,
        ),
        _gap(),
        TextField(
          controller: _projectId,
          enabled: editable,
          decoration: const InputDecoration(labelText: 'Project ID'),
        ),
        _gap(),
        TextField(
          controller: secret,
          enabled: editable,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Service account (JSON)',
            hintText: view['serviceAccountJson'] is Map && (view['serviceAccountJson'] as Map)['configured'] == true
                ? l10n.text(AdminStrings.secretSaved)
                : l10n.text(AdminStrings.secretNotSet),
          ),
        ),
        _gap(),
        _secretHelpBox(context, l10n),
        _gap(),
        if (editable)
          Row(
            children: <Widget>[
              AbraButton(
                label: l10n.text(AdminStrings.formSave),
                icon: Icons.check,
                isLoading: busy,
                onPressed: () => run(() => save(<String, Object?>{
                  'enabled': _enabled,
                  'projectId': orNull(_projectId),
                  if (secret.text.isNotEmpty) 'serviceAccountJson': secret.text,
                })),
              ),
              const SizedBox(width: AbraSpacing.md),
              AbraButton(
                label: l10n.text(AdminStrings.settingsTestConnection),
                icon: Icons.wifi_tethering,
                variant: AbraButtonVariant.secondary,
                isLoading: busy,
                onPressed: () => run(test),
              ),
            ],
          ),
        _OutcomeLine(outcome: outcome),
      ],
    );
  }
}

Widget _secretHelpBox(BuildContext context, AbraLocalizations l10n) => Container(
  padding: const EdgeInsets.all(AbraSpacing.md),
  decoration: BoxDecoration(
    color: Colors.grey.shade100,
    borderRadius: AbraRadius.medium,
    border: Border.all(color: AbraColors.divider),
  ),
  child: Row(
    children: [
      const Icon(Icons.lock_outline, size: 18),
      const SizedBox(width: AbraSpacing.sm),
      Expanded(
        child: Text(
          l10n.text(AdminStrings.settingsSetupSecretHelp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  ),
);

// ---------------------------------------------------------------- Company
class _CompanyTab extends StatefulWidget {
  const _CompanyTab({required this.canEdit});
  final bool canEdit;
  @override
  State<_CompanyTab> createState() => _CompanyTabState();
}

class _CompanyTabState extends State<_CompanyTab> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _gstin.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          decoration: BoxDecoration(
            color: AbraColors.white,
            borderRadius: AbraRadius.large,
            border: Border.all(color: AbraColors.divider),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.text(AdminStrings.settingsCompanyTitle), style: theme.textTheme.titleLarge),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                'Not connected yet - built in Phase 6',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              TextField(
                controller: _name,
                enabled: widget.canEdit,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsCompanyName)),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _email,
                enabled: widget.canEdit,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.settingsCompanyEmail),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _phone,
                enabled: widget.canEdit,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsCompanyPhone)),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _gstin,
                enabled: widget.canEdit,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsCompanyGstin)),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _address,
                enabled: widget.canEdit,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsCompanyAddress)),
              ),
              const SizedBox(height: AbraSpacing.xl),
              Tooltip(
                message: 'Not connected yet',
                child: AbraButton(
                  label: l10n.text(AdminStrings.formSave),
                  icon: Icons.check,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Booking rules
class _BookingRulesTab extends StatefulWidget {
  const _BookingRulesTab({required this.canEdit});
  final bool canEdit;
  @override
  State<_BookingRulesTab> createState() => _BookingRulesTabState();
}

class _BookingRulesTabState extends State<_BookingRulesTab> {
  final _holdSeconds = TextEditingController();
  final _maxSeats = TextEditingController();
  final _cutoffMinutes = TextEditingController();
  final _advanceDays = TextEditingController();

  @override
  void dispose() {
    _holdSeconds.dispose();
    _maxSeats.dispose();
    _cutoffMinutes.dispose();
    _advanceDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          decoration: BoxDecoration(
            color: AbraColors.white,
            borderRadius: AbraRadius.large,
            border: Border.all(color: AbraColors.divider),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.text(AdminStrings.settingsBookingTitle), style: theme.textTheme.titleLarge),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                'Not connected yet - built in Phase 6',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              TextField(
                controller: _holdSeconds,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.settingsHoldSeconds),
                  helperText: l10n.text(AdminStrings.settingsHoldSecondsHint),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _maxSeats,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.settingsMaxSeats),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _cutoffMinutes,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsCutoffMinutes)),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _advanceDays,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsAdvanceDays)),
              ),
              const SizedBox(height: AbraSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: BoxDecoration(
                  color: AbraColors.blueContainer,
                  borderRadius: AbraRadius.medium,
                  border: Border.all(color: AbraColors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AbraColors.blue, size: 20),
                    const SizedBox(width: AbraSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.text(AdminStrings.settingsBookingNotice),
                        style: theme.textTheme.bodySmall?.copyWith(color: AbraColors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              Tooltip(
                message: 'Not connected yet',
                child: AbraButton(
                  label: l10n.text(AdminStrings.formSave),
                  icon: Icons.check,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Security
class _SecurityTab extends StatefulWidget {
  const _SecurityTab({required this.canEdit});
  final bool canEdit;
  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  bool _mfaRequired = false;
  final _sessionMinutes = TextEditingController();
  final _passwordDays = TextEditingController();

  @override
  void dispose() {
    _sessionMinutes.dispose();
    _passwordDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          decoration: BoxDecoration(
            color: AbraColors.white,
            borderRadius: AbraRadius.large,
            border: Border.all(color: AbraColors.divider),
            boxShadow: AbraShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.text(AdminStrings.settingsSecurityTitle), style: theme.textTheme.titleLarge),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                'Not connected yet - built in Phase 6',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.text(AdminStrings.settingsMfaRequired)),
                value: _mfaRequired,
                onChanged: widget.canEdit ? (v) => setState(() => _mfaRequired = v) : null,
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _sessionMinutes,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsSessionMinutes)),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _passwordDays,
                enabled: widget.canEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.text(AdminStrings.settingsPasswordDays)),
              ),
              const SizedBox(height: AbraSpacing.xl),
              Tooltip(
                message: 'Not connected yet',
                child: AbraButton(
                  label: l10n.text(AdminStrings.formSave),
                  icon: Icons.check,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Message templates
class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab();

  static const _templates = <List<String>>[
    ['Booking confirmed', 'Push, WhatsApp, Email', 'English; others fall back'],
    ['Trip delayed', 'Push, WhatsApp', 'English'],
    ['Trip cancelled and refunded', 'Push, WhatsApp, Email', 'English'],
    ['Refund completed', 'Push, Email', 'English'],
    ['KYC approved', 'Push, Email, WhatsApp', 'English'],
    ['KYC rejected', 'Push, Email, WhatsApp', 'English'],
    ['Sign-in code', 'WhatsApp, SMS', 'English'],
  ];

  static Future<void> _preview(BuildContext context, String name) async {
    final l10n = AbraLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.text(AdminStrings.settingsTplPreviewTitle)),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AbraColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: AbraSpacing.sm),
              const Text(
                'Not connected yet',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.text(AdminStrings.commClose)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md, left: AbraSpacing.xs),
            child: Text(
              'Not connected yet - built in Phase 6',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AbraColors.white,
              borderRadius: AbraRadius.large,
              border: Border.all(color: AbraColors.divider),
              boxShadow: AbraShadows.soft,
            ),
            child: DataTable(
              columns: <DataColumn>[
                DataColumn(label: Text(l10n.text(AdminStrings.settingsTplColMessage))),
                DataColumn(label: Text(l10n.text(AdminStrings.settingsTplColChannels))),
                DataColumn(label: Text(l10n.text(AdminStrings.settingsTplColLanguages))),
                const DataColumn(label: Text('')),
              ],
              rows: <DataRow>[
                for (final tpl in _templates)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text(tpl[0], style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(tpl[1])),
                      DataCell(Text(tpl[2])),
                      DataCell(
                        OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: Text(l10n.text(AdminStrings.settingsTplPreview)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _preview(context, tpl[0]),
                        ),
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
}
