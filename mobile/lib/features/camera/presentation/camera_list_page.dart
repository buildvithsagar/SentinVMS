import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
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

  Future<void> _handleLogout() async {
    try {
      await GetIt.instance<AuthRepository>().logout();
    } finally {
      if (mounted) {
        context.read<AuthBloc>().add(const AuthLoggedOut());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14161F),
        elevation: 0,
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final tenantName = authState is Authenticated
                ? 'Tenant ID: ${authState.user.customerId.substring(0, 8.clamp(0, authState.user.customerId.length))}'
                : 'Cameras';
            return Text(
              'VMS $tenantName',
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF70788C)),
            tooltip: 'Logout',
            onPressed: _handleLogout,
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
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: InputDecoration(
                hintText: 'Search cameras by name or IP...',
                hintStyle: const TextStyle(color: Color(0xFF70788C)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF70788C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF70788C)),
                        onPressed: _searchController.clear,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF14161F),
                contentPadding: EdgeInsets.zero,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF70788C), width: 0.5),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF70788C), width: 0.5),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF02965E)),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF02965E)),
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
                            color: Color(0xFFD32F2F),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load cameras',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFFE2E8F0),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF70788C)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
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
                        style: const TextStyle(color: Color(0xFF70788C)),
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
                    color: const Color(0xFF02965E),
                    backgroundColor: const Color(0xFF14161F),
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
                              color: const Color(0x8014161F),
                              child: Text(
                                'SITE ID: $displaySiteId',
                                style: const TextStyle(
                                  color: Color(0xFF70788C),
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
                                  color: const Color(0xFF14161F),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0x2670788C),
                                    width: 0.5,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0E12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      camera.ptzCapable
                                          ? Icons.settings_backup_restore
                                          : Icons.videocam,
                                      color: const Color(0xFF70788C),
                                    ),
                                  ),
                                  title: Text(
                                    camera.name,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'IP: ${camera.ipAddress} • Profile ${camera.onvifProfile} • ${camera.codec}',
                                      style: const TextStyle(
                                        color: Color(0xFF70788C),
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
                                              ? const Color(0xFF02965E)
                                              : const Color(0xFFD32F2F),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status Text
                                      Text(
                                        isOnline ? 'ONLINE' : 'OFFLINE',
                                        style: TextStyle(
                                          color: isOnline
                                              ? const Color(0xFF02965E)
                                              : const Color(0xFFD32F2F),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        backgroundColor: const Color(0xFF14161F),
        selectedItemColor: const Color(0xFF02965E),
        unselectedItemColor: const Color(0xFF70788C),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            context.go('/live_grid');
          } else if (index == 1) {
            // Already here
          } else if (index == 2) {
            context.go('/playback');
          } else if (index == 3) {
            context.go('/alarms');
          } else if (index == 4) {
            context.go('/exports');
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
    );
  }

}
