import 'package:intl/intl.dart';

/// Fills in a translated message.
///
/// Supported syntax (a subset of ICU MessageFormat, as used in ARB files):
/// - placeholders: `Reference: {requestId}`
/// - plurals: `{count, plural, =0{No seats} one{# seat} other{# seats}}`,
///   where `#` is the number formatted for the locale. Plural categories
///   (zero, one, two, few, many, other) follow the rules of the locale, so
///   languages with more than two forms (Arabic, Russian, ...) work.
///   As in Flutter's own generated localizations (`Intl.pluralLogic`), a
///   `zero`, `one` or `two` branch also matches the exact numbers 0, 1
///   and 2, so write only the categories the language really has.
///
/// A placeholder without a value is left as it is, so a missing argument is
/// visible in testing instead of silently disappearing.
abstract final class MessageFormatter {
  static final RegExp _simplePlaceholder = RegExp(r'\{(\w+)\}');

  /// Formats [pattern] for [localeTag] (underscore form, e.g. `en_IN`).
  static String format(
    String pattern,
    String localeTag, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    final expanded = _expandPlurals(pattern, localeTag, arguments);
    return expanded.replaceAllMapped(_simplePlaceholder, (match) {
      final name = match.group(1)!;
      return arguments.containsKey(name)
          ? '${arguments[name]}'
          : match.group(0)!;
    });
  }

  static String _expandPlurals(
    String pattern,
    String localeTag,
    Map<String, Object?> arguments,
  ) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < pattern.length) {
      final start = pattern.indexOf('{', index);
      if (start < 0) break;
      final end = _matchingBrace(pattern, start);
      if (end < 0) break;

      final inner = pattern.substring(start + 1, end);
      final header = RegExp(r'^\s*(\w+)\s*,\s*plural\s*,').firstMatch(inner);
      if (header == null) {
        // Not a plural: keep the text, placeholders are replaced afterwards.
        buffer.write(pattern.substring(index, end + 1));
      } else {
        buffer
          ..write(pattern.substring(index, start))
          ..write(
            _plural(
              header.group(1)!,
              inner.substring(header.end),
              localeTag,
              arguments,
            ),
          );
      }
      index = end + 1;
    }
    buffer.write(pattern.substring(index));
    return buffer.toString();
  }

  static String _plural(
    String argumentName,
    String formsSource,
    String localeTag,
    Map<String, Object?> arguments,
  ) {
    final count = arguments[argumentName];
    if (count is! num) return '{$argumentName}';

    final forms = _pluralForms(formsSource);
    final other = forms['other'] ?? '';
    final chosen =
        forms['=${count is int ? count : count.toString()}'] ??
        Intl.pluralLogic<String?>(
          count,
          locale: localeTag,
          zero: forms['zero'],
          one: forms['one'],
          two: forms['two'],
          few: forms['few'],
          many: forms['many'],
          other: other,
        ) ??
        other;
    final number = NumberFormat.decimalPattern(
      NumberFormat.localeExists(localeTag) ? localeTag : null,
    ).format(count);
    return chosen.replaceAll('#', number);
  }

  /// Splits `=0{...} one{...} other{...}` into its forms.
  static Map<String, String> _pluralForms(String source) {
    final forms = <String, String>{};
    var index = 0;
    while (index < source.length) {
      final open = source.indexOf('{', index);
      if (open < 0) break;
      final close = _matchingBrace(source, open);
      if (close < 0) break;
      final selector = source.substring(index, open).trim();
      if (selector.isNotEmpty) {
        forms[selector] = source.substring(open + 1, close);
      }
      index = close + 1;
    }
    return forms;
  }

  /// Index of the `}` that closes the `{` at [open], or -1.
  static int _matchingBrace(String text, int open) {
    var depth = 0;
    for (var i = open; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}' && --depth == 0) return i;
    }
    return -1;
  }
}
