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
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
