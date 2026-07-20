import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class VmsDrawer extends StatelessWidget {
  const VmsDrawer({required this.currentRoute, super.key});
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF040606),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C3D32), // Forest green at top
              Color(0xFF071C17), // Deep forest green transition
              Color(0xFF040606), // Near pitch dark green-black outer
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom Header matching the Login branding exactly
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 48,
                          width: 48,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.security,
                              color: Color(0xFF2DD4BF),
                              size: 48,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SENTINEL VMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tactical Control Suite',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2DD4BF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'OPERATOR SESSION ACTIVE',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  ],
                ),
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.grid_view,
                    title: 'Live Grid Dashboard',
                    route: '/live_grid',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.videocam,
                    title: 'Camera Management',
                    route: '/cameras',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_active_outlined,
                    title: 'Alarms Panel',
                    route: '/alarms',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.play_circle_outline,
                    title: 'Video Playback',
                    route: '/playback',
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.download_outlined,
                    title: 'Export History',
                    route: '/exports',
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 16),
                  _buildLogoutItem(context),
                ],
              ),
            ),
            
            // Bottom Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'VMS OPERATOR v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
  }) {
    final isActive = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? const Color(0xFF2DD4BF).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.01),
          border: Border.all(
            color: isActive ? const Color(0xFF2DD4BF).withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(icon, color: isActive ? const Color(0xFF2DD4BF) : Colors.white70),
            title: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              if (!isActive) {
                context.go(route);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.01),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            key: const Key('drawerLogoutButton'),
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              GetIt.instance<AuthRepository>().logout();
              GetIt.instance<AuthBloc>().add(const AuthLoggedOut());
            },
          ),
        ),
      ),
    );
  }
}
