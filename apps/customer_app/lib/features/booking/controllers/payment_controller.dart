import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/payment_models.dart';
import '../models/ticket_models.dart';
import '../repositories/booking_repository.dart';
import '../repositories/payment_repository.dart';
import 'payment_validation.dart';
import 'seat_hold_controller.dart';

enum PaymentPhase { idle, processing, failed }

/// What the customer has chosen and typed to pay, and where the payment is.
/// Lives only while the payment screen is open (never stored, never logged:
/// there is deliberately no `toString`).
@immutable
class PaymentState {
  const PaymentState({
    this.method = PaymentMethod.upi,
    this.upiApp,
    this.upiId = '',
    this.cardNumber = '',
    this.cardExpiry = '',
    this.cardCvv = '',
    this.cardName = '',
    this.bank,
    this.wallet,
    this.phase = PaymentPhase.idle,
    this.failureCode,
    this.reference,
    this.bookingId,
  });

  final PaymentMethod method;
  final UpiApp? upiApp;
  final String upiId;
  final String cardNumber;
  final String cardExpiry;
  final String cardCvv;
  final String cardName;
  final Bank? bank;
  final WalletProvider? wallet;
  final PaymentPhase phase;
  final String? failureCode;
  final String? reference;

  /// The booking created for this payment, kept so that a retry pays for
  /// the same booking instead of creating another.
  final String? bookingId;

  /// The instrument for the chosen method, or null while it is not complete
  /// (the "Pay" button stays off).
  PaymentInstrument? instrumentAt(DateTime now) => switch (method) {
    PaymentMethod.upi =>
      PaymentValidation.isValidUpiId(upiId)
          ? PaymentInstrument.upi(upiId: upiId.trim())
          : upiApp != null
          ? PaymentInstrument.upi(upiApp: upiApp)
          : null,
    PaymentMethod.card =>
      PaymentValidation.isValidCardNumber(cardNumber) &&
              PaymentValidation.isValidExpiry(cardExpiry, now) &&
              PaymentValidation.isValidCvv(cardCvv) &&
              PaymentValidation.isValidCardName(cardName)
          ? PaymentInstrument.card(cardNumber: cardNumber)
          : null,
    PaymentMethod.netBanking =>
      bank == null ? null : PaymentInstrument.netBanking(bank: bank!),
    PaymentMethod.wallet =>
      wallet == null ? null : PaymentInstrument.wallet(wallet: wallet!),
  };

  PaymentState copyWith({
    PaymentMethod? method,
    UpiApp? Function()? upiApp,
    String? upiId,
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? cardName,
    Bank? bank,
    WalletProvider? wallet,
    PaymentPhase? phase,
    String? failureCode,
    String? reference,
    String? bookingId,
  }) => PaymentState(
    method: method ?? this.method,
    upiApp: upiApp == null ? this.upiApp : upiApp(),
    upiId: upiId ?? this.upiId,
    cardNumber: cardNumber ?? this.cardNumber,
    cardExpiry: cardExpiry ?? this.cardExpiry,
    cardCvv: cardCvv ?? this.cardCvv,
    cardName: cardName ?? this.cardName,
    bank: bank ?? this.bank,
    wallet: wallet ?? this.wallet,
    phase: phase ?? this.phase,
    failureCode: failureCode ?? this.failureCode,
    reference: reference ?? this.reference,
    bookingId: bookingId ?? this.bookingId,
  );
}

/// The payment of the booking of [tripId]. Dropped when the screen closes,
/// which also drops the card details.
final paymentProvider = NotifierProvider.autoDispose
    .family<PaymentController, PaymentState, String>(PaymentController.new);

class PaymentController extends Notifier<PaymentState> {
  PaymentController(this.tripId);

  final String tripId;

  @override
  PaymentState build() => const PaymentState();

  void selectMethod(PaymentMethod method) =>
      state = state.copyWith(method: method);

  void setUpiApp(UpiApp? app) => state = state.copyWith(upiApp: () => app);
  void setUpiId(String value) => state = state.copyWith(upiId: value);
  void setCardNumber(String value) => state = state.copyWith(cardNumber: value);
  void setCardExpiry(String value) => state = state.copyWith(cardExpiry: value);
  void setCardCvv(String value) => state = state.copyWith(cardCvv: value);
  void setCardName(String value) => state = state.copyWith(cardName: value);
  void setBank(Bank bank) => state = state.copyWith(bank: bank);
  void setWallet(WalletProvider wallet) =>
      state = state.copyWith(wallet: wallet);

  /// Back to choosing, with cards offered (after a failed payment).
  void changeMethod() => state = PaymentState(
    method: PaymentMethod.card,
    phase: PaymentPhase.idle,
    upiApp: state.upiApp,
    upiId: state.upiId,
    bank: state.bank,
    wallet: state.wallet,
    bookingId: state.bookingId,
  );

  /// Pays [amountPaise] with what is chosen. Returns the result so the
  /// screen can go on (success, or the hold ran out); a declined payment
  /// also puts the state in [PaymentPhase.failed].
  Future<PaymentResult?> pay({
    required BookingRequest request,
    required int amountPaise,
    required DateTime now,
  }) async {
    final instrument = state.instrumentAt(now);
    final hold = ref.read(seatHoldProvider(tripId));
    if (instrument == null ||
        hold == null ||
        hold.released ||
        state.phase == PaymentPhase.processing) {
      return null;
    }
    state = state.copyWith(phase: PaymentPhase.processing);
    PaymentResult result;
    try {
      var bookingId = state.bookingId;
      if (bookingId == null) {
        final created = await ref
            .read(bookingRepositoryProvider)
            .createBooking(request);
        bookingId = created.bookingId;
        state = state.copyWith(bookingId: bookingId);
      }
      result = await ref
          .read(paymentRepositoryProvider)
          .pay(
            bookingId: bookingId,
            amountPaise: amountPaise,
            instrument: instrument,
          );
    } on SeatsUnavailableException {
      // The hold was lost before the booking could be made: nothing was
      // charged and the seats are gone.
      result = const PaymentResult.timeout();
    } on Object {
      result = const PaymentResult.failed(
        failureCode: networkFailureCode,
        reference: '',
      );
    }
    switch (result.outcome) {
      case PaymentOutcome.failed:
        state = state.copyWith(
          phase: PaymentPhase.failed,
          failureCode: result.failureCode,
          reference: result.reference,
        );
      case PaymentOutcome.success:
      case PaymentOutcome.timeout:
        state = state.copyWith(phase: PaymentPhase.idle);
    }
    return result;
  }

  /// The failure code used when the payment could not be tried at all.
  static const networkFailureCode = 'NETWORK';
}

/// Seconds left on the hold of [tripId], once a second.
final holdSecondsProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  tripId,
) {
  final clock = ref.read(bookingClockProvider);
  final controller = StreamController<int>();
  void emit() => controller.add(
    ref.read(seatHoldProvider(tripId))?.secondsLeft(clock()) ?? 0,
  );
  emit();
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => emit());
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
