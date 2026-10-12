import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../core/ui/chips.dart';
import '../../../core/ui/tonal_button.dart';
import '../../../l10n/customer_strings.dart';
import '../controllers/payment_controller.dart';
import '../controllers/payment_validation.dart';
import '../models/payment_models.dart';

/// One way to pay as a card: a radio row with its name and hint, and, while
/// it is the chosen one, its form below.
class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onSelected,
    required this.body,
    super.key,
  });

  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? AbraColors.lightBlue : AbraColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AbraRadius.large,
        side: BorderSide(
          color: selected ? AbraColors.blue : AbraColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: selected,
              button: true,
              label: '$title, $hint',
              excludeSemantics: true,
              onTap: onSelected,
              child: InkWell(
                borderRadius: AbraRadius.medium,
                onTap: onSelected,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AbraSizes.minTouchTarget,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(hint, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      _Radio(selected: selected),
                    ],
                  ),
                ),
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(height: AbraSpacing.md),
              body,
            ],
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AbraColors.blue : null,
        border: Border.all(
          color: selected ? AbraColors.blue : const Color(0xFF9FB3C3),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: AbraColors.white)
          : null,
    ),
  );
}

/// A choice shown as a tile with a mark and a name (a UPI app, a wallet).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.mark,
    required this.markColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String mark;
  final Color markColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AbraColors.lightBlue : AbraColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AbraRadius.large,
          side: BorderSide(
            color: selected ? AbraColors.blue : AbraColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: AbraRadius.large,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AbraSpacing.md,
                vertical: AbraSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  // A placeholder for the brand's official mark (listed in
                  // MISSING_ASSETS.md).
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: markColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mark,
                      style: textTheme.labelLarge?.copyWith(
                        color: AbraColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AbraColors.blue,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// UPI: four app tiles, or a UPI id.
class UpiBody extends ConsumerStatefulWidget {
  const UpiBody({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<UpiBody> createState() => _UpiBodyState();
}

class _UpiBodyState extends ConsumerState<UpiBody> {
  late final TextEditingController _id = TextEditingController(
    text: ref.read(paymentProvider(widget.tripId)).upiId,
  );
  bool _verified = false;
  bool _showError = false;

  static const _marks = <UpiApp, (String, Color)>{
    UpiApp.gpay: ('G', AbraColors.blue),
    UpiApp.phonepe: ('P', AbraColors.deepBlue),
    UpiApp.paytm: ('P', AbraColors.skyBlue),
    UpiApp.bhim: ('B', AbraColors.navy),
  };

  static const _names = <UpiApp, String>{
    UpiApp.gpay: CustomerStrings.payUpiGpay,
    UpiApp.phonepe: CustomerStrings.payUpiPhonepe,
    UpiApp.paytm: CustomerStrings.payUpiPaytm,
    UpiApp.bhim: CustomerStrings.payUpiBhim,
  };

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final state = ref.watch(paymentProvider(widget.tripId));
    final notifier = ref.read(paymentProvider(widget.tripId).notifier);
    final textTheme = Theme.of(context).textTheme;
    final idInvalid =
        _showError && !PaymentValidation.isValidUpiId(state.upiId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - AbraSpacing.sm) / 2;
            return Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                for (final app in UpiApp.values)
                  SizedBox(
                    width: tileWidth,
                    child: _ChoiceTile(
                      label: l10n.text(_names[app]!),
                      mark: _marks[app]!.$1,
                      markColor: _marks[app]!.$2,
                      selected: state.upiApp == app,
                      onTap: () =>
                          notifier.setUpiApp(state.upiApp == app ? null : app),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AbraSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.payUpiId),
                  hintText: l10n.text(CustomerStrings.payUpiIdHint),
                  errorText: idInvalid
                      ? l10n.text(CustomerStrings.payUpiIdError)
                      : null,
                  helperText: _verified
                      ? l10n.text(CustomerStrings.payUpiVerified)
                      : null,
                  helperStyle: textTheme.bodySmall?.copyWith(
                    color: AbraColors.tealDark,
                  ),
                ),
                onChanged: (value) {
                  notifier.setUpiId(value);
                  setState(() {
                    _verified = false;
                    _showError = false;
                  });
                },
              ),
            ),
            const SizedBox(width: AbraSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: AbraSpacing.xs),
              child: TonalButton(
                label: l10n.text(CustomerStrings.payUpiVerify),
                onPressed: () => setState(() {
                  final valid = PaymentValidation.isValidUpiId(_id.text);
                  _verified = valid;
                  _showError = !valid;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Puts a space after every four digits as the customer types.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = PaymentValidation.digits(newValue.text);
    final limited = digits.length > 19 ? digits.substring(0, 19) : digits;
    final text = PaymentValidation.groupCardNumber(limited);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// "MM/YY": the slash is added after the month.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = PaymentValidation.digits(newValue.text);
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Card: number, expiry, CVV and name. The details live only in memory while
/// this screen is open.
class CardBody extends ConsumerStatefulWidget {
  const CardBody({required this.tripId, required this.now, super.key});

  final String tripId;
  final DateTime Function() now;

  @override
  ConsumerState<CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends ConsumerState<CardBody> {
  late final PaymentState _initial = ref.read(paymentProvider(widget.tripId));
  late final TextEditingController _number = TextEditingController(
    text: _initial.cardNumber,
  );
  late final TextEditingController _expiry = TextEditingController(
    text: _initial.cardExpiry,
  );
  late final TextEditingController _cvv = TextEditingController(
    text: _initial.cardCvv,
  );
  late final TextEditingController _name = TextEditingController(
    text: _initial.cardName,
  );

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final state = ref.watch(paymentProvider(widget.tripId));
    final notifier = ref.read(paymentProvider(widget.tripId).notifier);
    String? error(bool show, bool valid, String key) =>
        show && !valid ? l10n.text(key) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _number,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.creditCardNumber],
          inputFormatters: <TextInputFormatter>[_CardNumberFormatter()],
          decoration: InputDecoration(
            labelText: l10n.text(CustomerStrings.payCardNumber),
            hintText: '1234 5678 9012 3456',
            errorText: error(
              state.cardNumber.length >= 13,
              PaymentValidation.isValidCardNumber(state.cardNumber),
              CustomerStrings.payCardNumberError,
            ),
          ),
          onChanged: notifier.setCardNumber,
        ),
        const SizedBox(height: AbraSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _expiry,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.creditCardExpirationDate,
                ],
                inputFormatters: <TextInputFormatter>[_ExpiryFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.payCardExpiry),
                  hintText: 'MM/YY',
                  errorText: error(
                    state.cardExpiry.length == 5,
                    PaymentValidation.isValidExpiry(
                      state.cardExpiry,
                      widget.now(),
                    ),
                    CustomerStrings.payCardExpiryError,
                  ),
                ),
                onChanged: notifier.setCardExpiry,
              ),
            ),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              child: TextField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                obscureText: true,
                maxLength: 3,
                autofillHints: const <String>[
                  AutofillHints.creditCardSecurityCode,
                ],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.payCardCvv),
                  counterText: '',
                  errorText: error(
                    state.cardCvv.isNotEmpty && state.cardCvv.length < 3,
                    false,
                    CustomerStrings.payCardCvvError,
                  ),
                ),
                onChanged: notifier.setCardCvv,
              ),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.md),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.creditCardName],
          decoration: InputDecoration(
            labelText: l10n.text(CustomerStrings.payCardName),
          ),
          onChanged: notifier.setCardName,
        ),
      ],
    );
  }
}

