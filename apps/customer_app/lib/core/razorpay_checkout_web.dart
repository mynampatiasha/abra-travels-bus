import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'razorpay_checkout_types.dart';

RazorpayCheckout createRazorpayCheckout() => _WebCheckout();

@JS('Razorpay')
extension type _RazorpayJs._(JSObject _) implements JSObject {
  external factory _RazorpayJs(JSObject options);

  external void open();
  external void on(String event, JSFunction handler);
}

/// Razorpay's own pay screen in the browser (checkout.js, loaded in web/index.html).
class _WebCheckout implements RazorpayCheckout {
  @override
  Future<RazorpayOutcome> open(RazorpayRequest request) {
    final done = Completer<RazorpayOutcome>();
    void finish(RazorpayOutcome outcome) {
      if (!done.isCompleted) done.complete(outcome);
    }

    if (!globalContext.has('Razorpay')) {
      return Future<RazorpayOutcome>.value(const RazorpayFailed('CHECKOUT_NOT_AVAILABLE'));
    }

    final prefill = JSObject();
    if (request.contact != null) prefill['contact'] = request.contact!.toJS;
    if (request.email != null) prefill['email'] = request.email!.toJS;
    final theme = JSObject()..['color'] = '#1677C8'.toJS;
    final modal = JSObject()..['ondismiss'] = (() => finish(const RazorpayClosed())).toJS;

    final options = JSObject()
      ..['key'] = request.keyId.toJS
      ..['order_id'] = request.orderId.toJS
      ..['amount'] = request.amountPaise.toJS
      ..['currency'] = 'INR'.toJS
      ..['name'] = request.name.toJS
      ..['description'] = request.description.toJS
      ..['prefill'] = prefill
      ..['theme'] = theme
      ..['modal'] = modal
      ..['handler'] = ((JSObject response) {
        String text(String key) => (response[key] as JSString?)?.toDart ?? '';
        finish(
          RazorpayPaid(
            paymentId: text('razorpay_payment_id'),
            orderId: text('razorpay_order_id'),
            signature: text('razorpay_signature'),
          ),
        );
      }).toJS;
    try {
      final checkout = _RazorpayJs(options);
      checkout.on(
        'payment.failed',
        ((JSObject response) {
          final error = response['error'] as JSObject?;
          final code = (error?['code'] as JSString?)?.toDart ?? 'PAYMENT_FAILED';
          finish(RazorpayFailed(code));
        }).toJS,
      );
      checkout.open();
    } on Object {
      finish(const RazorpayFailed('CHECKOUT_NOT_AVAILABLE'));
    }
    return done.future;
  }
}
