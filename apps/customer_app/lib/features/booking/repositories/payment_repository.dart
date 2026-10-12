import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_models.dart';
import 'mock_payment_repository.dart';

/// Pays for a booking. Screens depend on this interface only; the backend
/// replaces [MockPaymentRepository] by providing [ApiPaymentRepository].
abstract interface class PaymentRepository {
  /// Creates the payment order for [bookingId] and takes the payment with
  /// [instrument] (`POST /payments/orders`, then the payment partner's SDK). Never throws for a declined payment: that is a
  /// [PaymentResult.failed]. Throws only when the backend cannot be reached.
  Future<PaymentResult> pay({
    required String bookingId,
    required int amountPaise,
    required PaymentInstrument instrument,
  });
}

/// Backend implementation. Not connected yet; see the README table.
class ApiPaymentRepository implements PaymentRepository {
  @override
  Future<PaymentResult> pay({
    required String bookingId,
    required int amountPaise,
    required PaymentInstrument instrument,
  }) => throw UnimplementedError('POST /payments/orders');
}

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => const MockPaymentRepository(),
);
