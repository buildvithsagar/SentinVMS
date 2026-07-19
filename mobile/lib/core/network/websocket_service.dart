import 'dart:async';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

enum WebSocketStatus { connected, disconnected, reconnecting }

class WebSocketService {
  WebSocketService({
    required this.authBloc,
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _authSubscription = authBloc.stream.listen(_onAuthStateChanged);
    // Trigger initial check in case already authenticated
    _onAuthStateChanged(authBloc.state);
  }

  final AuthBloc authBloc;
  final Logger _logger;
  
  late final StreamSubscription<AuthState> _authSubscription;
  socket_io.Socket? _socket;
  bool _isDisposed = false;
  String? _currentAccessToken;

  final Set<String> _subscribedSites = {};

  // Status controller
  final _statusController = StreamController<WebSocketStatus>.broadcast();
  Stream<WebSocketStatus> get statusStream => _statusController.stream;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  WebSocketStatus get status => _status;

  // Event stream controller
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  // Connection state
  bool get isConnected => _status == WebSocketStatus.connected;

  void _onAuthStateChanged(AuthState state) {
    if (state is Authenticated) {
      if (_currentAccessToken != state.accessToken) {
        _logger.i('WebSocket Auth state changed (Authenticated). Initializing Socket.io.');
        _currentAccessToken = state.accessToken;
        _connect();
      }
    } else {
      if (_currentAccessToken != null) {
        _logger.i('WebSocket Auth state changed (Unauthenticated). Closing Socket.io.');
        _currentAccessToken = null;
        _disconnect();
      }
    }
  }

  void _connect() {
    if (_isDisposed || _currentAccessToken == null) return;

    _disconnectSocketOnly();
    _updateStatus(WebSocketStatus.reconnecting);

    const wsBase = AppConstants.wsUrl;
    _logger.d('Connecting to Socket.io Broadcaster at: $wsBase with path: /ws/v5/telemetry');

    try {
      _socket = socket_io.io(wsBase, socket_io.OptionBuilder()
        .setTransports(['websocket'])
        .setPath('/ws/v5/telemetry')
        .setAuth({'token': _currentAccessToken})
        .disableReconnection()
        .build());

      _socket!.onConnect((_) {
        _logger.i('Socket.io connected successfully.');
        _updateStatus(WebSocketStatus.connected);
        _resubscribeToAllSites();
      });

      _socket!.onDisconnect((_) {
        _logger.w('Socket.io disconnected.');
        _updateStatus(WebSocketStatus.disconnected);
      });

      _socket!.onConnectError((err) {
        // Handle socket connection silently in offline/detached mode
        _updateStatus(WebSocketStatus.disconnected);
      });

      // Listen to telemetry channels
      _socket!.on('ai.alert.triggered', (data) {
        _logger.d('Socket.io received alert: $data');
        if (data is Map<String, dynamic>) {
          _eventController.add({
            'event': 'ai.alert.triggered',
            'data': data['data'] ?? data,
          });
        }
      });

      _socket!.on('camera.status', (data) {
        _logger.d('Socket.io received camera status: $data');
        if (data is Map<String, dynamic>) {
          _eventController.add({
            'event': 'camera.status',
            'data': data['data'] ?? data,
          });
        }
      });
      
      _socket!.on('storage.alert', (data) {
        _logger.d('Socket.io received storage alert: $data');
        if (data is Map<String, dynamic>) {
          _eventController.add({
            'event': 'storage.alert',
            'data': data['data'] ?? data,
          });
        }
      });

    } catch (e) {
      _logger.e('Socket.io initialization failed: $e');
      _updateStatus(WebSocketStatus.disconnected);
    }
  }

  void _disconnectSocketOnly() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _disconnect() {
    _disconnectSocketOnly();
    _updateStatus(WebSocketStatus.disconnected);
  }

  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  /// Subscribes to telemetry events for a site.
  void subscribeToSite(String siteId) {
    if (siteId.isEmpty) return;
    _subscribedSites.add(siteId);
    _sendEvent('subscribe:site', {'siteId': siteId});
  }

  /// Unsubscribes from telemetry events for a site.
  void unsubscribeFromSite(String siteId) {
    _subscribedSites.remove(siteId);
    _sendEvent('unsubscribe:site', {'siteId': siteId});
  }

  void _resubscribeToAllSites() {
    for (final siteId in _subscribedSites) {
      _logger.d('Socket.io resubscribing to site: $siteId');
      _sendEvent('subscribe:site', {'siteId': siteId});
    }
  }

  void _sendEvent(String event, Map<String, dynamic> data) {
    final s = _socket;
    if (s != null && s.connected) {
      try {
        s.emit(event, data);
      } catch (e) {
        _logger.e('Socket.io failed to emit event $event: $e');
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _authSubscription.cancel();
    _disconnect();
    _statusController.close();
    _eventController.close();
  }
}
