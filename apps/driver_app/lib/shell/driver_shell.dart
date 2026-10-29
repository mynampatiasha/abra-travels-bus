import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/providers.dart';
import '../features/assistant/assistant_driver_screen.dart';
import '../features/notifications/notifications_driver_screen.dart';
import '../features/sos/sos_driver_screen.dart';
import '../routing/driver_routes.dart';

class DriverShell extends ConsumerWidget {
  const DriverShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  int _currentIndex(String path) {
    if (path.startsWith(DriverRoutes.trip)) return 1;
    if (path.startsWith(DriverRoutes.reports)) return 2;
    if (path.startsWith(DriverRoutes.alerts)) return 3;
    if (path.startsWith(DriverRoutes.profile)) return 4;
    return 0; // home
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(driverNotificationsProvider);
    final unreadNotifs = notifs.value?.where((n) => !n.read).length ?? 0;
    final db = ref.watch(driverMockDbProvider);
    final currentTrip = db.currentTrip;
    final hasActiveTrip = currentTrip != null &&
        ['BOARDING', 'IN_TRANSIT', 'DELAYED'].contains(currentTrip['status']);

    final index = _currentIndex(currentPath);

    return Scaffold(
      body: Stack(
        children: [
          child,
          // Floating SOS Button (bottom-right)
          if (hasActiveTrip)
            Positioned(
              right: 18,
              bottom: 84,
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  heroTag: 'driver_sos_fab',
                  backgroundColor: const Color(0xFFEF4444),
                  elevation: 8,
                  shape: const CircleBorder(),
                  onPressed: () {
                    SosDriverSheet.show(context, currentTrip['id'] as String);
                  },
                  child: const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          // Floating AI Assistant Button (bottom-left)
          Positioned(
            left: 18,
            bottom: 88,
            child: SizedBox(
              width: 50,
              height: 50,
              child: FloatingActionButton(
                heroTag: 'driver_ai_fab',
                backgroundColor: const Color(0xFF12304A),
                elevation: 6,
                shape: const CircleBorder(),
                onPressed: () {
                  AssistantDriverSheet.show(context);
                },
                child: const Icon(Icons.mic, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFFE0F2FE),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF1677C8)),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus, color: Color(0xFF1677C8)),
            label: 'Your trip',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF1677C8)),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications, color: Color(0xFF1677C8)),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF1677C8)),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (idx) {
          switch (idx) {
            case 0:
              context.go(DriverRoutes.home);
              break;
            case 1:
              context.go(DriverRoutes.trip);
              break;
            case 2:
              context.go(DriverRoutes.reports);
              break;
            case 3:
              context.go(DriverRoutes.alerts);
              break;
            case 4:
              context.go(DriverRoutes.profile);
              break;
          }
        },
      ),
    );
  }
}
