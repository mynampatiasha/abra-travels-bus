import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../routing/portal_routes.dart';

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = kMockMe;
    final owner = me['owner'] as String? ?? 'Ramesh Kumar';
    final firstName = owner.split(' ').first;
    final companyName = me['name'] as String? ?? 'Kaveri Express';

    // Dynamic metrics
    final bookingsToday = kMockBookings.where((b) {
      final at = DateTime.tryParse(b['at'] as String? ?? '');
      if (at == null) return false;
      final now = DateTime.now();
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).length.toString();

    final earnings = kMockEarnings;
    final last7 = earnings.length >= 7 ? earnings.skip(earnings.length - 7).toList() : earnings;
    final earnings7dPaise = last7.fold<int>(0, (sum, e) => sum + (e['net'] as int));
    final earnings7d = formatRs(earnings7dPaise);

    final avgOccupancy = kMockTrips.isEmpty
        ? '0%'
        : '${(kMockTrips.fold<int>(0, (acc, t) => acc + (t['booked'] as int? ?? 0)) / (kMockTrips.fold<int>(0, (acc, t) => acc + (t['seats'] as int? ?? 1))) * 100).round()}%';
    final upcomingTrips = kMockTrips.where((t) => t['status'] == 'SCHEDULED' || t['status'] == 'IN_TRANSIT').length.toString();
    final activeBuses = kMockBuses.where((b) => b['status'] == 'ACTIVE').length.toString();
    final busesLiveNow = kMockLive.length.toString();
    final driversOnDuty = kMockCrew.where((c) => c['role'] == 'DRIVER' && c['status'] == 'ACTIVE').length.toString();
    final customerRating = me['rating']?.toString() ?? '-';

    // Attention alerts
    final alerts = <Map<String, dynamic>>[];
    for (final b in kMockBuses) {
      final ins = DateTime.tryParse(b['insExp'] as String? ?? '');
      if (ins != null && ins.difference(DateTime.now()).inDays < 30) {
        alerts.add({
          'tone': 'danger',
          'msg': 'Bus ${b['reg']} insurance expires within 30 days',
          'route': PortalRoutes.buses,
        });
      }
    }

    // Chart data (last 14 days)
    final last14 = earnings.length >= 14 ? earnings.skip(earnings.length - 14).toList() : earnings;
    final bookingSpots = last14.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['bookings'] as int).toDouble())
    ).toList();

    final earningSpots = last14.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['net'] as int) / 10000)
    ).toList();

    final confirmed = kMockBookings.where((b) => b['status'] == 'CONFIRMED').length;
    final completed = kMockBookings.where((b) => b['status'] == 'COMPLETED').length;
    final cancelled = kMockBookings.where((b) => b['status'] == 'CANCELLED').length;
    final totalBookings = confirmed + completed + cancelled;

    // Occupancy by route
    final occData = <MapEntry<String, int>>[];
    for (final t in kMockTrips) {
      final r = t['route'] as String? ?? '';
      if (r.isNotEmpty && !occData.any((e) => e.key == r)) {
        final rTrips = kMockTrips.where((x) => x['route'] == r);
        final booked = rTrips.fold<int>(0, (a, b) => a + (b['booked'] as int? ?? 0));
        final seats = rTrips.fold<int>(0, (a, b) => a + (b['seats'] as int? ?? 1));
        final pct = seats > 0 ? (booked / seats * 100).round() : 0;
        occData.add(MapEntry(r, pct));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 760;
        return ListView(
          padding: EdgeInsets.all(isWide ? AbraSpacing.xxl : AbraSpacing.lg),
          children: [
            // Top Welcome Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $firstName',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AbraColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            companyName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AbraColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('·', style: TextStyle(color: AbraColors.textSecondary)),
                          const SizedBox(width: 6),
                          const Text(
                            'verified partner',
                            style: TextStyle(
                              color: AbraColors.teal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ New trip', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  onPressed: () => context.go(PortalRoutes.trips),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.xl),
            // 8 KPI Cards Grid (4 columns on desktop, 2 on mobile)
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              childAspectRatio: isWide ? 2.3 : 1.7,
              mainAxisSpacing: AbraSpacing.md,
              crossAxisSpacing: AbraSpacing.md,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                PortalKpiCard(
                  icon: Icons.confirmation_number_outlined,
                  value: bookingsToday,
                  label: 'Bookings today',
                  onTap: () => context.go(PortalRoutes.bookings),
                ),
                PortalKpiCard(
                  icon: Icons.credit_card_outlined,
                  value: earnings7d,
                  label: 'Your earnings, 7 days',
                  isHighlighted: true,
                  onTap: () => context.go(PortalRoutes.earnings),
                ),
                PortalKpiCard(
                  icon: Icons.bar_chart_outlined,
                  value: avgOccupancy,
                  label: 'Average occupancy',
                ),
                PortalKpiCard(
                  icon: Icons.calendar_today_outlined,
                  value: upcomingTrips,
                  label: 'Upcoming trips',
                  onTap: () => context.go(PortalRoutes.trips),
                ),
                PortalKpiCard(
                  icon: Icons.airline_seat_recline_normal_outlined,
                  value: activeBuses,
                  label: 'Active buses',
                  onTap: () => context.go(PortalRoutes.buses),
                ),
                PortalKpiCard(
                  icon: Icons.near_me_outlined,
                  value: busesLiveNow,
                  label: 'Buses live now',
                  onTap: () => context.go(PortalRoutes.liveTracking),
                ),
                PortalKpiCard(
                  icon: Icons.people_outline,
                  value: driversOnDuty,
                  label: 'Drivers on duty',
                  onTap: () => context.go(PortalRoutes.crew),
                ),
                PortalKpiCard(
                  icon: Icons.star_outline,
                  value: customerRating,
                  label: 'Customer rating',
                ),
              ],
            ),
            // Needs your attention
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: AbraSpacing.xl),
              Text(
                'Needs your attention',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AbraColors.textPrimary,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AbraRadius.lg),
                  border: Border.all(color: AbraColors.border),
                  boxShadow: AbraShadows.soft,
                ),
                child: Column(
                  children: [
                    for (final alert in alerts)
                      InkWell(
                        borderRadius: BorderRadius.circular(AbraRadius.lg),
                        onTap: () => context.go(alert['route'] as String),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg, vertical: AbraSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AbraColors.orangeContainer,
                                  borderRadius: BorderRadius.circular(AbraRadius.md),
                                ),
                                child: const Icon(
                                  Icons.bar_chart_outlined,
                                  size: 18,
                                  color: AbraColors.orangeDark,
                                ),
                              ),
                              const SizedBox(width: AbraSpacing.md),
                              Expanded(
                                child: Text(
                                  alert['msg'] as String,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AbraColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AbraColors.textSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AbraSpacing.xl),
            // Charts Row 1: Line Chart + Donut Chart (exactly as in screenshot)
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _chartCard(
                      context,
                      'Bookings, last 14 days',
                      _lineChart(context, bookingSpots, 'Bookings', AbraColors.blue),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.lg),
                  Expanded(
                    child: _chartCard(
                      context,
                      'Booking status',
                      _donutChart(totalBookings, confirmed, completed, cancelled),
                    ),
                  ),
                ],
              )
            else ...[
              _chartCard(
                context,
                'Bookings, last 14 days',
                _lineChart(context, bookingSpots, 'Bookings', AbraColors.blue),
              ),
              const SizedBox(height: AbraSpacing.lg),
              _chartCard(
                context,
                'Booking status',
                _donutChart(totalBookings, confirmed, completed, cancelled),
              ),
            ],
            const SizedBox(height: AbraSpacing.lg),
            // Charts Row 2: Earnings Line + Occupancy Bar
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _chartCard(
                      context,
                      'Your earnings per day (after commission)',
                      _lineChart(context, earningSpots, 'Earnings (₹)', AbraColors.teal),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.lg),
                  Expanded(
                    child: _chartCard(
                      context,
                      'Occupancy by route',
                      _barChart(occData),
                    ),
                  ),
                ],
              )
            else ...[
              _chartCard(
                context,
                'Your earnings per day (after commission)',
                _lineChart(context, earningSpots, 'Earnings (₹)', AbraColors.teal),
              ),
              const SizedBox(height: AbraSpacing.lg),
              _chartCard(
                context,
                'Occupancy by route',
                _barChart(occData),
              ),
            ],
            const SizedBox(height: AbraSpacing.xxl),
          ],
        );
      },
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AbraColors.textPrimary,
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          chart,
        ],
      ),
    );
  }

  Widget _lineChart(BuildContext context, List<FlSpot> spots, String label, Color color) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AbraColors.divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.round()}',
                  style: const TextStyle(fontSize: 10, color: AbraColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _donutChart(int total, int confirmed, int completed, int cancelled) {
    if (total == 0) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline, size: 40, color: AbraColors.textDisabled),
              SizedBox(height: 8),
              Text('No bookings yet', style: TextStyle(color: AbraColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: confirmed.toDouble(),
                        color: AbraColors.blue,
                        title: '',
                        radius: 36,
                      ),
                      PieChartSectionData(
                        value: completed.toDouble(),
                        color: AbraColors.skyBlue,
                        title: '',
                        radius: 36,
                      ),
                      PieChartSectionData(
                        value: cancelled.toDouble(),
                        color: AbraColors.danger,
                        title: '',
                        radius: 36,
                      ),
                    ],
                    centerSpaceRadius: 48,
                    sectionsSpace: 2,
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AbraColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legend('Confirmed', confirmed, AbraColors.blue),
              const SizedBox(height: 8),
              _legend('Completed', completed, AbraColors.skyBlue),
              const SizedBox(height: 8),
              _legend('Cancelled', cancelled, AbraColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
        ),
      ],
    );
  }

  Widget _barChart(List<MapEntry<String, int>> data) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 40, color: AbraColors.textDisabled),
              SizedBox(height: 8),
              Text('No route occupancy data yet', style: TextStyle(color: AbraColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barGroups: data.asMap().entries.map((e) =>
            BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: AbraColors.blue,
                  width: 32,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.round()}%',
                  style: const TextStyle(fontSize: 10, color: AbraColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, m) {
                  if (v.toInt() >= data.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[v.toInt()].key,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AbraColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AbraColors.divider, strokeWidth: 1),
          ),
        ),
      ),
    );
  }
}
