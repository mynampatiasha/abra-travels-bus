import 'package:flutter/material.dart';

/// "Bengaluru → Hyderabad": two cities with an arrow icon between them (a
/// real icon, not a text arrow). Wraps when the names are long.
class RouteLabel extends StatelessWidget {
  const RouteLabel({
    required this.from,
    required this.to,
    this.style,
    super.key,
  });

  final String from;
  final String to;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final size = (effective.fontSize ?? 14) * 1.1;
    return Semantics(
      label: '$from, $to',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: from),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: size,
                  color: effective.color,
                ),
              ),
            ),
            TextSpan(text: to),
          ],
        ),
        style: style,
      ),
    );
  }
}
