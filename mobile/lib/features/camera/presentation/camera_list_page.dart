import 'dart:ui';

import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/widgets/vms_drawer.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CameraListPage extends StatefulWidget {
  const CameraListPage({super.key});

  @override
  State<CameraListPage> createState() => _CameraListPageState();
}

class _CameraListPageState extends State<CameraListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Dispatch initial fetch
    context.read<CameraBloc>().add(const FetchCameras());
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      drawer: const VmsDrawer(currentRoute: '/cameras'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final tenantName = authState is Authenticated
                ? 'Tenant ID: ${authState.user.customerId.substring(0, 8.clamp(0, authState.user.customerId.length))}'
                : 'Cameras';
            return Text(
              'VMS $tenantName',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => context.push('/onboard'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search cameras by name or IP...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                        onPressed: _searchController.clear,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),

          // Camera List
          Expanded(
            child: BlocBuilder<CameraBloc, CameraState>(
              builder: (context, state) {
                if (state is CameraLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  );
                }

                if (state is CameraError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFEF4444),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load cameras',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              context.read<CameraBloc>().add(const FetchCameras());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is CameraLoaded) {
                  final cameras = state.cameras;
                  final filteredCameras = cameras.where((cam) {
                    return cam.name.toLowerCase().contains(_searchQuery) ||
                        cam.ipAddress.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filteredCameras.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No cameras matching search query'
                            : 'No cameras registered for this tenant',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  // Group cameras by siteId
                  final grouped = <String, List<Camera>>{};
                  for (final cam in filteredCameras) {
                    grouped.putIfAbsent(cam.siteId, () => []).add(cam);
                  }

                  final siteIds = grouped.keys.toList()..sort();

                  return RefreshIndicator(
                    color: const Color(0xFF2DD4BF),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: () async {
                      context.read<CameraBloc>().add(const FetchCameras());
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: siteIds.length,
                      itemBuilder: (context, index) {
                        final siteId = siteIds[index];
                        final siteCameras = grouped[siteId]!;
                        final displaySiteId = siteId.length > 8
                            ? siteId.substring(0, 8)
                            : siteId;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Site Header Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              color: Colors.white.withValues(alpha: 0.05),
                              child: Text(
                                'SITE ID: $displaySiteId',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),

                            // Cameras in this Site
                            ...siteCameras.map((camera) {
                              final isOnline = camera.status == 'CONNECTED';
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        camera.ptzCapable
                                            ? Icons.settings_backup_restore
                                            : Icons.videocam,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    title: Text(
                                      camera.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'IP: ${camera.ipAddress} • Profile ${camera.onvifProfile} • ${camera.codec}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Status Dot
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOnline
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Status Text
                                        Text(
                                          isOnline ? 'ONLINE' : 'OFFLINE',
                                          style: TextStyle(
                                            color: isOnline
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: 1,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: const Color(0xFF2DD4BF),
                  unselectedItemColor: const Color(0xFF94A3B8),
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) {
                    if (index == 0) {
                      context.go('/live_grid');
                    } else if (index == 1) {
                      // Already here
                    } else if (index == 2) {
                      context.push('/playback');
                    } else if (index == 3) {
                      context.push('/alarms');
                    } else if (index == 4) {
                      context.push('/exports');
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.grid_view),
                      label: 'Live Grid',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.list),
                      label: 'Cameras',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.history),
                      label: 'Playback',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.notifications),
                      label: 'Alarms',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.download),
                      label: 'Exports',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
