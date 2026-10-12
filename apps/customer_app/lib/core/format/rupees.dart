import 'package:shared_localization/shared_localization.dart';

/// An amount in paise as the customer reads it: whole rupees without
/// decimals ("₹1,150"), anything else with them ("₹1,150.50"), grouped the
/// way the language writes numbers.
String formatRupees(
  AbraLocalizations l10n,
  int paise, {
  String currencyCode = 'INR',
}) {
  final text = l10n.formatters.currencyFromMinor(
    paise,
    currencyCode: currencyCode,
  );
  if (paise % 100 != 0) return text;
  return text.replaceFirst(RegExp(r'[.,]00(?=\D*$)'), '');
}
