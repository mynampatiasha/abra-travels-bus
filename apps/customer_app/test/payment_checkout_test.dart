import 'package:customer_app/core/razorpay_checkout.dart';
import 'package:customer_app/features/booking/models/payment_models.dart';
import 'package:customer_app/features/booking/repositories/payment_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';

/// A signed-in customer: a token that is always good.
class _SignedIn implements AuthTokenSource {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> refreshAccessToken() async => true;

  @override
  Future<void> onSessionRejected() async {}
}

/// Answers the checkout with a chosen outcome and keeps what it was asked.
class _FakeCheckout implements RazorpayCheckout {
  _FakeCheckout(this.outcome);

  final RazorpayOutcome outcome;
  RazorpayRequest? asked;

  @override
  Future<RazorpayOutcome> open(RazorpayRequest request) async {
    asked = request;
    return outcome;
  }
}

Map<String, Object?> orderJson({String keyId = 'rzp_test_abcdef12'}) => <String, Object?>{
  'paymentId': 'p1',
  'gatewayOrderId': 'order_1',
  'keyId': keyId,
  'amountPaise': 94150,
};

({ApiPaymentRepository repository, FakeHttpAdapter adapter}) build({
  required RazorpayCheckout checkout,
  String keyId = 'rzp_test_abcdef12',
  Map<String, FakeResponse> extra = const <String, FakeResponse>{},
}) {
  final adapter = FakeHttpAdapter((request) async {
    final key = '${request.options.method} ${request.path}';
    if (extra.containsKey(key)) return extra[key]!;
    if (key == 'POST payments/orders') return FakeResponse.ok(orderJson(keyId: keyId));
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  });
  final client = ApiClient(
    config: AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.customer,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
    ),
    dio: Dio()..httpClientAdapter = adapter,
    logger: MemoryLogger(),
    languageTag: () => 'en',
  )..attachTokenSource(_SignedIn());
  return (repository: ApiPaymentRepository(client, checkout: checkout), adapter: adapter);
}

Future<PaymentResult> pay(ApiPaymentRepository repository) => repository.pay(
  bookingId: 'bk1',
  amountPaise: 94150,
  instrument: const PaymentInstrument.upi(),
);

void main() {
  group('paying through the Razorpay pay screen', () {
    test('opens the pay screen for the order with its exact amount, and the booking is confirmed from the signature', () async {
      final checkout = _FakeCheckout(const RazorpayPaid(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1'));
      final built = build(
        checkout: checkout,
        extra: <String, FakeResponse>{
          'POST payments/p1/client-callback': FakeResponse.ok(<String, Object?>{
            'paymentId': 'p1',
            'status': 'SUCCESS',
            'bookingStatus': 'CONFIRMED',
            'refundDue': false,
            'refundedPaise': 0,
          }),
        },
      );
      final result = await pay(built.repository);

      expect(checkout.asked?.keyId, 'rzp_test_abcdef12');
      expect(checkout.asked?.orderId, 'order_1');
      expect(checkout.asked?.amountPaise, 94150);
      expect(checkout.asked?.name, 'Abra Travels');
      expect(result.outcome, PaymentOutcome.success);
      expect(result.bookingId, 'bk1');
      final callback = built.adapter.requests.last;
      expect(callback.path, 'payments/p1/client-callback');
      expect(callback.body, <String, Object?>{'gatewayPaymentId': 'pay_1', 'signature': 'sig_1'});
    });

    test('closing the pay screen tells the backend and shows a cancelled payment', () async {
      final built = build(
        checkout: _FakeCheckout(const RazorpayClosed()),
        extra: <String, FakeResponse>{'POST payments/p1/failed': FakeResponse.ok(<String, Object?>{})},
      );
      final result = await pay(built.repository);
      expect(result.outcome, PaymentOutcome.failed);
      expect(result.failureCode, 'CANCELLED');
      expect(result.reference, 'order_1');
      final sent = built.adapter.requests.last;
      expect(sent.path, 'payments/p1/failed');
      expect(sent.body, <String, Object?>{'reason': 'CANCELLED'});
    });

    test('a declined payment is a failure with its reason, even when telling the backend fails', () async {
      final built = build(checkout: _FakeCheckout(const RazorpayFailed('BAD_REQUEST_ERROR')));
      final result = await pay(built.repository);
      expect(result.outcome, PaymentOutcome.failed);
      expect(result.failureCode, 'BAD_REQUEST_ERROR');
    });

    test('a pay screen that cannot open fails cleanly, and the backend gives the seats back', () async {
      final built = build(
        checkout: _FakeCheckout(const RazorpayFailed('CHECKOUT_NOT_AVAILABLE')),
        extra: <String, FakeResponse>{'POST payments/p1/failed': FakeResponse.ok(<String, Object?>{})},
      );
      final result = await pay(built.repository);
      expect(result.failureCode, 'CHECKOUT_NOT_AVAILABLE');
      expect(built.adapter.requests.last.path, 'payments/p1/failed');
    });

    test('money taken but the seats lost is a timeout, so the screen says the refund is coming', () async {
      final built = build(
        checkout: _FakeCheckout(const RazorpayPaid(paymentId: 'pay_2', orderId: 'order_1', signature: 's')),
        extra: <String, FakeResponse>{
          'POST payments/p1/client-callback': FakeResponse.ok(<String, Object?>{
            'paymentId': 'p1',
            'status': 'SUCCESS',
            'bookingStatus': 'EXPIRED',
            'refundDue': true,
            'refundedPaise': 94150,
          }),
        },
      );
      expect((await pay(built.repository)).outcome, PaymentOutcome.timeout);
    });

    test('the test gateway never opens a pay screen', () async {
      final checkout = _FakeCheckout(const RazorpayClosed());
      final built = build(
        checkout: checkout,
        keyId: 'development',
        extra: <String, FakeResponse>{
          'POST payments/p1/dev-complete': FakeResponse.ok(<String, Object?>{
            'paymentId': 'p1',
            'status': 'SUCCESS',
            'bookingStatus': 'CONFIRMED',
            'refundDue': false,
            'refundedPaise': 0,
          }),
        },
      );
      final result = await pay(built.repository);
      expect(result.outcome, PaymentOutcome.success);
      expect(checkout.asked, isNull);
    });
  });

  group('a link for someone else to pay', () {
    test('makes the order if needed, asks for the link, and returns its address', () async {
      final built = build(
        checkout: _FakeCheckout(const RazorpayClosed()),
        extra: <String, FakeResponse>{
          'POST payments/p1/share-link': FakeResponse.ok(<String, Object?>{
            'paymentId': 'p1',
            'url': 'https://rzp.io/i/abc123',
            'amountPaise': 94150,
            'currency': 'INR',
            'expiresAt': '2026-11-01T10:00:00.000Z',
          }),
        },
      );
      final url = await built.repository.createShareLink(bookingId: 'bk1');
      expect(url, 'https://rzp.io/i/abc123');
      expect(built.adapter.requests.map((r) => r.path), <String>['payments/orders', 'payments/p1/share-link']);
      expect(built.adapter.requests.first.body, <String, Object?>{'bookingId': 'bk1'});
    });

    test('a refused link is an error the screen can show, not a silent nothing', () async {
      final built = build(
        checkout: _FakeCheckout(const RazorpayClosed()),
        extra: <String, FakeResponse>{'POST payments/p1/share-link': FakeResponse.error(409, 'INVALID_STATE_TRANSITION')},
      );
      await expectLater(built.repository.createShareLink(bookingId: 'bk1'), throwsA(isA<AppException>()));
    });
  });
}
