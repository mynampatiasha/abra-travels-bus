/// Plain CSV, as spreadsheets write it: commas, optional quotes around a
/// field, a doubled quote inside quotes, and line breaks inside quotes.
abstract final class Csv {
  /// One CSV line for [fields].
  static String line(Iterable<Object?> fields) => fields.map(_field).join(',');

  /// Rows as one text, header first, ready to be saved as a `.csv` file. A
  /// byte-order mark makes Excel read the text as UTF-8.
  static String encode(List<String> header, Iterable<List<Object?>> rows) =>
      '\u{FEFF}${<String>[line(header), for (final row in rows) line(row)].join('\r\n')}\r\n';

  static String _field(Object? value) {
    final text = value == null ? '' : '$value';
    // A spreadsheet runs a cell that starts like a formula; keep it as text
    final safe =
        text.isNotEmpty &&
            '=+-@'.contains(text[0]) &&
            num.tryParse(text) == null
        ? "'$text"
        : text;
    return safe.contains(RegExp('[",\r\n]'))
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  /// The rows of [text], each a list of fields. Blank lines are dropped.
  static List<List<String>> parse(String text) {
    final source = text.startsWith('\u{FEFF}') ? text.substring(1) : text;
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var i = 0;
    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    while (i < source.length) {
      final char = source[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        endField();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i += 1;
        }
        endRow();
      } else {
        field.write(char);
      }
      i += 1;
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }
}
