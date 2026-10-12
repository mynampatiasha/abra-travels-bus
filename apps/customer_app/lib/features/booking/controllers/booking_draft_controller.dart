import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

import '../models/booking_models.dart';
import 'booking_validation.dart';

/// What the customer has typed for one booking, kept while the booking is in
/// progress (not on the device: it holds names and contact details).
@immutable
class BookingDraft {
  const BookingDraft({
    this.passengers = const <String, PassengerEntry>{},
    this.contact = const ContactEntry(),
    this.gst = const GstEntry(),
    this.usesProfile = false,
    this.fillVersion = 0,
    this.showErrors = false,
    this.coupon = const CouponState(),
    this.termsAccepted = false,
  });

  /// By seat id.
  final Map<String, PassengerEntry> passengers;
  final ContactEntry contact;
  final GstEntry gst;

  /// "Use my profile" is on.
  final bool usesProfile;

  /// Grows whenever the fields are filled from outside (the profile), so
  /// text fields start again from the new values.
  final int fillVersion;

  /// Set after a failed "Continue": every field now shows its error.
  final bool showErrors;
  final CouponState coupon;
  final bool termsAccepted;

  PassengerEntry passengerFor(String seatId) =>
      passengers[seatId] ?? const PassengerEntry();

  BookingDraft copyWith({
    Map<String, PassengerEntry>? passengers,
    ContactEntry? contact,
    GstEntry? gst,
    bool? usesProfile,
    int? fillVersion,
    bool? showErrors,
    CouponState? coupon,
    bool? termsAccepted,
  }) => BookingDraft(
    passengers: passengers ?? this.passengers,
    contact: contact ?? this.contact,
    gst: gst ?? this.gst,
    usesProfile: usesProfile ?? this.usesProfile,
    fillVersion: fillVersion ?? this.fillVersion,
    showErrors: showErrors ?? this.showErrors,
    coupon: coupon ?? this.coupon,
    termsAccepted: termsAccepted ?? this.termsAccepted,
  );
}

/// The draft of the booking of [tripId].
final bookingDraftProvider =
    NotifierProvider.family<BookingDraftController, BookingDraft, String>(
      BookingDraftController.new,
    );

class BookingDraftController extends Notifier<BookingDraft> {
  BookingDraftController(this.tripId);

  final String tripId;

  @override
  BookingDraft build() => const BookingDraft();

  void setPassenger(String seatId, PassengerEntry entry) =>
      state = state.copyWith(
        passengers: <String, PassengerEntry>{
          ...state.passengers,
          seatId: entry,
        },
      );

  void setContact(ContactEntry contact) =>
      state = state.copyWith(contact: contact);

  void setGst(GstEntry gst) => state = state.copyWith(gst: gst);

  void setTermsAccepted(bool accepted) =>
      state = state.copyWith(termsAccepted: accepted);

  void setCoupon(CouponState coupon) => state = state.copyWith(coupon: coupon);

  void showErrors() => state = state.copyWith(showErrors: true);

  /// "Use my profile": on fills the name of the first passenger and the
  /// contact details from [profile]; off clears what it filled. The profile
  /// has no age or gender, so those stay for the customer to enter.
  void useProfile({
    required bool enabled,
    required UserProfile? profile,
    required String? firstSeatId,
  }) {
    if (!enabled) {
      state = state.copyWith(
        usesProfile: false,
        passengers: firstSeatId == null
            ? state.passengers
            : <String, PassengerEntry>{
                ...state.passengers,
                firstSeatId: state.passengerFor(firstSeatId).copyWith(name: ''),
              },
        contact: const ContactEntry(),
        fillVersion: state.fillVersion + 1,
      );
      return;
    }
    state = state.copyWith(
      usesProfile: true,
      passengers: firstSeatId == null
          ? state.passengers
          : <String, PassengerEntry>{
              ...state.passengers,
              firstSeatId: state
                  .passengerFor(firstSeatId)
                  .copyWith(name: profile?.name ?? ''),
            },
      contact: ContactEntry(
        mobile: BookingValidation.cleanMobile(profile?.phone ?? ''),
        email: profile?.email ?? '',
      ),
      fillVersion: state.fillVersion + 1,
    );
  }

  void reset() => state = const BookingDraft();
}

/// The coupon discount of the booking of a trip, in paise (0 without one).
final couponDiscountProvider = Provider.family<int, String>(
  (ref, tripId) => ref.watch(
    bookingDraftProvider(tripId).select((d) => d.coupon.discountPaise),
  ),
);
