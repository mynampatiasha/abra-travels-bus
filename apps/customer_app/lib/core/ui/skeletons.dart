import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

/// The shape of a card while it loads: a title line, two lines of detail
/// and a footer band.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({this.lines = 2, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AbraColors.white,
      borderRadius: AbraRadius.large,
      boxShadow: AbraShadows.soft,
    ),
    child: Padding(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              AbraSkeleton.circle(size: 36),
              SizedBox(width: AbraSpacing.md),
              Expanded(child: AbraSkeleton(height: 16)),
              SizedBox(width: AbraSpacing.xxxl),
            ],
          ),
          for (var i = 0; i < lines; i++) ...<Widget>[
            const SizedBox(height: AbraSpacing.md),
            FractionallySizedBox(
              widthFactor: i.isEven ? 1 : 0.6,
              child: const AbraSkeleton(),
            ),
          ],
          const SizedBox(height: AbraSpacing.lg),
          const AbraSkeleton(height: 32, radius: AbraRadius.md),
        ],
      ),
    ),
  );
}

/// A list of [CardSkeleton]s, announced once as loading.
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({this.count = 3, this.label, super.key});

  final int count;
  final String? label;

  @override
  Widget build(BuildContext context) => AbraSkeletonGroup(
    label: label,
    child: Column(
      children: <Widget>[
        for (var i = 0; i < count; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AbraSpacing.md),
            child: CardSkeleton(),
          ),
      ],
    ),
  );
}

/// Rows of a list (cities, settings) while they load.
class RowListSkeleton extends StatelessWidget {
  const RowListSkeleton({this.count = 6, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => AbraSkeletonGroup(
    child: Column(
      children: <Widget>[
        for (var i = 0; i < count; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AbraSpacing.md),
            child: Row(
              children: <Widget>[
                AbraSkeleton.circle(size: 32),
                SizedBox(width: AbraSpacing.lg),
                Expanded(child: AbraSkeleton()),
              ],
            ),
          ),
      ],
    ),
  );
}
