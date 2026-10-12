import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// A choice chip in the customer style: white with a border, sky-tinted
/// with deep-blue text and a check when selected (so selection is not shown
/// by colour alone). At least 48 px tall to tap.
class SelectChip extends StatelessWidget {
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    avatar: icon == null || selected ? null : Icon(icon, size: 18),
    showCheckmark: true,
    checkmarkColor: AbraColors.deepBlue,
    selectedColor: AbraColors.skyContainer,
    backgroundColor: AbraColors.white,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    side: BorderSide(color: selected ? AbraColors.blue : AbraColors.border),
    shape: const StadiumBorder(),
    labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: selected ? AbraColors.deepBlue : AbraColors.navy,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
  );
}

/// A short count or status on top of an icon button ("Filters 3").
class CountBadge extends StatelessWidget {
  const CountBadge({required this.count, required this.child, super.key});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    backgroundColor: AbraColors.deepBlue,
    label: Text('$count'),
    child: child,
  );
}

/// Two or three tabs in a rounded frame: the selected one navy with white
/// text, the others plain (Lower / Upper deck, Boarding / Dropping).
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Value and label of each tab.
  final List<(T value, String label)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      backgroundColor: AbraColors.white,
      foregroundColor: AbraColors.textSecondary,
      selectedBackgroundColor: AbraColors.navy,
      selectedForegroundColor: AbraColors.white,
      side: const BorderSide(color: AbraColors.border),
      minimumSize: const Size.fromHeight(AbraSizes.minTouchTarget),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    segments: <ButtonSegment<T>>[
      for (final (value, label) in segments)
        ButtonSegment<T>(value: value, label: Text(label)),
    ],
    selected: <T>{selected},
    onSelectionChanged: (values) => onChanged(values.first),
  );
}
