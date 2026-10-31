/// What the customer needs to pay one order in the Razorpay checkout.
class RazorpayRequest {
  const RazorpayRequest({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.name,
    required this.description,
    this.contact,
    this.email,
  });

  /// The public key id of the account (not a secret; the backend hands it out with each order).
  final String keyId;
  final String orderId;
  final int amountPaise;

  /// Shown on the pay screen: "Abra Travels".
  final String name;
  final String description;
  final String? contact;
  final String? email;
}

/// How the checkout ended.
sealed class RazorpayOutcome {
  const RazorpayOutcome();
}

/// Paid. The signature proves it to our backend.
final class RazorpayPaid extends RazorpayOutcome {
  const RazorpayPaid({required this.paymentId, required this.orderId, required this.signature});

  final String paymentId;
  final String orderId;
  final String signature;
}

/// The customer closed the pay screen without paying.
final class RazorpayClosed extends RazorpayOutcome {
  const RazorpayClosed();
}

/// The payment was declined, or the pay screen could not open. [reason] is a short word code.
final class RazorpayFailed extends RazorpayOutcome {
  const RazorpayFailed(this.reason);

  final String reason;
}

abstract interface class RazorpayCheckout {
  Future<RazorpayOutcome> open(RazorpayRequest request);
}
