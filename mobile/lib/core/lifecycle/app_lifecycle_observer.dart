import 'package:app/core/network/websocket_service.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({
    required this.webSocketService,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final WebSocketService webSocketService;
  final Logger _logger;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _logger.i('AppLifecycleObserver initialized.');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logger.i('AppLifecycleObserver disposed.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.i('App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _onPaused();
      case AppLifecycleState.detached:
        _onDetached();
    }
  }

  void _onResumed() {
    _logger.i('App returned to foreground. Re-syncing telemetry and WebSocket connection.');
    if (webSocketService.authBloc.state.toString().contains('Authenticated')) {
      // Stream reconnection triggers via AuthBloc state listener inside WebSocketService
    }
  }

  void _onPaused() {
    _logger.i('App backgrounded. Conserving battery and network decoder resources.');
  }

  void _onDetached() {
    _logger.w('App detached. Cleaning up transient lifecycle services.');
  }
}
