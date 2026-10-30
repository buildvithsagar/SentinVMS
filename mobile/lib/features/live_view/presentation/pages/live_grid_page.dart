import 'dart:async';

import 'package:app/core/core.dart';
import 'package:app/features/alarms/alarms.dart';
import 'package:app/features/camera/camera.dart';
import 'package:app/features/live_view/live_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class LiveGridPage extends StatefulWidget {
  const LiveGridPage({this.initialCameraId, super.key});

  final String? initialCameraId;

  @override
  State<LiveGridPage> createState() => _LiveGridPageState();
}

class _LiveGridPageState extends State<LiveGridPage> {
  final List<Camera?> _gridCameras = List<Camera?>.filled(16, null);
  int _layoutGridSize = 2; // 1 for 1x1, 2 for 2x2, 3 for 3x3, 4 for 4x4
  int _selectedSlotIndex = 0;

  bool _isPanicOverlayActive = false;
  int _panicCountdown = 5;
  Timer? _panicTimer;
  StreamSubscription<CameraState>? _cameraStateSubscription;
  String? _pendingCameraId;

  bool _isPTZActive = false;
  bool _isAlarmPanelExpanded = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _pendingCameraId = widget.initialCameraId;
    _cameraStateSubscription = context.read<CameraBloc>().stream.listen(
      _applyPendingCamera,
    );
    // Dispatch fetch event early so cameras are available when user opens picker
    context.read<CameraBloc>().add(const FetchCameras());
  }

  @override
  void dispose() {
    _panicTimer?.cancel();
    _cameraStateSubscription?.cancel();
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _applyPendingCamera(CameraState state) {
    final cameraId = _pendingCameraId;
    if (cameraId == null || state is! CameraLoaded || !mounted) return;
    final matches = state.cameras.where((camera) => camera.id == cameraId);
    if (matches.isEmpty) return;
    setState(() {
      _gridCameras[_selectedSlotIndex] = matches.first;
      _layoutGridSize = 1;
      _pendingCameraId = null;
    });
  }

  Future<void> _openAddCamera() async {
    final cameraId = await context.push<String>('/cameras/add');
    if (!mounted || cameraId == null) return;
    setState(() => _pendingCameraId = cameraId);
    final cameraBloc = context.read<CameraBloc>();
    _applyPendingCamera(cameraBloc.state);
    if (_pendingCameraId != null) cameraBloc.add(const FetchCameras());
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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

  void _confirmClearAllSlots() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Clear All Feeds',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to clear all active camera streams?',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              key: const Key('confirmClearAllButton'),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  for (var i = 0; i < _gridCameras.length; i++) {
                    _gridCameras[i] = null;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All viewports cleared.')),
                );
              },
              child: const Text(
                'CLEAR ALL',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startPanicCountdown(String protocol) {
    setState(() {
      _isPanicOverlayActive = true;
      _panicCountdown = 5;
    });
    _panicTimer?.cancel();
    _panicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_panicCountdown > 1) {
        setState(() {
          _panicCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _panicCountdown = 0;
        });
        try {
          GetIt.instance<CameraRepository>().dispatchEmergencyPanic(
            protocol: protocol,
            operatorId: 'operator-mobile-01',
          );
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 $protocol DISPATCHED TO CONTROL ROOM!'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    });
  }

  void _showPanicDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'EMERGENCY PANIC ALERT',
            style: TextStyle(
              color: VmsColors.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Select action to dispatch emergency protocols:',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startPanicCountdown('EMERGENCY SIREN');
              },
              child: const Text(
                'TRIGGER SIREN',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startPanicCountdown('SILENT PANIC ALARM');
              },
              child: const Text(
                'SILENT DISPATCH',
                style: TextStyle(color: Color(0xFFF59E0B)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startPanicCountdown('CONTROL ROOM ALARM');
              },
              child: const Text(
                'CALL CONTROL ROOM',
                style: TextStyle(color: Color(0xFF2DD4BF)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCameraPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: context.read<CameraBloc>(),
          child: _CameraPickerContent(
            onAddCamera: () {
              Navigator.pop(bottomSheetContext);
              _openAddCamera();
            },
            onSelected: (camera) {
              setState(() {
                _gridCameras[_selectedSlotIndex] = camera;
              });
              Navigator.pop(bottomSheetContext);
            },
            currentlyAssigned: _gridCameras
                .whereType<Camera>()
                .map((c) => c.id)
                .toSet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isFullScreen) {
            _toggleFullScreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _layoutGridSize == 4
                      ? _build4x4Grid()
                      : _layoutGridSize == 3
                      ? _build3x3Grid()
                      : _layoutGridSize == 2
                      ? _build2x2Grid()
                      : _build1x1Focus(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_layoutGridSize == 1) {
                                _layoutGridSize = 2;
                              } else if (_layoutGridSize == 2) {
                                _layoutGridSize = 3;
                              } else if (_layoutGridSize == 3) {
                                _layoutGridSize = 4;
                              } else {
                                _layoutGridSize = 1;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2DD4BF,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _layoutGridSize == 1
                                  ? '[1]'
                                  : _layoutGridSize == 2
                                  ? '[4]'
                                  : _layoutGridSize == 3
                                  ? '[9]'
                                  : '[16]',
                              style: const TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('exitFullscreenLandscapeButton'),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.fullscreen_exit,
                            color: Colors.white,
                          ),
                          tooltip: 'Exit Fullscreen',
                          onPressed: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      drawer: const VmsDrawer(currentRoute: '/live_grid'),
      appBar: AppBar(
        title: const VmsPageTitle(
          title: 'Live monitoring',
          subtitle: 'Select a viewport to manage its camera',
        ),
        actions: [
          IconButton(
            key: const Key('clearAllStreamsButton'),
            icon: const Icon(Icons.layers_clear_rounded),
            tooltip: 'Clear all viewports',
            onPressed: _confirmClearAllSlots,
          ),
          IconButton(
            key: const Key('panicAlertButton'),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
            ),
            tooltip: 'Emergency Panic Alert',
            onPressed: _showPanicDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Slot status / Camera assign bar
              Builder(
                builder: (context) {
                  final camera = _gridCameras[_selectedSlotIndex];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: camera == null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                key: const Key('assignCameraButtonTop'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VmsColors.primary,
                                  foregroundColor: const Color(0xFF03201B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Color(0xFF03201B),
                                ),
                                label: const Text(
                                  'Assign Camera',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF03201B),
                                  ),
                                ),
                                onPressed: () => _showCameraPicker(context),
                              ),
                              IconButton(
                                key: const Key('addDeviceTopButtonRight'),
                                style: IconButton.styleFrom(
                                  backgroundColor: VmsColors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: VmsColors.primary.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: VmsColors.primary,
                                ),
                                tooltip: 'Add New Camera Device',
                                onPressed: _openAddCamera,
                              ),
                            ],
                          )
                        : Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: VmsColors.surface,
                              borderRadius: BorderRadius.circular(VmsRadii.sm),
                              border: Border.all(color: VmsColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.videocam,
                                        size: 16,
                                        color: VmsColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Slot ${_selectedSlotIndex + 1}: ${camera.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: VmsColors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 14,
                                        color: Color(0xFF2DD4BF),
                                      ),
                                      label: const Text(
                                        'Change',
                                        style: TextStyle(
                                          color: Color(0xFF2DD4BF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showCameraPicker(context),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      key: const Key(
                                        'addDeviceSlotButtonRight',
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Color(0xFF2DD4BF),
                                      ),
                                      tooltip:
                                          'Add / Onboard New Camera Device',
                                      onPressed: _openAddCamera,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  );
                },
              ),

              // Main Viewport Area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: _layoutGridSize == 4
                      ? _build4x4Grid()
                      : _layoutGridSize == 3
                      ? _build3x3Grid()
                      : _layoutGridSize == 2
                      ? _build2x2Grid()
                      : _build1x1Focus(),
                ),
              ),

              // Grid Toolbars Row 1 & 2
              _buildGridToolbars(),

              // Sliding Alarm Messages Panel
              _buildAlarmPanel(),
            ],
          ),
          if (_isPanicOverlayActive)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.95),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gpp_bad,
                      size: 80,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'EMERGENCY DISPATCH IN PROGRESS',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _panicCountdown > 0
                          ? 'Notifying authorities in $_panicCountdown seconds...'
                          : 'AUTHORITIES NOTIFIED - LIVE VIDEO ENGAGED',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    if (_panicCountdown > 0)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          _panicTimer?.cancel();
                          setState(() {
                            _isPanicOverlayActive = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dispatch cancelled by operator.'),
                            ),
                          );
                        },
                        child: const Text('CANCEL DISPATCH'),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPanicOverlayActive = false;
                          });
                        },
                        child: const Text('DISMISS OVERLAY'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const VmsNavigationBar(currentRoute: '/live_grid'),
    );
  }

  Widget _buildMatrixGrid(int gridSize) {
    if (gridSize == 1) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildGridSlot(_selectedSlotIndex),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            childAspectRatio: 16 / 9,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) => _buildGridSlot(index),
        ),
      ),
    );
  }

  Widget _build2x2Grid() => _buildMatrixGrid(2);
  Widget _build3x3Grid() => _buildMatrixGrid(3);
  Widget _build4x4Grid() => _buildMatrixGrid(4);
  Widget _build1x1Focus() => _buildMatrixGrid(1);

  Widget _buildGridSlot(int index) {
    final camera = _gridCameras[index];
    final isSelected = _selectedSlotIndex == index;

    return GestureDetector(
      onTap: () {
        _selectSlot(index);
        if (camera == null) {
          _showCameraPicker(context);
        } else {
          // Expand to 1x1 Single Camera Screen View when clicking an assigned camera
          if (_layoutGridSize > 1) {
            setState(() {
              _layoutGridSize = 1;
            });
          }
        }
      },
      child: _PulsingSelectionBorder(
        isSelected: isSelected,
        child: camera == null
            ? CustomPaint(
                painter: _DashedBorderPainter(
                  color: isSelected
                      ? const Color(0xFF2DD4BF)
                      : Colors.white.withValues(alpha: 0.12),
                ),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.03),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 6,
                        left: 8,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF2DD4BF).withValues(alpha: 0.8)
                                : const Color(
                                    0xFF94A3B8,
                                  ).withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          Icons.add,
                          color: isSelected
                              ? const Color(0xFF2DD4BF)
                              : const Color(0xFF94A3B8).withValues(alpha: 0.4),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  VideoTile(
                    key: ValueKey('video_tile_${camera.id}_$index'),
                    camera: camera,
                    cameraRepository: GetIt.instance<CameraRepository>(),
                    decoderPool: GetIt.instance<DecoderPool>(),
                    webRtcService: GetIt.instance.isRegistered<WebRtcService>()
                        ? GetIt.instance<WebRtcService>()
                        : const WebRtcService(),
                    showPtzOverlay: _layoutGridSize == 1 && _isPTZActive,
                    gridDimension: _layoutGridSize,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGridToolbars() {
    final camera = _gridCameras[_selectedSlotIndex];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: VmsColors.surface,
        border: Border(top: BorderSide(color: VmsColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InkWell(
                key: const Key('layoutCyclerButton'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _layoutGridSize = switch (_layoutGridSize) {
                      1 => 2,
                      2 => 3,
                      3 => 4,
                      _ => 1,
                    };
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: VmsColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VmsRadii.sm),
                    border: Border.all(
                      color: VmsColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        color: VmsColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_layoutGridSize}x$_layoutGridSize',
                        style: const TextStyle(
                          color: VmsColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (camera != null)
                IconButton(
                  tooltip: 'Open playback',
                  onPressed: () => context.go('/playback'),
                  icon: const Icon(Icons.history_rounded),
                ),
              if (camera?.ptzCapable ?? false)
                IconButton(
                  tooltip: 'PTZ controls',
                  onPressed: () {
                    setState(() {
                      _layoutGridSize = 1;
                      _isPTZActive = !_isPTZActive;
                    });
                  },
                  icon: Icon(
                    _isPTZActive
                        ? Icons.center_focus_strong
                        : Icons.center_focus_weak,
                    color: _isPTZActive
                        ? VmsColors.primary
                        : VmsColors.textSecondary,
                  ),
                ),
              IconButton(
                key: const Key('fullscreenButton'),
                tooltip: _isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
          if (camera != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: VmsColors.surfaceHigh,
                borderRadius: BorderRadius.circular(VmsRadii.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam,
                    color: VmsColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Camera: ${camera.name} (${camera.ipAddress})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VmsColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove camera from slot',
                    icon: const Icon(Icons.close, color: VmsColors.danger),
                    onPressed: () => _clearSlot(_selectedSlotIndex),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlarmPanel() {
    return Container(
      decoration: BoxDecoration(
        color: VmsColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VmsRadii.lg),
        ),
        border: Border.all(color: VmsColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle/Top bar
          InkWell(
            onTap: () {
              setState(() {
                _isAlarmPanelExpanded = !_isAlarmPanelExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: VmsColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Alarm Message',
                    style: TextStyle(
                      color: VmsColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: VmsColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isAlarmPanelExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: VmsColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_isAlarmPanelExpanded)
            Container(
              height: 200,
              color: VmsColors.canvas,
              child: BlocBuilder<AlarmBloc, AlarmState>(
                builder: (context, state) {
                  if (state is AlarmLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          VmsColors.primary,
                        ),
                      ),
                    );
                  }
                  if (state is AlarmError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(
                          color: VmsColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  if (state is AlarmLoaded) {
                    final alarms = state.alarms;
                    if (alarms.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              color: VmsColors.textMuted,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No message',
                              style: TextStyle(
                                color: VmsColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: alarms.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        final isAck = alarm.status == 'ACKNOWLEDGED';
                        final timeStr = DateFormat(
                          'HH:mm:ss',
                        ).format(alarm.timestamp);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAck
                                  ? VmsColors.success
                                  : VmsColors.danger,
                            ),
                          ),
                          title: Text(
                            alarm.eventClass,
                            style: const TextStyle(
                              color: VmsColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${alarm.cameraName} • $timeStr',
                            style: const TextStyle(
                              color: VmsColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                          trailing: isAck
                              ? const Text(
                                  'ACK',
                                  style: TextStyle(
                                    color: VmsColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                )
                              : TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    context.read<AlarmBloc>().add(
                                      AlarmAcknowledged(alarmId: alarm.id),
                                    );
                                  },
                                  child: const Text(
                                    'ACK',
                                    style: TextStyle(
                                      color: VmsColors.danger,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                        );
                      },
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No message',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraPickerContent extends StatefulWidget {
  const _CameraPickerContent({
    required this.onSelected,
    required this.currentlyAssigned,
    required this.onAddCamera,
  });

  final ValueChanged<Camera> onSelected;
  final Set<String> currentlyAssigned;
  final VoidCallback onAddCamera;

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
    return Material(
      color: VmsColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VmsRadii.lg),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: VmsColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Camera for Slot',
                    style: TextStyle(
                      color: VmsColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.add,
                      size: 20,
                      color: VmsColors.primary,
                    ),
                    tooltip: 'Add New Camera Device',
                    onPressed: () {
                      widget.onAddCamera();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: VmsColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name or IP...',
                  hintStyle: const TextStyle(color: VmsColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: VmsColors.textMuted,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: VmsColors.textMuted,
                          ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          VmsColors.primary,
                        ),
                      ),
                    );
                  }
                  if (state is CameraError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: VmsColors.danger),
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
                          style: TextStyle(color: VmsColors.textMuted),
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
                        final displaySiteId = siteId.length > 8
                            ? siteId.substring(0, 8)
                            : siteId;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: VmsColors.surfaceHigh,
                              child: Text(
                                'SITE ID: $displaySiteId',
                                style: const TextStyle(
                                  color: VmsColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...siteCameras.map((camera) {
                              final isAssigned = widget.currentlyAssigned
                                  .contains(camera.id);
                              final isOnline = camera.status == 'CONNECTED';

                              return ListTile(
                                enabled: !isAssigned && isOnline,
                                title: Text(
                                  camera.name,
                                  style: TextStyle(
                                    color: isAssigned
                                        ? Colors.white24
                                        : VmsColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'IP: ${camera.ipAddress} • ${camera.codec}',
                                  style: const TextStyle(
                                    color: VmsColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                leading: Icon(
                                  camera.ptzCapable
                                      ? Icons.settings_backup_restore
                                      : Icons.videocam,
                                  color: isAssigned
                                      ? Colors.white24
                                      : VmsColors.textSecondary,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isAssigned) ...[
                                      const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: VmsColors.primary,
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
                                        color: isOnline
                                            ? VmsColors.success
                                            : VmsColors.danger,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOnline ? 'ONLINE' : 'OFFLINE',
                                      style: TextStyle(
                                        color: isOnline
                                            ? VmsColors.success
                                            : VmsColors.danger,
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

class _PulsingSelectionBorder extends StatelessWidget {
  const _PulsingSelectionBorder({
    required this.child,
    required this.isSelected,
  });

  final Widget child;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    if (!isSelected) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2DD4BF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.16),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}
