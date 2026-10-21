import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Admin Bookings screen matching prototypes/admin_demo_model.html.
class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({this.initialBookingId, super.key});

  final String? initialBookingId;

  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedMode = 'ALL';
  String _selectedOperator = 'ALL';
  String? _selectedBookingId;

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.initialBookingId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'ALL';
      _selectedMode = 'ALL';
      _selectedOperator = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedBookingId != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedBookingId = null),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to bookings'),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              Container(
                padding: const EdgeInsets.all(AbraSpacing.xxl),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.confirmation_number_outlined, size: 48, color: AbraColors.textDisabled),
                    SizedBox(height: AbraSpacing.md),
                    Text(
                      'Not connected yet - built in Phase 3',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Breadcrumbs
            Row(
              children: <Widget>[
                const Text('Sales', style: TextStyle(color: AbraColors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(' / ', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
                Text('Bookings', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AbraSpacing.xs),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bookings',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text(
                      'Search by PNR, passenger phone, name or route.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Filter Bar Card
            Container(
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Wrap(
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  // Search Box
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search PNR, name, phone...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  // Status Filter
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                      DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),

                  // Payment Mode Filter
                  DropdownButton<String>(
                    value: _selectedMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All modes')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'CARD', child: Text('Card')),
                      DropdownMenuItem(value: 'NETBANKING', child: Text('Netbanking')),
                      DropdownMenuItem(value: 'WALLET', child: Text('Wallet')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMode = val);
                    },
                  ),

                  // Operator Filter
                  DropdownButton<String>(
                    value: _selectedOperator,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All operators')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOperator = val);
                    },
                  ),

                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Data Table Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(
                        isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Travel Date', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Seats', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Paid by', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: const <DataRow>[],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(AbraSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.confirmation_number_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 3',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
