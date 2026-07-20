import 'package:app/features/device_onboarding/presentation/widgets/onboarding_mode_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeviceCategoryPage extends StatelessWidget {
  const DeviceCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Tactical Theme Colors
    const primaryBg = Color(0xFF0D0E12);
    const panelBg = Color(0xFF14161F);
    const primaryText = Color(0xFFE2E8F0);
    const mutedText = Color(0xFF70788C);
    const accentGreen = Color(0xFF02965E);

    final categories = [
      _DeviceCategory(
        id: 'wireless_camera',
        title: 'Wireless Camera',
        icon: Icons.wifi,
      ),
      _DeviceCategory(
        id: 'wired_camera',
        title: 'Wired Camera',
        icon: Icons.videocam,
      ),
      _DeviceCategory(
        id: 'ptz_camera',
        title: 'PTZ Camera',
        icon: Icons.control_camera,
      ),
      _DeviceCategory(
        id: 'dvr_nvr',
        title: 'DVR/NVR',
        icon: Icons.dns,
      ),
      _DeviceCategory(
        id: 'edge_gateway',
        title: 'Edge Gateway',
        icon: Icons.router,
      ),
    ];

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: panelBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Add Device',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT DEVICE CATEGORY',
                style: TextStyle(
                  color: mutedText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Material(
                      color: panelBg,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          // Show connection type bottom sheet
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) => OnboardingModeSheet(
                              category: cat.id,
                              categoryName: cat.title,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: primaryBg.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.icon,
                                size: 36,
                                color: accentGreen,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                cat.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCategory {
  _DeviceCategory({
    required this.id,
    required this.title,
    required this.icon,
  });

  final String id;
  final String title;
  final IconData icon;
}
