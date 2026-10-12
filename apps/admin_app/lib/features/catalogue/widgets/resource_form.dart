import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';

/// One field of a management form.
sealed class FieldSpec {
  const FieldSpec(
    this.key,
    this.labelKey, {
    this.isRequired = false,
    this.fullWidth = false,
    this.visibleWhen,
  });

  /// Name of the field in the request body.
  final String key;
  final String labelKey;
  final bool isRequired;

  /// In a two-column form: takes the whole row instead of half of it.
  final bool fullWidth;

  /// Shown only while this returns true for the values typed so far (the
  /// offer code only when the banner opens an offer). A hidden field is not
  /// checked and not sent.
  final bool Function(JsonMap values)? visibleWhen;
}

class TextSpec extends FieldSpec {
  const TextSpec(
    super.key,
    super.labelKey, {
    super.isRequired,
    super.fullWidth,
    super.visibleWhen,
    this.maxLines = 1,
    this.clearable = false,
    this.helpKey,
    this.helpKeyOf,
  });

  final int maxLines;

  /// When editing, emptying the field sends `null` (the backend clears it).
  final bool clearable;
  final String? helpKey;

  /// A help line that depends on the other values of the form (what to enter
  /// for the chosen kind); wins over [helpKey] when it returns a key.
  final String? Function(JsonMap values)? helpKeyOf;
}

class NumberSpec extends FieldSpec {
  const NumberSpec(
    super.key,
    super.labelKey, {
    super.isRequired,
    super.fullWidth,
    this.allowDecimal = false,
    this.scale = 1,
  });

  final bool allowDecimal;

  /// The value sent is the entered number times this (rupees to paise: 100).
  final int scale;
}

/// A calendar day, sent as `YYYY-MM-DD`. Picked from a calendar; may be
/// emptied again (when editing, emptying it sends `null`).
class DateSpec extends FieldSpec {
  const DateSpec(
    super.key,
    super.labelKey, {
    super.isRequired,
    super.fullWidth,
  });
}

class BoolSpec extends FieldSpec {
  const BoolSpec(super.key, super.labelKey);
}

/// One of a fixed set of values; [options] maps each value to its label key.
class ChoiceSpec extends FieldSpec {
  const ChoiceSpec(
    super.key,
    super.labelKey,
    this.options, {
    super.isRequired,
    super.fullWidth,
    super.visibleWhen,
  });

  final Map<String, String> options;
}

/// A record chosen from a catalogue list the user may see.
class RefSpec extends FieldSpec {
  const RefSpec(
    super.key,
    super.labelKey,
    this.optionsPath,
    this.labelOf, {
    super.isRequired,
    super.fullWidth,
    super.visibleWhen,
  });

  final String optionsPath;
  final String Function(JsonMap record) labelOf;
}

/// Any number of a fixed set of values.
class MultiChoiceSpec extends FieldSpec {
  const MultiChoiceSpec(super.key, super.labelKey, this.options, this.labelOf);

  final List<String> options;
  final String Function(String value) labelOf;
}

/// A list of rows, each with the same fields (stops of a route, points of a
/// trip).
class RowsSpec extends FieldSpec {
  const RowsSpec(super.key, super.labelKey, this.fields, {this.minRows = 0});

  final List<FieldSpec> fields;
  final int minRows;
}

/// Thrown by an `onSubmit` to show [message] in the form as it is (for
/// example: saved, but a file could not be uploaded).
class ResourceFormMessage implements Exception {
  const ResourceFormMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Something a page adds below the fields (files, a preview). It sees the
/// values as they are typed and is rebuilt on every change.
typedef ResourceFormExtra =
    Widget Function(BuildContext context, JsonMap values, bool isSaving);

/// A second way to save a form, shown as a button beside the main one
/// ("Save draft" beside "Publish"). It receives the same values.
class FormAction {
  const FormAction(this.label, this.onSubmit);