/// Net banking: the banks as chips.
class NetBankingBody extends ConsumerWidget {
  const NetBankingBody({required this.tripId, super.key});

  final String tripId;

  static const _names = <Bank, String>{
    Bank.sbi: CustomerStrings.payBankSbi,
    Bank.hdfc: CustomerStrings.payBankHdfc,
    Bank.icici: CustomerStrings.payBankIcici,
    Bank.axis: CustomerStrings.payBankAxis,
    Bank.kotak: CustomerStrings.payBankKotak,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final state = ref.watch(paymentProvider(tripId));
    final notifier = ref.read(paymentProvider(tripId).notifier);
    return Wrap(
      spacing: AbraSpacing.sm,
      runSpacing: AbraSpacing.sm,
      children: <Widget>[
        for (final bank in Bank.values)
          SelectChip(
            label: l10n.text(_names[bank]!),
            selected: state.bank == bank,
            onSelected: (_) => notifier.setBank(bank),
          ),
      ],
    );
  }
}

/// Wallets: one row each.
class WalletBody extends ConsumerWidget {
  const WalletBody({required this.tripId, super.key});

  final String tripId;

  static const _items = <WalletProvider, (String, String, Color)>{
    WalletProvider.paytm: (
      CustomerStrings.payWalletPaytm,
      'P',
      AbraColors.skyBlue,
    ),
    WalletProvider.phonepe: (
      CustomerStrings.payWalletPhonepe,
      'P',
      AbraColors.deepBlue,
    ),
    WalletProvider.amazonPay: (
      CustomerStrings.payWalletAmazon,
      'A',
      AbraColors.navy,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final state = ref.watch(paymentProvider(tripId));
    final notifier = ref.read(paymentProvider(tripId).notifier);
    return Column(
      children: <Widget>[
        for (final entry in _items.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
            child: _ChoiceTile(
              label: l10n.text(entry.value.$1),
              mark: entry.value.$2,
              markColor: entry.value.$3,
              selected: state.wallet == entry.key,
              onTap: () => notifier.setWallet(entry.key),
            ),
          ),
      ],
    );
  }
}

/// "Payments are encrypted and processed by a PCI-DSS partner".
class SecureNote extends StatelessWidget {
  const SecureNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AbraColors.textSecondary,
          ),
        ),
        const SizedBox(width: AbraSpacing.sm),
        Expanded(
          child: Text(
            l10n.text(CustomerStrings.payEncrypted),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
