import 'package:app/core/network/connectivity_service.dart';
import 'package:flutter/material.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    required this.connectivityService,
    required this.child,
    super.key,
  });

  final ConnectivityService connectivityService;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityStatus>(
      stream: connectivityService.statusStream,
      initialData: connectivityService.currentStatus,
      builder: (context, snapshot) {
        final isOffline = snapshot.data == ConnectivityStatus.offline;

        return Stack(
          children: [
            child,
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: isOffline ? 0 : -40,
              left: 0,
              right: 0,
              height: 36,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: const Color(0xFFD32F2F),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'NETWORK CONNECTION LOST — TELEMETRY PAUSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
