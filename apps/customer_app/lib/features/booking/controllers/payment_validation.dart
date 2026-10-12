/// Checks of the payment forms, without any widget so they can be tested on
/// their own.
abstract final class PaymentValidation {
  static final RegExp _upiId = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');

  static bool isValidUpiId(String input) => _upiId.hasMatch(input.trim());

  /// Digits of [input] only.
  static String digits(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// 13 to 19 digits that pass the Luhn check.
  static bool isValidCardNumber(String input) {
    final number = digits(input);
    if (number.length < 13 || number.length > 19) return false;
    var sum = 0;
    var doubleIt = false;
    for (var i = number.length - 1; i >= 0; i--) {
      var digit = number.codeUnitAt(i) - 48;
      if (doubleIt) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  /// "MM/YY" in the future: valid through the end of the month shown.
  static bool isValidExpiry(String input, DateTime now) {
    final match = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(input.trim());
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;
    final endOfMonth = DateTime(year, month + 1);
    return endOfMonth.isAfter(now);
  }

  static bool isValidCvv(String input) => RegExp(r'^\d{3}$').hasMatch(input);

  static bool isValidCardName(String input) => input.trim().length >= 2;

  /// "1234567890123456" → "1234 5678 9012 3456".
  static String groupCardNumber(String input) {
    final number = digits(input);
    final groups = <String>[
      for (var i = 0; i < number.length; i += 4)
        number.substring(i, i + 4 > number.length ? number.length : i + 4),
    ];
    return groups.join(' ');
  }
}
