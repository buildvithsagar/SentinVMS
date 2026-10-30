import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/theme/vms_theme.dart';
import 'package:app/core/widgets/vms_ui.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class VmsDrawer extends StatelessWidget {
  const VmsDrawer({required this.currentRoute, super.key});

  final String currentRoute;

  static const _operations = <_DrawerDestination>[
    _DrawerDestination(
      '/live_grid',
      'Live monitoring',
      Icons.grid_view_rounded,
    ),
    _DrawerDestination('/cameras', 'Cameras', Icons.videocam_rounded),
    _DrawerDestination('/playback', 'Playback', Icons.history_rounded),
    _DrawerDestination('/alarms', 'Alarms', Icons.notifications_rounded),
    _DrawerDestination('/exports', 'Exports', Icons.download_rounded),
  ];

  static const _tools = <_DrawerDestination>[
    _DrawerDestination(
      '/stream_demo',
      'Stream diagnostics',
      Icons.settings_input_antenna_rounded,
    ),
    _DrawerDestination(
      '/onboard',
      'Add a device',
      Icons.add_circle_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: VmsColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C2B25), VmsColors.canvas],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: VmsColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VmsRadii.md),
                        border: Border.all(
                          color: VmsColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_outlined,
                          color: VmsColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SENTINEL VMS',
                            style: TextStyle(
                              color: VmsColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Operator console',
                            style: TextStyle(
                              color: VmsColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VmsEnvironmentBadge(),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                  children: [
                    const _SectionLabel('OPERATIONS'),
                    for (final destination in _operations)
                      _destinationTile(context, destination),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    const _SectionLabel('SETUP & TOOLS'),
                    for (final destination in _tools)
                      _destinationTile(context, destination),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  key: const Key('drawerLogoutButton'),
                  minTileHeight: 52,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VmsRadii.sm),
                  ),
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: VmsColors.danger,
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(
                      color: VmsColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'End this operator session',
                    style: TextStyle(color: VmsColors.textMuted, fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await GetIt.instance<AuthRepository>().logout();
                    GetIt.instance<AuthBloc>().add(const AuthLoggedOut());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destinationTile(
    BuildContext context,
    _DrawerDestination destination,
  ) {
    final isActive =
        currentRoute == destination.route ||
        (destination.route == '/cameras' &&
            currentRoute.startsWith('/onboard'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: isActive,
        button: true,
        child: ListTile(
          minTileHeight: 52,
          selected: isActive,
          selectedTileColor: VmsColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VmsRadii.sm),
            side: BorderSide(
              color: isActive
                  ? VmsColors.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          leading: Icon(
            destination.icon,
            color: isActive ? VmsColors.primary : VmsColors.textSecondary,
          ),
          title: Text(
            destination.label,
            style: TextStyle(
              color: isActive ? VmsColors.textPrimary : VmsColors.textSecondary,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          trailing: isActive
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: VmsColors.primary,
                )
              : null,
          onTap: () {
            Navigator.pop(context);
            if (!isActive) context.go(destination.route);
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: VmsColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _DrawerDestination {
  const _DrawerDestination(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;
}
