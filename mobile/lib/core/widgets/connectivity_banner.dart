import 'package:app/core/network/connectivity_service.dart';
import 'package:app/core/theme/vms_theme.dart';
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
            if (isOffline)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _OfflineConnectivityBanner(),
              ),
          ],
        );
      },
    );
  }
}

class _OfflineConnectivityBanner extends StatelessWidget {
  const _OfflineConnectivityBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('offlineConnectivityBanner'),
      color: VmsColors.danger,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: 'Control plane offline. Local camera video may still work.',
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Control plane offline - Local video can continue',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
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