  final String label;
  final Future<void> Function(JsonMap values) onSubmit;
}

/// Opens a create or edit form. [onSubmit] receives the values to send;
/// when it throws, the reason from the backend is shown in the form and the
/// form stays open. Returns true when the form was saved.
///
/// [secondary] adds buttons beside the main one. [columns] 2 puts the fields
/// side by side (a field with `fullWidth` takes the whole row). [side] is
/// shown to the right of the fields on a wide dialog, below them otherwise
/// (a preview). [width] is the width of the dialog.
Future<bool> showResourceForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Future<void> Function(JsonMap values) onSubmit,
  JsonMap initial = const <String, Object?>{},
  String? submitLabel,
  String? message,
  ResourceFormExtra? extra,
  ResourceFormExtra? side,
  List<FormAction> secondary = const <FormAction>[],
  int columns = 1,
  double width = 640,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ResourceFormDialog(
      title: title,
      fields: fields,
      initial: initial,
      onSubmit: onSubmit,
      submitLabel: submitLabel,
      message: message,
      extra: extra,
      side: side,
      secondary: secondary,
      columns: columns,
      width: width,
    ),
  );
  return saved ?? false;
}

class _ResourceFormDialog extends ConsumerStatefulWidget {
  const _ResourceFormDialog({
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSubmit,
    this.submitLabel,
    this.message,
    this.extra,
    this.side,
    this.secondary = const <FormAction>[],
    this.columns = 1,
    this.width = 640,
  });

  final ResourceFormExtra? extra;
  final ResourceFormExtra? side;
  final List<FormAction> secondary;
  final int columns;
  final double width;
  final String title;
  final List<FieldSpec> fields;
  final JsonMap initial;
  final Future<void> Function(JsonMap values) onSubmit;
  final String? submitLabel;
  final String? message;

  @override
  ConsumerState<_ResourceFormDialog> createState() => _ResourceFormState();
}

class _ResourceFormState extends ConsumerState<_ResourceFormDialog> {
  late final JsonMap _values = <String, Object?>{
    for (final field in widget.fields)
      field.key: switch (field) {
        RowsSpec(:final fields) => <JsonMap>[
          for (final row
              in (widget.initial[field.key] as List<Object?>? ?? const []))
            <String, Object?>{
              // Only the fields of the form; values as editable text
              for (final sub in fields)
                sub.key: switch ((row! as JsonMap)[sub.key]) {
                  null => '',
                  final num value when sub is NumberSpec => _numberText(
                    value / sub.scale,
                  ),
                  final value => value.toString(),
                },
            },
        ],
        MultiChoiceSpec() => <String>{
          ...(widget.initial[field.key] as List<Object?>? ?? const [])
              .cast<String>(),
        },
        NumberSpec(:final scale) =>
          widget.initial[field.key] == null
              ? ''
              : _numberText((widget.initial[field.key]! as num) / scale),
        BoolSpec() => widget.initial[field.key] as bool? ?? false,
        DateSpec() => _dayOf(widget.initial[field.key]),
        _ => widget.initial[field.key]?.toString() ?? '',
      },
  };
  bool _showErrors = false;
  bool _isSaving = false;
  String? _failure;

  /// `YYYY-MM-DD` of a date or time from the API (in local time), or empty.
  static String _dayOf(Object? value) {
    final time = DateTime.tryParse('${value ?? ''}');
    if (time == null) return '';
    return (time.isUtc ? time.toLocal() : time).toIso8601String().substring(
      0,
      10,
    );
  }

