import 'package:app/core/core.dart';
import 'package:app/features/camera/camera.dart';
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
    context.read<CameraBloc>().add(const FetchCameras());
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) setState(() => _searchQuery = query);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const VmsDrawer(currentRoute: '/cameras'),
      appBar: AppBar(
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final customerId = authState is Authenticated
                ? authState.user.customerId
                : '';
            final shortId = customerId.length > 8
                ? customerId.substring(0, 8)
                : customerId;
            return VmsPageTitle(
              title: 'Cameras',
              subtitle: shortId.isEmpty
                  ? 'Device inventory'
                  : 'Tenant $shortId',
            );
          },
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: VmsEnvironmentBadge()),
          ),
          IconButton(
            tooltip: 'Add camera or device',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _openAddCamera,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by camera name or IP address',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: const WidgetStatePropertyAll(VmsColors.surface),
              side: const WidgetStatePropertyAll(
                BorderSide(color: VmsColors.border),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VmsRadii.md),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<CameraBloc, CameraState>(
              builder: (context, state) {
                if (state is CameraLoading) {
                  return const VmsLoadingView(label: 'Loading cameras...');
                }
                if (state is CameraError) {
                  return VmsStateView.error(
                    title: 'Could not load cameras',
                    message:
                        '${state.message}\nCheck the connection and try again.',
                    onRetry: () =>
                        context.read<CameraBloc>().add(const FetchCameras()),
                  );
                }
                if (state is! CameraLoaded) return const SizedBox.shrink();

                final filtered = state.cameras
                    .where((camera) {
                      return camera.name.toLowerCase().contains(_searchQuery) ||
                          camera.ipAddress.toLowerCase().contains(
                            _searchQuery,
                          ) ||
                          camera.codec.toLowerCase().contains(_searchQuery);
                    })
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return VmsStateView.empty(
                    icon: _searchQuery.isEmpty
                        ? Icons.videocam_off_outlined
                        : Icons.search_off_rounded,
                    title: _searchQuery.isEmpty
                        ? 'No cameras registered'
                        : 'No matching cameras',
                    message: _searchQuery.isEmpty
                        ? 'Add a camera to begin live monitoring.'
                        : 'Try a different name, IP address, or codec.',
                    actionLabel: _searchQuery.isEmpty
                        ? 'Add camera'
                        : 'Clear search',
                    onAction: _searchQuery.isEmpty
                        ? _openAddCamera
                        : _searchController.clear,
                  );
                }

                final grouped = <String, List<Camera>>{};
                for (final camera in filtered) {
                  grouped.putIfAbsent(camera.siteId, () => []).add(camera);
                }
                final siteIds = grouped.keys.toList()..sort();
                final onlineCount = filtered
                    .where((camera) => camera.status == 'CONNECTED')
                    .length;

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<CameraBloc>().add(const FetchCameras());
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Row(
                            children: [
                              VmsStatusBadge(
                                label: '$onlineCount ONLINE',
                                color: VmsColors.success,
                                icon: Icons.circle,
                              ),
                              const SizedBox(width: 8),
                              VmsStatusBadge(
                                label: '${filtered.length} TOTAL',
                                color: VmsColors.information,
                                icon: Icons.videocam_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final siteId in siteIds) ...[
                        SliverToBoxAdapter(
                          child: _SiteHeader(
                            siteId: siteId,
                            cameraCount: grouped[siteId]!.length,
                          ),
                        ),
                        SliverList.separated(
                          itemCount: grouped[siteId]!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final camera = grouped[siteId]![index];
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                index == 0 ? 10 : 0,
                                16,
                                index == grouped[siteId]!.length - 1 ? 16 : 0,
                              ),
                              child: _CameraCard(
                                camera: camera,
                                onTap: () => _showCameraActions(camera),
                              ),
                            );
                          },
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const VmsNavigationBar(currentRoute: '/cameras'),
    );
  }

  void _showCameraActions(Camera camera) {
    final online = camera.status == 'CONNECTED';
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: VmsPageTitle(
                    title: camera.name,
                    subtitle: '${camera.ipAddress} · ${camera.codec}',
                  ),
                ),
                VmsStatusBadge(
                  label: online ? 'ONLINE' : 'OFFLINE',
                  color: online ? VmsColors.success : VmsColors.danger,
                  icon: online ? Icons.check_circle : Icons.cancel_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetadataChip(
                  icon: Icons.video_settings_outlined,
                  label: 'Profile ${camera.onvifProfile}',
                ),
                _MetadataChip(icon: Icons.memory_rounded, label: camera.codec),
                if (camera.hasSubStream)
                  const _MetadataChip(
                    icon: Icons.grid_view_rounded,
                    label: 'Adaptive sub-stream',
                  ),
                if (camera.ptzCapable)
                  const _MetadataChip(
                    icon: Icons.control_camera_rounded,
                    label: 'PTZ capable',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: online
                  ? () {
                      Navigator.pop(sheetContext);
                      context.go(
                        Uri(
                          path: '/live_grid',
                          queryParameters: {'cameraId': camera.id},
                        ).toString(),
                      );
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('OPEN LIVE VIEW'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: camera.usesDirectRtsp
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      context.go('/playback');
                    },
              icon: const Icon(Icons.history_rounded),
              label: const Text('OPEN PLAYBACK'),
            ),
            if (camera.usesDirectRtsp) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteCamera(camera);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('REMOVE FROM THIS PHONE'),
                style: TextButton.styleFrom(foregroundColor: VmsColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAddCamera() async {
    final cameraId = await context.push<String>('/cameras/add');
    if (!mounted || cameraId == null) return;
    context.read<CameraBloc>().add(const FetchCameras());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera saved securely on this phone.')),
    );
  }

  Future<void> _confirmDeleteCamera(Camera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove camera?'),
        content: Text('${camera.name} will be removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GetIt.instance<CameraRepository>().deleteLocalCamera(camera.id);
    if (!mounted) return;
    context.read<CameraBloc>().add(const FetchCameras());
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.siteId, required this.cameraCount});

  final String siteId;
  final int cameraCount;

  @override
  Widget build(BuildContext context) {
    final displayId = siteId.length > 10 ? siteId.substring(0, 10) : siteId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: VmsColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'SITE $displayId',
              style: const TextStyle(
                color: VmsColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            '$cameraCount ${cameraCount == 1 ? 'camera' : 'cameras'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera, required this.onTap});

  final Camera camera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = camera.status == 'CONNECTED';
    return VmsSurfaceCard(
      semanticLabel: '${camera.name}, ${online ? 'online' : 'offline'}',
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (online ? VmsColors.primary : VmsColors.textMuted)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VmsRadii.sm),
            ),
            child: Icon(
              camera.ptzCapable
                  ? Icons.control_camera_rounded
                  : Icons.videocam_outlined,
              color: online ? VmsColors.primary : VmsColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camera.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${camera.ipAddress} · ${camera.codec} · Profile ${camera.onvifProfile}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          VmsStatusBadge(
            label: online ? 'ONLINE' : 'OFFLINE',
            color: online ? VmsColors.success : VmsColors.danger,
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, color: VmsColors.textMuted),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}
