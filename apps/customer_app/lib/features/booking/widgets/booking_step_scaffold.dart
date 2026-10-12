import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../core/ui/gradient_header.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/sticky_action_bar.dart';
import 'hold_widgets.dart';

/// The frame of a booking step (passengers, review, payment): the gradient
/// bar with the hold countdown, a scrolling form, and the action.
///
/// - Phones (and short screens): one column and a sticky bar at the bottom
///   with the total and the action.
/// - From 600 dp wide: the form on the left and [sideSummary] (the fare and
///   the action) on the right, which stays in view while the form scrolls.
///
/// Enter triggers the action when [onAction] is not null.
class BookingStepScaffold extends StatelessWidget {
  const BookingStepScaffold({
    required this.tripId,
    required this.title,
    required this.children,
    required this.sideSummary,
    required this.barTotal,
    required this.barCaption,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
    this.showHold = true,
    this.scrollController,
    super.key,
  });

  final String tripId;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Shown beside the form on wide screens.
  final Widget sideSummary;

  /// The amount in the bottom bar ("₹5,134") and what it is ("Total").
  final String barTotal;
  final String barCaption;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool showHold;
  final ScrollController? scrollController;

  /// Whether the summary is beside the form (not in a bottom bar).
  static bool usesSideSummary(BuildContext context) =>
      CustomerLayout.hasSideSummary(context) &&
      !CustomerLayout.isShort(context);

  static double summaryWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.3).clamp(240.0, 340.0);

  @override
  Widget build(BuildContext context) {
    final sideBySide = usesSideSummary(context);
    final gutter = AbraResponsive.gutter(context);

    final list = ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        sideBySide ? 0 : gutter,
        AbraSpacing.lg,
        sideBySide ? 0 : gutter,
        AbraSpacing.xl,
      ),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AbraSpacing.md),
      itemBuilder: (_, index) => children[index],
    );

    final Widget body = sideBySide
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AbraSizes.maxContentWidth,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: list),
                    const SizedBox(width: AbraSpacing.xl),
                    SizedBox(
                      width: summaryWidth(context),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: AbraSpacing.lg),
                        child: sideSummary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CustomerLayout.listMaxWidth,
              ),
              child: list,
            ),
          );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () => onAction?.call(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: GradientAppBar(
            title: title,
            subtitle: subtitle,
            actions: <Widget>[
              if (showHold)
                HoldChip(tripId: tripId)
              else
                // No countdown on screen, but the hold is still watched.
                HoldWatcher(tripId: tripId),
            ],
          ),
          bottomNavigationBar: sideBySide
              ? null
              : StickyActionBar(
                  title: barTotal,
                  subtitle: barCaption,
                  captionFirst: true,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
          body: body,
        ),
      ),
    );
  }
}
