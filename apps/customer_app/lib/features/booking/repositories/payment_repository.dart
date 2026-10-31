import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../../../core/razorpay_checkout.dart';
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

  /// A link that anyone can open to pay [bookingId], to share by WhatsApp or any app
  /// (`POST /payments/orders`, then `POST /payments/:id/share-link`). One link for each payment.
  Future<String> createShareLink({required String bookingId});
}

/// Backend: `POST /payments/orders`, then the payment is taken and reported.
/// With the development gateway (local work only) the backend finishes the test payment itself.
/// With Razorpay the Razorpay pay screen opens for the order (UPI apps and QR, cards, net banking);
/// when it ends paid, its signature goes to our backend, which checks it and confirms the
/// booking. A closed or declined pay screen tells the backend, which gives the seats back.
class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client, {RazorpayCheckout? checkout})
    : _checkout = checkout ?? defaultRazorpayCheckout();

  final ApiClient _client;
  final RazorpayCheckout _checkout;

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

    if (order.keyId == 'development') {
      final done = (await _client.post(
        'payments/${order.paymentId}/dev-complete',
        body: const <String, Object?>{'outcome': 'success'},
      )).decodeObject(paymentResultFromJson);
      return paymentOutcomeOf(done, bookingId: bookingId, reference: order.gatewayOrderId);
    }

    final outcome = await _checkout.open(
      RazorpayRequest(
        keyId: order.keyId,
        orderId: order.gatewayOrderId,
        amountPaise: order.amountPaise > 0 ? order.amountPaise : amountPaise,
        name: 'Abra Travels',
        description: 'Bus ticket',
      ),
    );
    switch (outcome) {
      case RazorpayPaid(:final paymentId, :final signature):
        final report = (await _client.post(
          'payments/${order.paymentId}/client-callback',
          body: <String, Object?>{'gatewayPaymentId': paymentId, 'signature': signature},
        )).decodeObject(paymentResultFromJson);
        return paymentOutcomeOf(report, bookingId: bookingId, reference: paymentId);
      case RazorpayClosed():
        return _failed(order, 'CANCELLED');
      case RazorpayFailed(:final reason):
        return _failed(order, reason);
    }
  }

  @override
  Future<String> createShareLink({required String bookingId}) async {
    final order = (await _client.post(
      'payments/orders',
      body: <String, Object?>{'bookingId': bookingId},
    )).decodeObject(paymentOrderFromJson);
    final link = await _client.post('payments/${order.paymentId}/share-link');
    return link.decodeObject(shareLinkFromJson);
  }

  /// Tells the backend the payment did not happen (it gives back the seats and the coupon), and
  /// answers the screen with the reason. A failed call here changes nothing for the customer.
  Future<PaymentResult> _failed(PaymentOrder order, String reason) async {
    try {
      await _client.post(
        'payments/${order.paymentId}/failed',
        body: <String, Object?>{'reason': reason},
      );
    } on Object {
      // The hold runs out by itself
    }
    return PaymentResult.failed(failureCode: reason, reference: order.gatewayOrderId);
  }
}

/// The address of the link made for someone else to pay.
String shareLinkFromJson(JsonMap json) => '${json['url']}';

/// The order to pay, as the backend sends it.
class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.gatewayOrderId,
    required this.keyId,
    this.amountPaise = 0,
  });

  final int amountPaise;

  final String paymentId;
  final String gatewayOrderId;
  final String keyId;
}

PaymentOrder paymentOrderFromJson(JsonMap json) => PaymentOrder(
  paymentId: '${json['paymentId']}',
  gatewayOrderId: '${json['gatewayOrderId']}',
  keyId: '${json['keyId']}',
  amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
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
  Future<String> createShareLink({required String bookingId}) async =>
      throw StateError('Not connected yet - built in Phase 3');

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