  static String _numberText(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String? _problemOf(FieldSpec field, Object? value, AbraLocalizations l10n) {
    final text = value is String ? value.trim() : null;
    final isEmpty = switch (value) {
      String() => text!.isEmpty,
      null => true,
      _ => false,
    };
    if (isEmpty) {
      return field.isRequired ? l10n.text(AdminStrings.formRequired) : null;
    }
    if (field is NumberSpec) {
      final parsed = num.tryParse(text!);
      if (parsed == null) return l10n.text(AdminStrings.formNumber);
      if (!field.allowDecimal && field.scale == 1 && parsed is! int) {
        return l10n.text(AdminStrings.formWholeNumber);
      }
    }
    return null;
  }

  bool _isShown(FieldSpec field) => field.visibleWhen?.call(_values) ?? true;

  bool _isValid(AbraLocalizations l10n) {
    for (final field in widget.fields.where(_isShown)) {
      if (field is RowsSpec) {
        final rows = _values[field.key]! as List<JsonMap>;
        if (rows.length < field.minRows) return false;
        for (final row in rows) {
          for (final sub in field.fields) {
            if (_problemOf(sub, row[sub.key], l10n) != null) return false;
          }
        }
      } else if (_problemOf(field, _values[field.key], l10n) != null) {
        return false;
      }
    }
    return true;
  }

  Object? _apiValue(FieldSpec field, Object? value) => switch (field) {
    NumberSpec(:final scale, :final allowDecimal) => () {
      final parsed = num.parse((value! as String).trim()) * scale;
      return allowDecimal ? parsed : parsed.round();
    }(),
    TextSpec() => (value! as String).trim(),
    _ => value,
  };

  JsonMap _collect() {
    final isEdit = widget.initial.isNotEmpty;
    final body = <String, Object?>{};
    for (final field in widget.fields.where(_isShown)) {
      final value = _values[field.key];
      switch (field) {
        case RowsSpec():
          body[field.key] = <JsonMap>[
            for (final row in value! as List<JsonMap>)
              <String, Object?>{
                for (final sub in field.fields)
                  if ((row[sub.key]?.toString() ?? '').trim().isNotEmpty)
                    sub.key: _apiValue(sub, row[sub.key]),
              },
          ];
        case MultiChoiceSpec():
          body[field.key] = (value! as Set<String>).toList();
        case BoolSpec():
          body[field.key] = value;
        default:
          final text = (value! as String).trim();
          if (text.isNotEmpty) {
            body[field.key] = _apiValue(field, text);
          } else if (isEdit &&
              (field is TextSpec && field.clearable || field is DateSpec) &&
              widget.initial[field.key] != null) {
            body[field.key] = null;
          }
      }
    }
    return body;
  }

  Future<void> _submit([Future<void> Function(JsonMap values)? action]) async {
    final l10n = AbraLocalizations.of(context);
    if (!_isValid(l10n)) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    try {
      await (action ?? widget.onSubmit)(_collect());
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _failure = error is ResourceFormMessage
            ? error.message
            : failureText(l10n, error);
      });
    }
  }

  Widget _field(FieldSpec field, JsonMap values, {Key? key}) {
    final l10n = AbraLocalizations.of(context);
    final label = l10n.text(field.labelKey);
    final error = _showErrors
        ? _problemOf(field, values[field.key], l10n)
        : null;
    switch (field) {
      case TextSpec():
      case NumberSpec():
        return TextFormField(
          key: key,
          initialValue: values[field.key] as String?,
          enabled: !_isSaving,
          maxLines: field is TextSpec ? field.maxLines : 1,
          keyboardType: field is NumberSpec
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters: <TextInputFormatter>[
            if (field is NumberSpec)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            helperText: switch (field) {
              TextSpec(:final helpKeyOf?) when helpKeyOf(values) != null =>
                l10n.text(helpKeyOf(values)!),
              TextSpec(:final helpKey?) => l10n.text(helpKey),
              _ => null,
            },
          ),
          onChanged: (text) {
            values[field.key] = text;
            // What the page added may show what is typed (a preview).
            if (widget.extra != null) setState(() {});
          },
        );
      case DateSpec():
        final day = values[field.key]! as String;
        return InkWell(
          key: key,
          borderRadius: AbraRadius.medium,
          onTap: _isSaving
              ? null
              : () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(day) ?? now,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 10),
                  );
                  if (picked == null || !mounted) return;
                  setState(
                    () => values[field.key] = picked
                        .toIso8601String()
                        .substring(0, 10),
                  );
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              suffixIcon: day.isEmpty
                  ? const Icon(Icons.calendar_today_outlined, size: 18)
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.text(AdminStrings.formClearDate),
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => values[field.key] = ''),
                    ),
            ),
            child: Text(day),
          ),
        );
      case BoolSpec():
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: values[field.key]! as bool,
          onChanged: _isSaving
              ? null
              : (value) => setState(() => values[field.key] = value),
        );
      case ChoiceSpec():
        return _dropdown(
          key: key,
          label: label,
          error: error,
          value: values[field.key] as String?,
          items: <String, String>{
            for (final entry in field.options.entries)
              entry.key: l10n.text(entry.value),
          },
          onChanged: (value) => setState(() => values[field.key] = value),
        );
      case RefSpec():
        final options = ref.watch(optionsProvider(field.optionsPath));
        return options.when(
          loading: () => InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: const LinearProgressIndicator(),
          ),
          error: (failure, _) => InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: failureText(l10n, failure),
            ),
            child: const SizedBox.shrink(),
          ),
          data: (records) => _dropdown(
            key: key,
            label: label,
            error: error,
            value: values[field.key] as String?,
            items: <String, String>{
              for (final record in records)
                record['id']! as String: field.labelOf(record),
            },
            onChanged: (value) => setState(() => values[field.key] = value),
          ),
        );
      case MultiChoiceSpec():
        final selected = values[field.key]! as Set<String>;
        return InputDecorator(
          key: key,
          decoration: InputDecoration(labelText: label),
          child: Wrap(
            spacing: AbraSpacing.sm,
            children: <Widget>[
              for (final option in field.options)
                FilterChip(
                  label: Text(field.labelOf(option)),
                  selected: selected.contains(option),
                  onSelected: _isSaving
                      ? null
                      : (isOn) => setState(
                          () => isOn
                              ? selected.add(option)
                              : selected.remove(option),
                        ),
                ),
            ],
          ),
        );
      case RowsSpec():
        final rows = values[field.key]! as List<JsonMap>;
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('${l10n.text(AdminStrings.formAddRow)}: $label'),
                  onPressed: _isSaving
                      ? null
                      : () => setState(
                          () => rows.add(<String, Object?>{
                            for (final sub in field.fields) sub.key: '',
                          }),
                        ),
                ),
              ],
            ),
            if (_showErrors && rows.length < field.minRows)
              Text(
                l10n.text(AdminStrings.formRequired),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            for (final row in rows)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(top: AbraSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final sub in field.fields) ...<Widget>[
                      Expanded(
                        flex: sub is RefSpec ? 2 : 1,
                        child: _field(sub, row),
                      ),
                      const SizedBox(width: AbraSpacing.sm),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.text(AdminStrings.formRemoveRow),
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => rows.remove(row)),
                    ),
                  ],
                ),
              ),
          ],
        );
    }
  }

  Widget _dropdown({
    required String label,
    required String? error,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    Key? key,
  }) => DropdownButtonFormField<String>(
    key: key,
    // A stored value that is no longer offered (disabled since) is kept out
    // of the selector rather than shown as a broken choice.
    initialValue: items.containsKey(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, errorText: error),
    items: <DropdownMenuItem<String>>[
      for (final entry in items.entries)
        DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _isSaving ? null : onChanged,
  );

  /// A field with its spacing. Keyed: a message appearing above must not
  /// shift what was typed from one field into the next.
  Widget _fieldBox(FieldSpec field) => Padding(
    key: ValueKey<String>(field.key),
    padding: const EdgeInsets.only(bottom: AbraSpacing.md),
    child: _field(field, _values),
  );

  /// The fields one below the other, or two to a row in a two-column form.
  List<Widget> _fieldWidgets() {
    final fields = widget.fields.where(_isShown).toList();
    if (widget.columns < 2) {
      return <Widget>[for (final f in fields) _fieldBox(f)];
    }
    final rows = <Widget>[];
    var index = 0;
    while (index < fields.length) {
      final field = fields[index];
      final next = index + 1 < fields.length ? fields[index + 1] : null;
      if (field.fullWidth || next == null || next.fullWidth) {
        rows.add(_fieldBox(field));
        index += 1;
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _fieldBox(field)),
              const SizedBox(width: AbraSpacing.md),
              Expanded(child: _fieldBox(next)),
            ],
          ),
        );
        index += 2;
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final danger = AbraStatusColors.from(context).danger;
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md),
            child: Text(widget.message!),
          ),
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: danger.container,
                  borderRadius: AbraRadius.medium,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  child: Text(
                    _failure!,
                    style: TextStyle(color: danger.foreground),
                  ),
                ),
              ),
            ),
          ),
        ..._fieldWidgets(),
        if (widget.extra != null) widget.extra!(context, _values, _isSaving),
      ],
    );
    final side = widget.side?.call(context, _values, _isSaving);
    // Beside the fields when the dialog fits next to a preview, below otherwise
    final isWide = MediaQuery.sizeOf(context).width >= widget.width + 96;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: widget.width,
        child: SingleChildScrollView(
          child: side == null
              ? fields
              : isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: fields),
                    const SizedBox(width: AbraSpacing.lg),
                    Expanded(flex: 2, child: side),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    fields,
                    const SizedBox(height: AbraSpacing.md),
                    side,
                  ],
                ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        for (final action in widget.secondary)
          AbraButton(
            label: action.label,
            variant: AbraButtonVariant.secondary,
            onPressed: _isSaving ? null : () => _submit(action.onSubmit),
          ),
        AbraButton(
          label: widget.submitLabel ?? l10n.text(AdminStrings.formSave),
          variant: AbraButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
