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

/// Settings: a grid of cards, one per connection (WhatsApp, email). A search
/// box filters the cards; a card opens its form in a pop-up. Anyone with
/// `settings.read` can look; only a Super Admin (`settings.update`) can change
/// or test. Secrets are write-only: the backend never returns them, so the
/// fields stay empty and an empty field means "keep what is saved".
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

  /// Extra words that find the card in the search box.
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
];

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _query = '';

  Future<void> _open(_Section section) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SettingsDialog(section: section),
    );
    // The card shows the state the form left it in
    ref.invalidate(settingsProvider(section.channel));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final needle = _query.trim().toLowerCase();
    final shown = <_Section>[
      for (final section in _sections)
        if (needle.isEmpty ||
            l10n.text(section.labelKey).toLowerCase().contains(needle) ||
            l10n.text(section.hintKey).toLowerCase().contains(needle) ||
            section.keywords.any((word) => word.contains(needle)))
          section,
    ];
    return ListView(
      padding: const EdgeInsets.all(AbraSpacing.xl),
      children: <Widget>[
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
                _SettingsCard(section: section, onTap: () => _open(section)),
            ],
          ),
      ],
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.section, required this.onTap});

  final _Section section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref
        .watch(settingsProvider(section.channel))
        .value?['status'];
    final badge = switch ('$status') {
      'READY' => (AdminStrings.settingsStatusReady, AbraStatusTone.success),
      'DISABLED' => (
        AdminStrings.settingsStatusDisabled,
        AbraStatusTone.neutral,
      ),
      'INCOMPLETE' => (
        AdminStrings.settingsStatusIncomplete,
        AbraStatusTone.warning,
      ),
      _ => null,
    };
    return SizedBox(
      width: 260,
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
              CircleAvatar(
                radius: 24,
                backgroundColor: section.color.withValues(alpha: 0.12),
                child: Icon(section.icon, color: section.color),
              ),
              const SizedBox(height: AbraSpacing.md),
              Text(
                l10n.text(section.labelKey),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                l10n.text(section.hintKey),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AbraSpacing.md),
              if (badge != null)
                AbraStatusBadge(label: l10n.text(badge.$1), tone: badge.$2)
              else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The form of one connection, in a pop-up with a title and a close button.
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
          },
        ),
      ),
    ),
  );
}

/// What the last save or test said, shown under the buttons.
class _Outcome {
  const _Outcome({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// State and helpers shared by the two forms.
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

  /// Runs [action], showing its failure in the outcome line.
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

/// The form label for a setting the backend reports as missing.
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
