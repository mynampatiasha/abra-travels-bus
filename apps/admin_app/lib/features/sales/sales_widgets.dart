import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

import 'sales_api.dart';

/// Title, breadcrumb and one line of help, as on the other admin pages.
class SalesHeader extends StatelessWidget {
  const SalesHeader({required this.section, required this.title, required this.help, this.actions = const <Widget>[], super.key});

  final String section;
  final String title;
  final String help;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$section / $title', style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(help, style: TextStyle(fontSize: 14, color: muted)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }
}

/// Search, one status filter and Clear.
class SalesFilterBar extends StatelessWidget {
  const SalesFilterBar({
    required this.controller,
    required this.statuses,
    required this.status,
    required this.onSearch,
    required this.onStatus,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final List<String> statuses;
  final String status;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AbraSpacing.md,
    runSpacing: AbraSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          onSubmitted: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search PNR, name, phone',
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        ),
      ),
      DropdownButton<String>(
        value: status,
        underline: const SizedBox(),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: '', child: Text('All statuses')),
          for (final s in statuses) DropdownMenuItem<String>(value: s, child: Text(readable(s))),
        ],
        onChanged: (value) => onStatus(value ?? ''),
      ),
      FilledButton.tonal(onPressed: () => onSearch(controller.text), child: const Text('Search')),
      TextButton.icon(onPressed: onClear, icon: const Icon(Icons.clear, size: 14), label: const Text('Clear')),
    ],
  );
}

/// "1-20 of 134" with Previous and Next.
class SalesPager extends StatelessWidget {
  const SalesPager({required this.firstIndex, required this.lastIndex, required this.total, required this.hasPrevious, required this.hasNext, required this.onPrevious, required this.onNext, super.key});

  final int firstIndex;
  final int lastIndex;
  final int total;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      Text('$firstIndex-$lastIndex of $total'),
      IconButton(onPressed: hasPrevious ? onPrevious : null, icon: const Icon(Icons.chevron_left), tooltip: 'Previous'),
      IconButton(onPressed: hasNext ? onNext : null, icon: const Icon(Icons.chevron_right), tooltip: 'Next'),
    ],
  );
}

/// A coloured word for a status.
class StatusWord extends StatelessWidget {
  const StatusWord(this.code, {super.key});

  final String code;

  Color get _color => switch (code) {
    'CONFIRMED' || 'SUCCESS' || 'COMPLETED' => AbraColors.teal,
    'PAYMENT_PENDING' || 'CREATED' || 'REFUND_PENDING' => AbraColors.orange,
    'FAILED' || 'EXPIRED' || 'CANCELLED' => AbraColors.danger,
    _ => AbraColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) =>
      Text(readable(code), style: TextStyle(color: _color, fontWeight: FontWeight.w700));
}

/// The table card around a [DataTable], scrolling both ways.
class SalesTableCard extends StatelessWidget {
  const SalesTableCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF13222F) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
    );
  }
}
