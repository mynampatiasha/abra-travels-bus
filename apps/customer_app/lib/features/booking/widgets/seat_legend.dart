import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../core/ui/seat_tile.dart';
import 'seat_grid.dart';

/// What the seat styles mean. Each entry is a small seat drawn exactly like
/// on the map, with its name beside it.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  static const _states = <SeatTileState>[
    SeatTileState.available,
    SeatTileState.selected,
    SeatTileState.booked,
    SeatTileState.ladiesOnly,
    SeatTileState.blocked,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: AbraSpacing.lg,
      runSpacing: AbraSpacing.sm,
      children: <Widget>[
        for (final state in _states)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: IgnorePointer(
                  child: SeatTile(
                    id: '',
                    state: state,
                    width: 18,
                    height: 18,
                    semanticsLabel: '',
                    minHitSize: 0,
                  ),
                ),
              ),
              const SizedBox(width: AbraSpacing.sm - 2),
              Flexible(
                child: Text(SeatGrid.statusLabel(l10n, state), style: style),
              ),
            ],
          ),
      ],
    );
  }
}
