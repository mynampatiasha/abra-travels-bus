import '../models/booking_models.dart';
import '../models/seat_models.dart';

/// Checks of the passenger form, without any widget so they can be tested on
/// their own.
abstract final class BookingValidation {
  static final RegExp _email = RegExp(r'^\S+@\S+\.\S+$');
  static final RegExp _gstin = RegExp(
    r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  );

  /// Digits only: "98765 43210" → "9876543210", "+91 98765 43210" → the
  /// same (a country code in front is dropped).
  static String cleanMobile(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
  }

  static bool isValidMobile(String input) {
    final digits = cleanMobile(input);
    return digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits);
  }

  static bool isValidEmail(String input) => _email.hasMatch(input.trim());

  static bool isValidAge(String input) {
    final age = int.tryParse(input.trim());
    return age != null && age >= 1 && age <= 99;
  }

  static bool isValidGstin(String input) =>
      _gstin.hasMatch(input.trim().toUpperCase());

  /// Checks every passenger, the contact and, when switched on, the GST
  /// details. [seats] are the chosen seats in order; [passengers] is by seat
  /// id. A ladies-only seat accepts a female passenger only.
  static BookingFormErrors check({
    required List<Seat> seats,
    required Map<String, PassengerEntry> passengers,
    required ContactEntry contact,
    required GstEntry gst,
  }) {
    final errors = <String, PassengerErrors>{};
    for (final seat in seats) {
      final entry = passengers[seat.id] ?? const PassengerEntry();
      final gender = entry.gender;
      errors[seat.id] = PassengerErrors(
        name: entry.name.trim().isEmpty,
        age: !isValidAge(entry.age),
        gender: gender == null,
        ladiesOnlyViolation:
            seat.status == SeatStatus.ladiesOnly &&
            gender != null &&
            gender != Gender.female,
      );
    }
    return BookingFormErrors(
      passengers: errors,
      mobile: !isValidMobile(contact.mobile),
      email: !isValidEmail(contact.email),
      // Optional: checked only when something is entered.
      gstin:
          gst.enabled &&
          gst.gstin.trim().isNotEmpty &&
          !isValidGstin(gst.gstin),
      company:
          gst.enabled &&
          gst.gstin.trim().isNotEmpty &&
          gst.company.trim().isEmpty,
    );
  }
}
