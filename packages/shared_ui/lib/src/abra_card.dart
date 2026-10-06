import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// A rounded content card. With [onTap] the whole card is a tap target.
class AbraCard extends StatelessWidget {
  const AbraCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(AbraSpacing.lg),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Directional, so it mirrors correctly in right-to-left languages.
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final isLabelled = semanticLabel != null;
    // With a label the card is announced as one thing: the label replaces
    // what is inside, and carries the tap itself so it is not left on an
    // unlabelled inner node.
    return Semantics(
      container: isLabelled,
      label: semanticLabel,
      button: onTap != null,
      onTap: isLabelled ? onTap : null,
      excludeSemantics: isLabelled,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
