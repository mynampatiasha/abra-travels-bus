import 'package:meta/meta.dart';

/// The four ways to pay.
enum PaymentMethod { upi, card, netBanking, wallet }

/// UPI apps offered as buttons.
enum UpiApp { gpay, phonepe, paytm, bhim }

enum Bank { sbi, hdfc, icici, axis, kotak }

enum WalletProvider { paytm, phonepe, amazonPay }

/// How the customer chose to pay. Holds what the payment partner needs for
/// this one payment and is never stored or logged. Card details are passed
/// through only; a production build hands them to the payment partner's SDK
/// and never touches them (see the README).
@immutable
final class PaymentInstrument {
  const PaymentInstrument.upi({this.upiApp, this.upiId})
    : method = PaymentMethod.upi,
      cardNumber = null,
      bank = null,
      wallet = null;

  const PaymentInstrument.card({required String this.cardNumber})
    : method = PaymentMethod.card,
      upiApp = null,
      upiId = null,
      bank = null,
      wallet = null;

  const PaymentInstrument.netBanking({required Bank this.bank})
    : method = PaymentMethod.netBanking,
      upiApp = null,
      upiId = null,
      cardNumber = null,
      wallet = null;

  const PaymentInstrument.wallet({required WalletProvider this.wallet})
    : method = PaymentMethod.wallet,
      upiApp = null,
      upiId = null,
      cardNumber = null,
      bank = null;

  final PaymentMethod method;
  final UpiApp? upiApp;
  final String? upiId;
  final String? cardNumber;
  final Bank? bank;
  final WalletProvider? wallet;
}

enum PaymentOutcome { success, failed, timeout }

/// What the payment partner and the backend answered.
@immutable
final class PaymentResult {
  const PaymentResult.success({required String this.bookingId})
    : outcome = PaymentOutcome.success,
      failureCode = null,
      reference = null;

  const PaymentResult.failed({
    required String this.failureCode,
    required String this.reference,
  }) : outcome = PaymentOutcome.failed,
       bookingId = null;

  /// The confirmation did not arrive in time: the seats are let go and no
  /// money is taken.
  const PaymentResult.timeout()
    : outcome = PaymentOutcome.timeout,
      bookingId = null,
      failureCode = null,
      reference = null;

  final PaymentOutcome outcome;
  final String? bookingId;
  final String? failureCode;

  /// The partner's reference, shown with a failure ("TXN28104471").
  final String? reference;
}
