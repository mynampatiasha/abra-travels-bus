import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/rupees.dart';
import '../../../core/ui/seat_tile.dart';
import '../../../l10n/customer_strings.dart';
import '../models/seat_models.dart';

/// The seats of one deck, drawn row by row from the front of the bus, with
/// the aisle in its place. The seat size is worked out from the width the
/// grid actually has (never below 36 or above 56 logical pixels in height),
/// so the layout fits every screen and text size.
class SeatGrid extends StatelessWidget {
  const SeatGrid({
    required this.map,
    required this.deck,
    required this.chosenIds,
    required this.currencyCode,
    required this.onSeatTap,
    super.key,
  });

  final SeatMap map;
  final SeatDeck deck;
  final List<String> chosenIds;
  final String currencyCode;
  final ValueChanged<Seat> onSeatTap;

  static const double _gap = 10;
  static const double _minSize = 36;
  static const double _maxSize = 56;
  static const double _berthRatio = 72 / 56;
  static const double _aisleRatio = 0.6;

  SeatTileState _stateOf(Seat seat) {
    if (chosenIds.contains(seat.id)) return SeatTileState.selected;
    return switch (seat.status) {
      SeatStatus.available => SeatTileState.available,
      SeatStatus.booked => SeatTileState.booked,
      SeatStatus.ladiesOnly => SeatTileState.ladiesOnly,
      SeatStatus.blocked => SeatTileState.blocked,
    };
  }

  static String statusLabel(AbraLocalizations l10n, SeatTileState state) =>
      l10n.text(switch (state) {
        SeatTileState.available => CustomerStrings.seatLegendAvailable,
        SeatTileState.selected => CustomerStrings.seatLegendSelected,
        SeatTileState.booked => CustomerStrings.seatLegendBooked,
        SeatTileState.ladiesOnly => CustomerStrings.seatLegendLadies,
        SeatTileState.blocked => CustomerStrings.seatLegendBlocked,
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final isBerth = map.kind == SeatLayoutKind.sleeper;
    final seats = map.onDeck(deck);
    final columns = map.columnCount;
    final rows = map.rowCount;
    final ratio = isBerth ? _berthRatio : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _maxSize * columns * ratio;
        double sizeFor(double width) =>
            ((width - (columns + 1) * _gap) / (columns * ratio + _aisleRatio))
                .clamp(_minSize, _maxSize);
        // Seats smaller than the touch target get a tap area of at least
        // 48 square. It sticks out of the drawn seat, so the gaps between
        // the areas are reduced by as much (the seats keep their distance)
        // and the row loses that much width.
        const touch = AbraSizes.minTouchTarget;
        final overhang = math.max(0.0, touch - sizeFor(available) * ratio);
        final size = sizeFor(available - overhang);
        final width = size * ratio;
        final aisle = size * _aisleRatio;
        final slotWidth = math.max(width, touch);
        final slotHeight = math.max(size, touch);
        final columnGap = math.max(0.0, _gap - (slotWidth - width));
        final rowGap = math.max(0.0, _gap - (slotHeight - size));

        Widget cell(int row, int column) {
          final seat = seats
              .where((s) => s.row == row && s.column == column)
              .firstOrNull;
          if (seat == null) {
            return SizedBox(width: slotWidth, height: slotHeight);
          }
          final state = _stateOf(seat);
          final price = formatRupees(
            l10n,
            seat.farePaise,
            currencyCode: currencyCode,
          );
          final status = statusLabel(l10n, state);
          final showsPrice =
              state != SeatTileState.booked && state != SeatTileState.blocked;
          return SeatTile(
            id: seat.id,
            state: state,
            width: width,
            height: size,
            shape: isBerth ? SeatTileShape.berth : SeatTileShape.seat,
            price: showsPrice ? price : null,
            semanticsLabel: showsPrice
                ? l10n.text(CustomerStrings.seatSemantics, <String, Object?>{
                    'seat': seat.id,
                    'status': status,
                    'price': price,
                  })
                : l10n.text(
                    CustomerStrings.seatSemanticsNoPrice,
                    <String, Object?>{'seat': seat.id, 'status': status},
                  ),
            bookedMessage: l10n.text(
              CustomerStrings.seatBookedTip,
              <String, Object?>{'seat': seat.id},
            ),
            onTap: () => onSeatTap(seat),
          );
        }

        final grid = Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var row = 0; row < rows; row++)
              Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : rowGap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (
                      var column = 0;
                      column < columns;
                      column++
                    ) ...<Widget>[
                      if (column > 0) SizedBox(width: columnGap),
                      if (column == map.aisleAfterColumn + 1)
                        SizedBox(width: aisle + _gap),
                      cell(row, column),
                    ],
                  ],
                ),
              ),
          ],
        );

        return Semantics(
          container: true,
          label: l10n.text(CustomerStrings.seatMapLabel, <String, Object?>{
            'deck': l10n.text(
              deck == SeatDeck.lower
                  ? CustomerStrings.seatDeckLower
                  : CustomerStrings.seatDeckUpper,
            ),
          }),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
                child: grid,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The skeleton of a seat map while it loads: the same grid of blocks, so
/// nothing jumps when the seats arrive.
class SeatGridSkeleton extends StatelessWidget {
  const SeatGridSkeleton({this.berths = true, super.key});

  final bool berths;

  @override
  Widget build(BuildContext context) {
    final columns = berths ? 3 : 4;
    return AbraSkeletonGroup(
      child: Column(
        children: <Widget>[
          for (var row = 0; row < (berths ? 6 : 8); row++)
            Padding(
              padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
              child: Row(
                children: <Widget>[
                  for (var column = 0; column < columns; column++) ...<Widget>[
                    if (column > 0) const SizedBox(width: AbraSpacing.sm),
                    if (column == 2) const SizedBox(width: AbraSpacing.xl),
                    const Expanded(
                      child: AbraSkeleton(height: 48, radius: AbraRadius.md),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
