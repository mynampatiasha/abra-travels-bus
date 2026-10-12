import 'package:meta/meta.dart';

enum Gender {
  male('M'),
  female('F'),
  other('O');

  const Gender(this.wireValue);

  final String wireValue;
}

/// One traveller, as typed into the passenger card of a seat.
@immutable
final class PassengerEntry {
  const PassengerEntry({this.name = '', this.age = '', this.gender});

  final String name;

  /// As typed; checked by `BookingValidation`.
  final String age;
  final Gender? gender;

  PassengerEntry copyWith({String? name, String? age, Gender? gender}) =>
      PassengerEntry(
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
      );
}

/// Where the ticket and trip updates are sent.
@immutable
final class ContactEntry {
  const ContactEntry({this.mobile = '', this.email = ''});

  /// Ten digits, without country code or spaces once cleaned.
  final String mobile;
  final String email;

  ContactEntry copyWith({String? mobile, String? email}) =>
      ContactEntry(mobile: mobile ?? this.mobile, email: email ?? this.email);
}

/// Optional business details for a GST invoice.
@immutable
final class GstEntry {
  const GstEntry({this.enabled = false, this.gstin = '', this.company = ''});

  final bool enabled;
  final String gstin;
  final String company;

  GstEntry copyWith({bool? enabled, String? gstin, String? company}) =>
      GstEntry(
        enabled: enabled ?? this.enabled,
        gstin: gstin ?? this.gstin,
        company: company ?? this.company,
      );
}

/// What went wrong in one passenger card.
@immutable
final class PassengerErrors {
  const PassengerErrors({
    this.name = false,
    this.age = false,
    this.gender = false,
    this.ladiesOnlyViolation = false,
  });

  final bool name;
  final bool age;

  /// No gender chosen.
  final bool gender;

  /// A ladies-only seat with a passenger who is not female.
  final bool ladiesOnlyViolation;

  bool get hasAny => name || age || gender || ladiesOnlyViolation;
}

/// The result of checking the whole passenger form.
@immutable
final class BookingFormErrors {
  const BookingFormErrors({
    required this.passengers,
    this.mobile = false,
    this.email = false,
    this.gstin = false,
    this.company = false,
  });

  /// By seat id.
  final Map<String, PassengerErrors> passengers;
  final bool mobile;
  final bool email;
  final bool gstin;
  final bool company;

  bool get hasAny =>
      mobile ||
      email ||
      gstin ||
      company ||
      passengers.values.any((errors) => errors.hasAny);

  PassengerErrors forSeat(String seatId) =>
      passengers[seatId] ?? const PassengerErrors();

  static const none = BookingFormErrors(
    passengers: <String, PassengerErrors>{},
  );
}

/// The coupon box of the review step.
enum CouponStatus { none, applied, invalid }

@immutable
final class CouponState {
  const CouponState({
    this.status = CouponStatus.none,
    this.code = '',
    this.discountPaise = 0,
  });

  final CouponStatus status;
  final String code;
  final int discountPaise;

  bool get isApplied => status == CouponStatus.applied;
}

/// What the backend says about a coupon code.
@immutable
final class CouponResult {
  const CouponResult.valid({required this.code, required this.discountPaise})
    : isValid = true;

  const CouponResult.invalid(this.code) : isValid = false, discountPaise = 0;

  final String code;
  final bool isValid;
  final int discountPaise;
}

/// The amounts of a booking, all in paise.
@immutable
final class FareBreakup {
  const FareBreakup({
    required this.basePaise,
    required this.gstPaise,
    required this.convenienceFeePaise,
    required this.discountPaise,
  });

  final int basePaise;
  final int gstPaise;
  final int convenienceFeePaise;
  final int discountPaise;

  int get totalPaise =>
      basePaise + gstPaise + convenienceFeePaise - discountPaise;
}

/// One line of the cancellation policy: cancelling at least [hoursBefore]
/// hours before departure refunds [refundPercent] percent.
@immutable
final class CancellationRule {
  const CancellationRule({
    required this.fromHoursBefore,
    required this.toHoursBefore,
    required this.refundPercent,
  });

  /// Window start, in hours before departure (`null` = no upper limit).
  final int? fromHoursBefore;

  /// Window end, in hours before departure (0 = at departure).
  final int toHoursBefore;
  final int refundPercent;
}

/// Seats held for the customer until [expiresAt] (`POST /trips/:id/seat-locks`).
@immutable
final class SeatLock {
  const SeatLock({required this.lockId, required this.expiresAt});

  final String lockId;
  final DateTime expiresAt;
}
