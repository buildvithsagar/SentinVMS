import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/live_view/widgets/video_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class LiveGridPage extends StatefulWidget {
  const LiveGridPage({super.key});

  @override
  State<LiveGridPage> createState() => _LiveGridPageState();
}

class _LiveGridPageState extends State<LiveGridPage> {
  final List<Camera?> _gridCameras = List<Camera?>.filled(4, null);
  bool _is2x2 = true;
  int _selectedSlotIndex = 0;

  @override
  void initState() {
    super.initState();
    // Dispatch fetch event early so cameras are available when user opens picker
    context.read<CameraBloc>().add(const FetchCameras());
  }

  void _selectSlot(int index) {
    setState(() {
      _selectedSlotIndex = index;
    });
  }

  void _clearSlot(int index) {
    setState(() {
      _gridCameras[index] = null;
    });
  }

  void _clearAllSlots() {
    setState(() {
      for (var i = 0; i < _gridCameras.length; i++) {
        _gridCameras[i] = null;
      }
    });
  }

  void _showCameraPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14161F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: context.read<CameraBloc>(),
          child: _CameraPickerContent(
            onSelected: (camera) {
              setState(() {
                _gridCameras[_selectedSlotIndex] = camera;
              });
              Navigator.pop(bottomSheetContext);
            },
            currentlyAssigned: _gridCameras.whereType<Camera>().map((c) => c.id).toSet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14161F),
        elevation: 0,
        title: const Text(
          'Live Viewport Grid',
          style: TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_clear, color: Color(0xFF70788C)),
            tooltip: 'Clear All Streams',
            onPressed: _clearAllSlots,
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Bar: Layout toggle and Quick Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _is2x2
                      ? 'Layout: 2x2 Grid (4 Feeds)'
                      : 'Layout: 1x1 Focus (Single Feed)',
                  style: const TextStyle(
                    color: Color(0xFF70788C),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.rectangle_outlined,
                        color: !_is2x2 ? const Color(0xFF02965E) : const Color(0xFF70788C),
                      ),
                      tooltip: '1x1 View',
                      onPressed: () {
                        setState(() {
                          _is2x2 = false;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.grid_view,
                        color: _is2x2 ? const Color(0xFF02965E) : const Color(0xFF70788C),
                      ),
                      tooltip: '2x2 View',
                      onPressed: () {
                        setState(() {
                          _is2x2 = true;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Viewport Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _is2x2 ? _build2x2Grid() : _build1x1Focus(),
            ),
          ),

          // Selected Slot Control Panel
          _buildControlPanel(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF14161F),
        selectedItemColor: const Color(0xFF02965E),
        unselectedItemColor: const Color(0xFF70788C),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            // Already here
          } else if (index == 1) {
            context.go('/cameras');
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

  Widget _build2x2Grid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 16 / 9,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(4, _buildGridSlot),
    );
  }

  Widget _build1x1Focus() {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildGridSlot(_selectedSlotIndex),
      ),
    );
  }

  Widget _buildGridSlot(int index) {
    final camera = _gridCameras[index];
    final isSelected = _selectedSlotIndex == index;

    return GestureDetector(
      onTap: () => _selectSlot(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF02965E) : const Color(0x00000000),
            width: 2,
          ),
        ),
        child: camera == null
            ? CustomPaint(
                painter: _DashedBorderPainter(
                  color: isSelected ? const Color(0xFF02965E) : const Color(0xFF70788C),
                ),
                child: ColoredBox(
                  color: const Color(0xFF14161F),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: isSelected ? const Color(0xFF02965E) : const Color(0xFF70788C),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Slot ${index + 1}: Empty',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFE2E8F0) : const Color(0xFF70788C),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : VideoTile(
                camera: camera,
                cameraRepository: GetIt.instance<CameraRepository>(),
                decoderPool: GetIt.instance<DecoderPool>(),
              ),
      ),
    );
  }

  Widget _buildControlPanel() {
    final camera = _gridCameras[_selectedSlotIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF14161F),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SLOT ${_selectedSlotIndex + 1} SELECTED',
                    style: const TextStyle(
                      color: Color(0xFF70788C),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    camera != null ? camera.name : 'No Camera Assigned',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (camera != null) ...[
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFFD32F2F)),
                tooltip: 'Clear Slot',
                onPressed: () => _clearSlot(_selectedSlotIndex),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.videocam, size: 16),
              label: Text(camera != null ? 'Change' : 'Select'),
              onPressed: () => _showCameraPicker(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPickerContent extends StatefulWidget {
  const _CameraPickerContent({
    required this.onSelected,
    required this.currentlyAssigned,
  });

  final ValueChanged<Camera> onSelected;
  final Set<String> currentlyAssigned;

  @override
  State<_CameraPickerContent> createState() => _CameraPickerContentState();
}

class _CameraPickerContentState extends State<_CameraPickerContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF70788C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Camera for Slot',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: InputDecoration(
                hintText: 'Search by name or IP...',
                hintStyle: const TextStyle(color: Color(0xFF70788C)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF70788C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF70788C)),
                        onPressed: _searchController.clear,
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // List of Cameras
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
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Color(0xFFD32F2F)),
                    ),
                  );
                }
                if (state is CameraLoaded) {
                  final cameras = state.cameras;
                  final filtered = cameras.where((camera) {
                    final query = _searchQuery.trim().toLowerCase();
                    return camera.name.toLowerCase().contains(query) ||
                        camera.ipAddress.toLowerCase().contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No cameras found',
                        style: TextStyle(color: Color(0xFF70788C)),
                      ),
                    );
                  }

                  // Group by siteId
                  final grouped = <String, List<Camera>>{};
                  for (final cam in filtered) {
                    grouped.putIfAbsent(cam.siteId, () => []).add(cam);
                  }
                  final siteIds = grouped.keys.toList()..sort();

                  return ListView.builder(
                    itemCount: siteIds.length,
                    itemBuilder: (context, index) {
                      final siteId = siteIds[index];
                      final siteCameras = grouped[siteId]!;
                      final displaySiteId = siteId.length > 8 ? siteId.substring(0, 8) : siteId;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: const Color(0xFF0D0E12),
                            child: Text(
                              'SITE ID: $displaySiteId',
                              style: const TextStyle(
                                color: Color(0xFF70788C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...siteCameras.map((camera) {
                            final isAssigned = widget.currentlyAssigned.contains(camera.id);
                            final isOnline = camera.status == 'CONNECTED';

                            return ListTile(
                              enabled: !isAssigned && isOnline,
                              title: Text(
                                camera.name,
                                style: TextStyle(
                                  color: isAssigned
                                      ? const Color(0xFF70788C)
                                      : const Color(0xFFE2E8F0),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'IP: ${camera.ipAddress} • ${camera.codec}',
                                style: const TextStyle(
                                  color: Color(0xFF70788C),
                                  fontSize: 12,
                                ),
                              ),
                              leading: Icon(
                                camera.ptzCapable ? Icons.settings_backup_restore : Icons.videocam,
                                color: isAssigned ? const Color(0x2670788C) : const Color(0xFF70788C),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAssigned) ...[
                                    const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFF02965E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline ? const Color(0xFF02965E) : const Color(0xFFD32F2F),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOnline ? 'ONLINE' : 'OFFLINE',
                                    style: TextStyle(
                                      color: isOnline ? const Color(0xFF02965E) : const Color(0xFFD32F2F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => widget.onSelected(camera),
                            );
                          }),
                        ],
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 3.0;

    // Draw top
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
    // Draw right
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(size.width, (startY + dashWidth).clamp(0, size.height)),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
    // Draw bottom
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset((startX + dashWidth).clamp(0, size.width), size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
    // Draw left
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, (startY + dashWidth).clamp(0, size.height)),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
