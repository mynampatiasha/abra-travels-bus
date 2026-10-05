import 'package:flutter/widgets.dart';

import 'abra_tokens.dart';

/// Width classes the layouts adapt to. Chosen by the width available, not
/// by the device type, so split-screen and resized windows behave.
enum AbraBreakpoint {
  /// Narrow phones, below 360 logical pixels.
  smallPhone(0),

  /// Typical phones, 360 to 411.
  phone(360),

  /// Large phones, 412 to 599.
  largePhone(412),

  /// Tablets and small windows, 600 to 1023.
  tablet(600),

  /// Desktop and large tablets in landscape, 1024 and wider.
  desktop(1024);

  const AbraBreakpoint(this.minWidth);

  /// Smallest width that belongs to this class.
  final double minWidth;

  /// The class of [width].
  static AbraBreakpoint fromWidth(double width) {
    for (final breakpoint in values.reversed) {
      if (width >= breakpoint.minWidth) return breakpoint;
    }
    return smallPhone;
  }

  /// The class of the nearest [MediaQuery].
  static AbraBreakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isPhone => index <= largePhone.index;

  bool get isTabletOrWider => index >= tablet.index;
}

/// A value that depends on the width class. [phone] is required; narrower
/// and wider classes fall back to the nearest smaller value given.
@immutable
class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.phone,
    this.smallPhone,
    this.largePhone,
    this.tablet,
    this.desktop,
  });

  final T? smallPhone;
  final T phone;
  final T? largePhone;
  final T? tablet;
  final T? desktop;

  T resolve(AbraBreakpoint breakpoint) => switch (breakpoint) {
    AbraBreakpoint.smallPhone => smallPhone ?? phone,
    AbraBreakpoint.phone => phone,
    AbraBreakpoint.largePhone => largePhone ?? phone,
    AbraBreakpoint.tablet => tablet ?? largePhone ?? phone,
    AbraBreakpoint.desktop => desktop ?? tablet ?? largePhone ?? phone,
  };

  T of(BuildContext context) => resolve(AbraBreakpoint.of(context));
}

/// Responsive spacing shared by all pages.
abstract final class AbraResponsive {
  static const ResponsiveValue<double> _gutter = ResponsiveValue<double>(
    smallPhone: AbraSpacing.md,
    phone: AbraSpacing.lg,
    tablet: AbraSpacing.xl,
    desktop: AbraSpacing.xxl,
  );

  /// Horizontal page margin for [breakpoint].
  static double gutterFor(AbraBreakpoint breakpoint) =>
      _gutter.resolve(breakpoint);

  /// Horizontal page margin for the current width.
  static double gutter(BuildContext context) => _gutter.of(context);

  /// Page padding: the gutter on both sides plus vertical spacing.
  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.symmetric(
    horizontal: gutter(context),
    vertical: AbraSpacing.lg,
  );
}

/// Lays out page content: keeps it out of notches and system bars, applies
/// the responsive gutter, and centres it with a maximum width on wide
/// screens.
class AbraPageContainer extends StatelessWidget {
  const AbraPageContainer({
    required this.child,
    this.maxWidth = AbraSizes.maxContentWidth,
    this.useSafeArea = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: AbraResponsive.pagePadding(context),
          child: child,
        ),
      ),
    );
    return useSafeArea ? SafeArea(child: content) : content;
  }
}

/// Builds a different widget per width class from the width actually
/// available to it (works inside split views and dialogs).
class AbraResponsiveBuilder extends StatelessWidget {
  const AbraResponsiveBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, AbraBreakpoint breakpoint)
  builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => builder(
      context,
      AbraBreakpoint.fromWidth(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
      ),
    ),
  );
}
