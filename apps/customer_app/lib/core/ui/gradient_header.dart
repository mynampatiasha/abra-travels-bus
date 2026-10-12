import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

/// The top bar of the customer app: white title (and optional subtitle) on
/// the deep brand gradient. Back button, actions and system bar styling are
/// the standard [AppBar] ones.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    (subtitle == null ? kToolbarHeight : kToolbarHeight + AbraSpacing.md) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: AbraColors.navy,
      foregroundColor: AbraColors.white,
      toolbarHeight: subtitle == null
          ? kToolbarHeight
          : kToolbarHeight + AbraSpacing.md,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AbraGradients.brandDeep),
      ),
      titleSpacing: leading == null && !automaticallyImplyLeading
          ? AbraResponsive.gutter(context)
          : null,
      title: Semantics(
        header: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(color: AbraColors.white),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AbraColors.onNavyMuted,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        ...actions,
        const SizedBox(width: AbraSpacing.xs),
      ],
      bottom: bottom,
    );
  }
}

/// A brand block at the top of a page (Home hero, trip header): the brand
/// gradient with the route motif, rounded at the bottom, white content.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: AbraSpacing.xl),
    this.roundedBottom = true,
    this.showMotif = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool roundedBottom;
  final bool showMotif;

  @override
  Widget build(BuildContext context) => AbraBrandSurface(
    gradient: AbraGradients.brandDeep,
    showMotif: showMotif,
    borderRadius: roundedBottom
        ? const BorderRadius.vertical(bottom: Radius.circular(AbraRadius.xl))
        : BorderRadius.zero,
    child: Padding(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AbraColors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: AbraColors.white),
          child: child,
        ),
      ),
    ),
  );
}
