import '../models/payment_models.dart';
import 'payment_repository.dart';

/// Pretends to pay. It succeeds, unless the customer uses a test value:
///
/// - UPI id `fail@upi`, or card `4000 0000 0000 0002`: the bank declines
///   (the "Payment failed" screen);
/// - UPI id `timeout@upi`, or card `4000 0000 0000 0036`: no confirmation
///   arrives (the "seats released" screen).
class MockPaymentRepository implements PaymentRepository {
  const MockPaymentRepository({this.delay = const Duration(seconds: 4)});

  final Duration delay;

  @override
  Future<PaymentResult> pay({
    required String bookingId,
    required int amountPaise,
    required PaymentInstrument instrument,
  }) async {
    await Future<void>.delayed(delay);
    final id = instrument.upiId?.trim().toLowerCase();
    final card = instrument.cardNumber?.replaceAll(RegExp(r'\D'), '');
    if (id == 'timeout@upi' || card == '4000000000000036') {
      return const PaymentResult.timeout();
    }
    if (id == 'fail@upi' || card == '4000000000000002') {
      return const PaymentResult.failed(
        failureCode: 'U30',
        reference: 'TXN28104471',
      );
    }
    return PaymentResult.success(bookingId: bookingId);
  }
}
