import 'razorpay_checkout_types.dart';

RazorpayCheckout createRazorpayCheckout() => const _NotAvailableCheckout();

/// Phone builds: the Razorpay plugin is not added yet, so the checkout answers that it cannot open.
class _NotAvailableCheckout implements RazorpayCheckout {
  const _NotAvailableCheckout();

  @override
  Future<RazorpayOutcome> open(RazorpayRequest request) async => const RazorpayFailed('CHECKOUT_NOT_AVAILABLE');
}
