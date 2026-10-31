import 'razorpay_checkout_stub.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart';
import 'razorpay_checkout_types.dart';

export 'razorpay_checkout_types.dart';

/// Opens the Razorpay pay screen for an order, the way the current device can: in the browser it
/// is Razorpay's own checkout (UPI apps and QR, cards, net banking); on a phone build the
/// Razorpay plugin goes here when it is added, until then it answers "not available".
RazorpayCheckout defaultRazorpayCheckout() => createRazorpayCheckout();
