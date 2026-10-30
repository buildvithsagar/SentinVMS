import 'dart:async';
import 'dart:ui';

import 'package:app/core/core.dart';
import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:app/features/device_onboarding/presentation/widgets/onboarding_mode_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Ultra-Minimal Device Category Selection Screen
/// Featuring prominent hardware icons and single-word category labels.
class DeviceCategoryPage extends StatefulWidget {
  const DeviceCategoryPage({super.key});

  @override
  State<DeviceCategoryPage> createState() => _DeviceCategoryPageState();
}

class _DeviceCategoryPageState extends State<DeviceCategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static final List<_DeviceCategory> _allCategories = [
    _DeviceCategory(
      id: 'wireless_camera',
      name: 'Wireless',
      icon: Icons.wifi_tethering_rounded,
    ),
    _DeviceCategory(
      id: 'wired_camera',
      name: 'Wired',
      icon: Icons.videocam_rounded,
    ),
    _DeviceCategory(
      id: 'ptz_camera',
      name: 'PTZ',
      icon: Icons.center_focus_strong_rounded,
    ),
    _DeviceCategory(id: 'dvr_nvr', name: 'NVR', icon: Icons.dns_rounded),
    _DeviceCategory(
      id: 'edge_gateway',
      name: 'Edge',
      icon: Icons.memory_rounded,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_DeviceCategory> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return _allCategories;
    final query = _searchQuery.toLowerCase();
    return _allCategories.where((cat) {
      return cat.name.toLowerCase().contains(query) ||
          cat.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const baseCanvas = VmsColors.canvas;
    const primaryText = VmsColors.textPrimary;
    const mutedText = VmsColors.textSecondary;
    const glassBorder = VmsColors.border;

    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: baseCanvas,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.3,
            colors: [VmsColors.canvasRaised, VmsColors.canvas],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: VmsColors.surfaceHigh.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: glassBorder.withValues(alpha: 0.6),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: primaryText,
                          size: 22,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add Device',
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ── Minimal Search Bar ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: VmsColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: glassBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: primaryText, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        color: mutedText.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: mutedText,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: mutedText,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Minimal 2-Column Grid ───────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No hardware found',
                          style: TextStyle(
                            color: mutedText.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.05,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          return _MinimalCategoryGridCard(
                            category: cat,
                            onTap: () =>
                                _runSubnetOnvifScan(context, cat.id, cat.name),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const VmsNavigationBar(currentRoute: '/cameras'),
    );
  }

  Future<void> _runSubnetOnvifScan(
    BuildContext parentContext,
    String category,
    String categoryName,
  ) async {
    final nav = Navigator.of(parentContext, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: parentContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return const AlertDialog(
            backgroundColor: VmsColors.surface,
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(VmsColors.primary),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Probing Local Subnet (UDP 3702)...',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final repo = GetIt.instance<DeviceOnboardingRepository>();
      final devices = await repo.scanSubnetForOnvifDevices();
      if (!mounted) return;
      nav.pop();
      _showDiscoveredDevicesModal(context, category, categoryName, devices);
    } catch (_) {
      if (!mounted) return;
      nav.pop();
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (sheetContext) => OnboardingModeSheet(
            category: category,
            categoryName: categoryName,
          ),
        ),
      );
    }
  }

  void _showDiscoveredDevicesModal(
    BuildContext context,
    String category,
    String categoryName,
    List<DiscoveredOnvifDevice> devices,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VmsColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: Color(0xFF2DD4BF),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'DISCOVERED ONVIF DEVICES (${devices.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'LAN Subnet 192.168.1.0/24 • UDP WS-Discovery Port 3702',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (ctx, index) {
                    final dev = devices[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dev.manufacturer,
                                style: const TextStyle(
                                  color: Color(0xFF2DD4BF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${dev.latencyMs} ms',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dev.model,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'IP: ${dev.ipAddress}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dev.onvifProfile,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2DD4BF),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text(
                                'REGISTER THIS CAMERA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                showModalBottomSheet<void>(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (mCtx) => OnboardingModeSheet(
                                    category: category,
                                    categoryName:
                                        '${dev.manufacturer} (${dev.ipAddress})',
                                  ),
                                );
                              },
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
      },
    );
  }
}

class _DeviceCategory {
  _DeviceCategory({required this.id, required this.icon, String? name})
    : _rawName = name;

  final String id;
  final String? _rawName;
  final IconData icon;

  String get name {
    if (_rawName != null && _rawName.isNotEmpty) return _rawName;
    switch (id) {
      case 'wireless_camera':
        return 'Wireless';
      case 'wired_camera':
        return 'Wired';
      case 'ptz_camera':
        return 'PTZ';
      case 'dvr_nvr':
        return 'NVR';
      case 'edge_gateway':
        return 'Edge';
      default:
        return 'Camera';
    }
  }

  String get imageAsset {
    switch (id) {
      case 'wireless_camera':
        return 'assets/3d_wireless_camera.png';
      case 'wired_camera':
        return 'assets/3d_wired_camera.png';
      case 'ptz_camera':
        return 'assets/3d_ptz_camera.png';
      case 'dvr_nvr':
        return 'assets/3d_nvr.png';
      case 'edge_gateway':
        return 'assets/3d_edge_gateway.png';
      default:
        return 'assets/3d_wireless_camera.png';
    }
  }

  Color get accentColor {
    switch (id) {
      case 'wireless_camera':
        return const Color(0xFF10B981); // Emerald
      case 'wired_camera':
        return const Color(0xFF3B82F6); // Blue
      case 'ptz_camera':
        return const Color(0xFF8B5CF6); // Purple
      case 'dvr_nvr':
        return const Color(0xFFF59E0B); // Amber
      case 'edge_gateway':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFF38BDF8);
    }
  }
}

/// Minimal Grid Card with Prominent Icon and Single Word Label
class _MinimalCategoryGridCard extends StatefulWidget {
  const _MinimalCategoryGridCard({required this.category, required this.onTap});

  final _DeviceCategory category;
  final VoidCallback onTap;

  @override
  State<_MinimalCategoryGridCard> createState() =>
      _MinimalCategoryGridCardState();
}

class _MinimalCategoryGridCardState extends State<_MinimalCategoryGridCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const primaryText = VmsColors.textPrimary;
    const glassBorder = VmsColors.border;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    VmsColors.surfaceHigh.withValues(
                      alpha: _isPressed ? 1 : 0.9,
                    ),
                    VmsColors.surface.withValues(alpha: _isPressed ? 1 : 0.94),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? widget.category.accentColor
                      : glassBorder.withValues(alpha: 0.7),
                  width: _isPressed ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? widget.category.accentColor.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: _isPressed ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Prominent 3D / Vector Icon Tile
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.category.accentColor.withValues(alpha: 0.25),
                          VmsColors.canvas,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.category.accentColor.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.category.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          blurRadius: 14,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        widget.category.imageAsset,
                        width: 54,
                        height: 54,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            widget.category.icon,
                            color: widget.category.accentColor,
                            size: 34,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Single Word Category Label
                  Text(
                    widget.category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
