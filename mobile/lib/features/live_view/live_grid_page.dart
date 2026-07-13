import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/bloc/alarm_state.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/live_view/widgets/video_tile.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class LiveGridPage extends StatefulWidget {
  const LiveGridPage({super.key});

  @override
  State<LiveGridPage> createState() => _LiveGridPageState();
}

class _LiveGridPageState extends State<LiveGridPage> {
  final List<Camera?> _gridCameras = List<Camera?>.filled(9, null);
  int _layoutGridSize = 2; // 1 for 1x1, 2 for 2x2, 3 for 3x3
  int _selectedSlotIndex = 0;

  final List<bool> _instantPlaybackSlots = List<bool>.filled(9, false);
  bool _isPanicOverlayActive = false;
  int _panicCountdown = 5;
  Timer? _panicTimer;

  bool _isPlaying = true;
  bool _isQualityHD = false;
  bool _isMuted = false;
  bool _isStarred = false;
  bool _isMicActive = false;
  bool _isRecording = false;
  bool _isPTZActive = false;
  bool _isAlarmPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    // Dispatch fetch event early so cameras are available when user opens picker
    context.read<CameraBloc>().add(const FetchCameras());
  }

  @override
  void dispose() {
    _panicTimer?.cancel();
    super.dispose();
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
          title: const Text('Clear All Feeds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to clear all active camera streams?', style: TextStyle(color: Color(0xFF94A3B8))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
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
              child: const Text('CLEAR ALL', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        );
      },
    );
  }

  void _showSnapshotPreviewDialog(String cameraName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.camera_alt, color: Color(0xFF2DD4BF)),
              SizedBox(width: 8),
              Text('Snapshot Captured', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Frame captured from $cameraName', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.white30, size: 40),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening system sharing panel...')),
                );
              },
              child: const Text('SHARE', style: TextStyle(color: Color(0xFF2DD4BF))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Snapshot saved to phone album.')),
                );
              },
              child: const Text('SAVE TO ALBUM', style: TextStyle(color: Color(0xFF10B981))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
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
      if (!mounted) return;
      if (_panicCountdown > 1) {
        setState(() {
          _panicCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _panicCountdown = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$protocol DISPATCHED TO CONTROL ROOM!'),
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
          title: const Text('EMERGENCY PANIC ALERT', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
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
              child: const Text('TRIGGER SIREN', style: TextStyle(color: Color(0xFFEF4444))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startPanicCountdown('CONTROL ROOM ALARM');
              },
              child: const Text('CALL CONTROL ROOM', style: TextStyle(color: Color(0xFF2DD4BF))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
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
      backgroundColor: const Color(0xFF0F172A),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.security,
                    color: Color(0xFF2DD4BF),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SENTINEL VMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Operator Session',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view, color: Color(0xFF2DD4BF)),
              title: const Text('Live Grid Dashboard', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              key: const Key('drawerLogoutButton'),
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () async {
                Navigator.pop(context);
                await _handleLogout();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Live Viewport Grid',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('clearAllStreamsButton'),
            icon: const Icon(Icons.layers_clear, color: Color(0xFF94A3B8)),
            tooltip: 'Clear All Streams',
            onPressed: _confirmClearAllSlots,
          ),
          IconButton(
            key: const Key('panicAlertButton'),
            icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
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
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              key: const Key('assignCameraButtonTop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.add, size: 14, color: Colors.white),
                              label: const Text(
                                'Assign Camera',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              onPressed: () => _showCameraPicker(context),
                            ),
                          )
                        : Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.videocam, size: 16, color: Color(0xFF2DD4BF)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Slot ${_selectedSlotIndex + 1}: ${camera.name}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF2DD4BF)),
                                  label: const Text(
                                    'Change',
                                    style: TextStyle(
                                      color: Color(0xFF2DD4BF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _showCameraPicker(context),
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
                  padding: const EdgeInsets.all(8),
                  child: _layoutGridSize == 3
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
              child: Container(
                color: Colors.black.withOpacity(0.95),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gpp_bad, size: 80, color: Color(0xFFEF4444)),
                    const SizedBox(height: 24),
                    const Text(
                      'EMERGENCY DISPATCH IN PROGRESS',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          _panicTimer?.cancel();
                          setState(() {
                            _isPanicOverlayActive = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dispatch cancelled by operator.')),
                          );
                        },
                        child: const Text('CANCEL DISPATCH'),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  backgroundColor: Colors.transparent,
                  selectedItemColor: const Color(0xFF2DD4BF),
                  unselectedItemColor: const Color(0xFF94A3B8),
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) {
                    if (index == 0) {
                      // Already here
                    } else if (index == 1) {
                      context.go('/cameras');
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

  Widget _build2x2Grid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 16 / 9,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(4, _buildGridSlot),
    );
  }

  Widget _build3x3Grid() {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 16 / 9,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: List.generate(9, _buildGridSlot),
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
                                : const Color(0xFF94A3B8).withValues(alpha: 0.5),
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
                    camera: camera,
                    cameraRepository: GetIt.instance<CameraRepository>(),
                    decoderPool: GetIt.instance<DecoderPool>(),
                  ),
                  if (_instantPlaybackSlots[index])
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.55),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'INSTANT PLAYBACK -30s',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildGridToolbars() {
    final camera = _gridCameras[_selectedSlotIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Grid Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isQualityHD = !_isQualityHD;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isQualityHD
                            ? 'Switched to HD (Clear Stream)'
                            : 'Switched to SD (Fluent Stream)',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _isQualityHD ? 'HD' : 'SD',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _isStarred ? Icons.star : Icons.star_border,
                  color: _isStarred ? const Color(0xFF2DD4BF) : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isStarred = !_isStarred;
                  });
                },
              ),
              // Grid Size Indicator Badge (Tappable layout cyclist)
              GestureDetector(
                key: const Key('layoutCyclerButton'),
                onTap: () {
                  setState(() {
                    if (_layoutGridSize == 1) {
                      _layoutGridSize = 2;
                    } else if (_layoutGridSize == 2) {
                      _layoutGridSize = 3;
                    } else {
                      _layoutGridSize = 1;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _layoutGridSize == 1 ? '[1]' : _layoutGridSize == 2 ? '[4]' : '[9]',
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fullscreen view triggered')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Tactical Actions
          Row(
            children: [
              // Playback Quick Action Button (White background, Red text)
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    context.push('/playback');
                  },
                  child: const Text(
                    'Playback',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Talkback
              IconButton(
                icon: Icon(
                  _isMicActive ? Icons.mic : Icons.mic_none,
                  color: _isMicActive ? const Color(0xFF2DD4BF) : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isMicActive = !_isMicActive;
                  });
                },
              ),
              // Local Record
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.fiber_manual_record : Icons.videocam_outlined,
                  color: _isRecording ? const Color(0xFFEF4444) : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isRecording = !_isRecording;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isRecording
                            ? 'Local recording started...'
                            : 'Recording saved to gallery!',
                      ),
                    ),
                  );
                },
              ),
              // Snapshot
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                onPressed: () {
                  _showSnapshotPreviewDialog(camera?.name ?? 'Live Feed');
                },
              ),
              // Instant Playback
              IconButton(
                key: const Key('instantPlaybackButton'),
                icon: Icon(
                  Icons.replay_30,
                  color: _instantPlaybackSlots[_selectedSlotIndex] ? const Color(0xFF2DD4BF) : Colors.white,
                ),
                tooltip: 'Instant Playback (30s rewind)',
                onPressed: () {
                  setState(() {
                    _instantPlaybackSlots[_selectedSlotIndex] = !_instantPlaybackSlots[_selectedSlotIndex];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _instantPlaybackSlots[_selectedSlotIndex]
                            ? 'Instant Playback Mode Engaged (Rewinding 30s)...'
                            : 'Returned to Live feed.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              // PTZ crosshair centering
              IconButton(
                icon: Icon(
                  _isPTZActive ? Icons.center_focus_strong : Icons.center_focus_weak,
                  color: _isPTZActive ? const Color(0xFF2DD4BF) : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isPTZActive = !_isPTZActive;
                  });
                },
              ),
            ],
          ),
          // Clean active camera status label if assigned
          if (camera != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Color(0xFF2DD4BF), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Camera: ${camera.name} (${camera.ipAddress})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
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
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white12),
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
                  const Icon(Icons.notifications_active_outlined, color: Color(0xFF2DD4BF), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Alarm Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 16),
                  const SizedBox(width: 8),
                  Icon(
                    _isAlarmPanelExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          if (_isAlarmPanelExpanded)
            Container(
              height: 200,
              color: const Color(0xFF0F172A),
              child: BlocBuilder<AlarmBloc, AlarmState>(
                builder: (context, state) {
                  if (state is AlarmLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                      ),
                    );
                  }
                  if (state is AlarmError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                      ),
                    );
                  }
                  if (state is AlarmLoaded) {
                    final alarms = state.alarms;
                    if (alarms.isEmpty) {
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
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: alarms.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        final isAck = alarm.status == 'ACKNOWLEDGED';
                        final timeStr = DateFormat('HH:mm:ss').format(alarm.timestamp);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAck ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          title: Text(
                            alarm.eventClass,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${alarm.cameraName} • $timeStr',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                          trailing: isAck
                              ? const Text(
                                  'ACK',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                )
                              : TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    context.read<AlarmBloc>().add(
                                          AlarmAcknowledged(alarmId: alarm.id),
                                        );
                                  },
                                  child: const Text(
                                    'ACK',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
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
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Camera for Slot',
            style: TextStyle(
              color: Colors.white,
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or IP...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                    ),
                  );
                }
                if (state is CameraError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Color(0xFFEF4444)),
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
                        style: TextStyle(color: Color(0xFF94A3B8)),
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
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Text(
                              'SITE ID: $displaySiteId',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
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
                                      ? Colors.white24
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'IP: ${camera.ipAddress} • ${camera.codec}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              leading: Icon(
                                camera.ptzCapable ? Icons.settings_backup_restore : Icons.videocam,
                                color: isAssigned ? Colors.white24 : const Color(0xFF94A3B8),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAssigned) ...[
                                    const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFF2DD4BF),
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
                                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOnline ? 'ONLINE' : 'OFFLINE',
                                    style: TextStyle(
                                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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

class _PulsingSelectionBorder extends StatefulWidget {
  const _PulsingSelectionBorder({
    required this.child,
    required this.isSelected,
  });

  final Widget child;
  final bool isSelected;

  @override
  State<_PulsingSelectionBorder> createState() => _PulsingSelectionBorderState();
}

class _PulsingSelectionBorderState extends State<_PulsingSelectionBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isSelected && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingSelectionBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        if (!Platform.environment.containsKey('FLUTTER_TEST')) {
          _controller.repeat(reverse: true);
        }
      } else {
        _controller
          ..stop()
          ..value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelected) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = 0.3 + (_controller.value * 0.4);
        final borderThickness = 1.5 + (_controller.value * 1.0);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF2DD4BF).withValues(alpha: glowOpacity),
              width: borderThickness,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DD4BF).withValues(alpha: glowOpacity * 0.25),
                blurRadius: 4.0 + (_controller.value * 6.0),
                spreadRadius: 0.5 + (_controller.value * 1.0),
              )
            ],
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
