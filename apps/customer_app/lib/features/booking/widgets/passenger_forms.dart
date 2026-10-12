import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/ui/chips.dart';
import '../../../l10n/customer_strings.dart';
import '../models/booking_models.dart';
import '../models/seat_models.dart';

/// A card with a title, a hint and a switch ("Use my profile", "GST / ID
/// details"). The whole row is the tap target.
class SwitchCard extends StatelessWidget {
  const SwitchCard({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.child,
    super.key,
  });

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Shown under the row while the switch is on.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: InkWell(
              borderRadius: AbraRadius.medium,
              onTap: () => onChanged(!value),
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
                          Text(title, style: textTheme.titleSmall),
                          Text(hint, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Switch(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ),
          if (value && child != null) ...<Widget>[
            const SizedBox(height: AbraSpacing.md),
            child!,
          ],
        ],
      ),
    );
  }
}

/// One passenger: name, age and gender for one seat.
class PassengerCard extends StatefulWidget {
  const PassengerCard({
    required this.number,
    required this.seat,
    required this.entry,
    required this.errors,
    required this.showErrors,
    required this.onChanged,
    super.key,
  });

  final int number;
  final Seat seat;
  final PassengerEntry entry;
  final PassengerErrors errors;
  final bool showErrors;
  final ValueChanged<PassengerEntry> onChanged;

  @override
  State<PassengerCard> createState() => _PassengerCardState();
}

class _PassengerCardState extends State<PassengerCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name,
  );
  late final TextEditingController _age = TextEditingController(
    text: widget.entry.age,
  );

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLadies = widget.seat.status == SeatStatus.ladiesOnly;
    final errors = widget.errors;
    final show = widget.showErrors;
    final genderError = show && (errors.gender || errors.ladiesOnlyViolation);

    String? message(bool error, String key) =>
        show && error ? l10n.text(key) : null;

    final seatLabel = l10n.text(
      isLadies
          ? CustomerStrings.passengerSeatChipLadies
          : CustomerStrings.passengerSeatChip,
      <String, Object?>{'seat': widget.seat.id},
    );

    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.text(
                    CustomerStrings.passengerCardTitle,
                    <String, Object?>{'number': widget.number},
                  ),
                  style: textTheme.titleSmall,
                ),
              ),
              AbraStatusBadge(label: seatLabel, tone: AbraStatusTone.info),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.passengerName),
              errorText: message(
                errors.name,
                CustomerStrings.passengerNameError,
              ),
            ),
            onChanged: (value) =>
                widget.onChanged(widget.entry.copyWith(name: value)),
          ),
          const SizedBox(height: AbraSpacing.md),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 2,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.passengerAge),
              counterText: '',
              errorText: message(errors.age, CustomerStrings.passengerAgeError),
            ),
            onChanged: (value) =>
                widget.onChanged(widget.entry.copyWith(age: value)),
          ),
          const SizedBox(height: AbraSpacing.md),
          Semantics(
            container: true,
            label: l10n.text(CustomerStrings.passengerGenderLabel),
            child: Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                for (final (gender, key) in const <(Gender, String)>[
                  (Gender.male, CustomerStrings.passengerGenderMale),
                  (Gender.female, CustomerStrings.passengerGenderFemale),
                  (Gender.other, CustomerStrings.passengerGenderOther),
                ])
                  SelectChip(
                    label: l10n.text(key),
                    selected: widget.entry.gender == gender,
                    onSelected: (_) =>
                        widget.onChanged(widget.entry.copyWith(gender: gender)),
                  ),
              ],
            ),
          ),
          if (genderError)
            Padding(
              padding: const EdgeInsets.only(top: AbraSpacing.xs + 2),
              child: Text(
                l10n.text(
                  errors.ladiesOnlyViolation
                      ? CustomerStrings.passengerLadiesError
                      : CustomerStrings.passengerGenderError,
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the ticket is sent: mobile and email.
class ContactCard extends StatefulWidget {
  const ContactCard({
    required this.contact,
    required this.showMobileError,
    required this.showEmailError,
    required this.onChanged,
    super.key,
  });

  final ContactEntry contact;
  final bool showMobileError;
  final bool showEmailError;
  final ValueChanged<ContactEntry> onChanged;

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  late final TextEditingController _mobile = TextEditingController(
    text: widget.contact.mobile,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.contact.email,
  );

  @override
  void dispose() {
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.contactTitle),
              style: textTheme.titleSmall,
            ),
          ),
          Text(
            l10n.text(CustomerStrings.contactHint),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AbraSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 88,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.text(CustomerStrings.contactCountryCode),
                  ),
                  child: Text('+91', style: textTheme.titleSmall),
                ),
              ),
              const SizedBox(width: AbraSpacing.md),
              Expanded(
                child: TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[
                    AutofillHints.telephoneNumberNational,
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.text(CustomerStrings.contactMobile),
                    errorText: widget.showMobileError
                        ? l10n.text(CustomerStrings.contactMobileError)
                        : null,
                  ),
                  onChanged: (value) =>
                      widget.onChanged(widget.contact.copyWith(mobile: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.text(CustomerStrings.contactEmail),
              errorText: widget.showEmailError
                  ? l10n.text(CustomerStrings.contactEmailError)
                  : null,
            ),
            onChanged: (value) =>
                widget.onChanged(widget.contact.copyWith(email: value)),
          ),
        ],
      ),
    );
  }
}

/// The optional GSTIN and company name for a business invoice.
class GstFields extends StatefulWidget {
  const GstFields({
    required this.gst,
    required this.showGstinError,
    required this.showCompanyError,
    required this.onChanged,
    super.key,
  });

  final GstEntry gst;
  final bool showGstinError;
  final bool showCompanyError;
  final ValueChanged<GstEntry> onChanged;

  @override
  State<GstFields> createState() => _GstFieldsState();
}

class _GstFieldsState extends State<GstFields> {
  late final TextEditingController _gstin = TextEditingController(
    text: widget.gst.gstin,
  );
  late final TextEditingController _company = TextEditingController(
    text: widget.gst.company,
  );

  @override
  void dispose() {
    _gstin.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _gstin,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          maxLength: 15,
          decoration: InputDecoration(
            labelText: l10n.text(CustomerStrings.gstGstin),
            hintText: '29ABCDE1234F1Z5',
            counterText: '',
            errorText: widget.showGstinError
                ? l10n.text(CustomerStrings.gstGstinError)
                : null,
          ),
          onChanged: (value) =>
              widget.onChanged(widget.gst.copyWith(gstin: value)),
        ),
        const SizedBox(height: AbraSpacing.md),
        TextField(
          controller: _company,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.text(CustomerStrings.gstCompany),
            errorText: widget.showCompanyError
                ? l10n.text(CustomerStrings.gstCompanyError)
                : null,
          ),
          onChanged: (value) =>
              widget.onChanged(widget.gst.copyWith(company: value)),
        ),
      ],
    );
  }
}
