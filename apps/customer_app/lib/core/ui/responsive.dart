import 'package:flutter/widgets.dart';
import 'package:shared_theme/shared_theme.dart';

/// Layout rules of the customer app, on top of [AbraBreakpoint].
///
/// - below [navigationRailFrom] the sections are a bottom bar;
/// - from [navigationRailFrom] a navigation rail, extended (icon and label
///   side by side) from [extendedRailFrom];
/// - sheets become centred dialogs from [dialogFrom] and full-screen pages
///   when the screen is shorter than [shortHeight];
/// - two columns (content and a summary or filter panel) from
///   [twoColumnsFrom].
abstract final class CustomerLayout {
  static const double navigationRailFrom = 840;
  static const double extendedRailFrom = 1200;
  static const double dialogFrom = 600;
  static const double twoColumnsFrom = 840;
  static const double shortHeight = 560;

  /// A summary and price card beside the form or seat map (instead of a
  /// bar at the bottom) from this width.
  static const double sideSummaryFrom = 600;

  /// Widest a list of cards grows (search results, trips).
  static const double listMaxWidth = 760;

  /// Widest a dialog or a sheet on a wide screen grows.
  static const double dialogMaxWidth = 480;

  /// Text this much larger than normal turns side-by-side rows into
  /// columns.
  static const double largeTextScale = 1.6;

  static Size _size(BuildContext context) => MediaQuery.sizeOf(context);

  static bool usesNavigationRail(BuildContext context) =>
      _size(context).width >= navigationRailFrom;

  static bool usesExtendedRail(BuildContext context) =>
      _size(context).width >= extendedRailFrom;

  static bool usesDialogs(BuildContext context) =>
      _size(context).width >= dialogFrom && !isShort(context);

  static bool isShort(BuildContext context) =>
      _size(context).height < shortHeight;

  static bool hasSideSummary(BuildContext context) =>
      _size(context).width >= sideSummaryFrom;

  static bool hasTwoColumns(BuildContext context) =>
      _size(context).width >= twoColumnsFrom;

  /// True when the text is so large that two texts side by side would be
  /// cramped; such rows stack instead.
  static bool hasLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(10) / 10 >= largeTextScale;

  /// True when side-by-side content should stack: a narrow phone, or large
  /// text.
  static bool shouldStack(BuildContext context) =>
      _size(context).width < AbraBreakpoint.phone.minWidth ||
      hasLargeText(context);
}

/// Centres [child] with a maximum width and the page gutter on both sides.
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    required this.child,
    this.maxWidth = AbraSizes.maxContentWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  /// Replaces the horizontal page gutter.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    // As tall as the content, also where the height is unbounded or loose
    // (a bottom bar), never the whole screen.
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: AbraResponsive.gutter(context)),
        child: child,
      ),
    ),
  );
}
