import 'package:app/core/theme/vms_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VmsNavigationBar extends StatelessWidget {
  const VmsNavigationBar({required this.currentRoute, super.key});

  final String currentRoute;

  static const _destinations = <_VmsDestination>[
    _VmsDestination(
      '/live_grid',
      'Live',
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
    ),
    _VmsDestination(
      '/cameras',
      'Cameras',
      Icons.videocam_outlined,
      Icons.videocam_rounded,
    ),
    _VmsDestination(
      '/playback',
      'Playback',
      Icons.history_outlined,
      Icons.history_rounded,
    ),
    _VmsDestination(
      '/alarms',
      'Alarms',
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
    ),
    _VmsDestination(
      '/exports',
      'Exports',
      Icons.download_outlined,
      Icons.download_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => currentRoute.startsWith(destination.route),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VmsColors.surface,
          borderRadius: BorderRadius.circular(VmsRadii.lg),
          border: Border.all(color: VmsColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VmsRadii.lg),
          child: NavigationBar(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              final route = _destinations[index].route;
              if (route != currentRoute) context.go(route);
            },
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  tooltip: destination.label,
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VmsDestination {
  const _VmsDestination(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
