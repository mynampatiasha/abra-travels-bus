import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../models/payment_models.dart';

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

/// Backend: `POST /payments/orders`, then the payment is taken and reported.
/// With the development gateway (local work only) the backend finishes the
/// test payment itself. The Razorpay checkout needs its own SDK and is not
/// opened from here yet: a real order answers with a failure the screen
/// shows, and the seats are let go.
class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final ApiClient _client;

  @override
  Future<PaymentResult> pay({
    required String bookingId,
    required int amountPaise,
    required PaymentInstrument instrument,
  }) async {
    final order = (await _client.post(
      'payments/orders',
      body: <String, Object?>{'bookingId': bookingId},
    )).decodeObject(paymentOrderFromJson);

    if (order.keyId != 'development') {
      await _client.post(
        'payments/${order.paymentId}/failed',
        body: const <String, Object?>{'reason': 'CHECKOUT_NOT_AVAILABLE'},
      );
      return PaymentResult.failed(
        failureCode: 'CHECKOUT_NOT_AVAILABLE',
        reference: order.gatewayOrderId,
      );
    }
    final done = (await _client.post(
      'payments/${order.paymentId}/dev-complete',
      body: const <String, Object?>{'outcome': 'success'},
    )).decodeObject(paymentResultFromJson);
    return paymentOutcomeOf(done, bookingId: bookingId, reference: order.gatewayOrderId);
  }
}

/// The order to pay, as the backend sends it.
class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.gatewayOrderId,
    required this.keyId,
  });

  final String paymentId;
  final String gatewayOrderId;
  final String keyId;
}

PaymentOrder paymentOrderFromJson(JsonMap json) => PaymentOrder(
  paymentId: '${json['paymentId']}',
  gatewayOrderId: '${json['gatewayOrderId']}',
  keyId: '${json['keyId']}',
);

/// What the backend says happened to a payment.
class PaymentReport {
  const PaymentReport({
    required this.status,
    required this.bookingStatus,
    required this.refundDue,
  });

  final String status;
  final String bookingStatus;
  final bool refundDue;
}

PaymentReport paymentResultFromJson(JsonMap json) => PaymentReport(
  status: '${json['status']}',
  bookingStatus: '${json['bookingStatus']}',
  refundDue: json['refundDue'] == true,
);

/// A confirmed booking is a success. Seats lost after paying are a timeout
/// (the money comes back); anything else is a failure with its reference.
PaymentResult paymentOutcomeOf(
  PaymentReport report, {
  required String bookingId,
  required String reference,
}) {
  if (report.status == 'SUCCESS' && report.bookingStatus == 'CONFIRMED') {
    return PaymentResult.success(bookingId: bookingId);
  }
  if (report.refundDue) return const PaymentResult.timeout();
  return PaymentResult.failed(failureCode: 'PAYMENT_FAILED', reference: reference);
}

/// Not connected yet - built in Phase 3.
class NotConnectedPaymentRepository implements PaymentRepository {
  const NotConnectedPaymentRepository();

  @override
  Future<PaymentResult> pay({
    required String bookingId,
    required int amountPaise,
    required PaymentInstrument instrument,
  }) async =>
      const PaymentResult.failed(
        failureCode: 'NOT_CONNECTED',
        reference: 'REF-PHASE-3',
      );
}

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => ApiPaymentRepository(ref.watch(appDependenciesProvider).apiClient),
);
