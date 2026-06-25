import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:logger/logger.dart';

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
  WebSocket? _webSocket;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
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
        _logger.i('WebSocket Auth state changed (Authenticated). Initializing socket.');
        _currentAccessToken = state.accessToken;
        _reconnectAttempts = 0;
        _connect();
      }
    } else {
      if (_currentAccessToken != null) {
        _logger.i('WebSocket Auth state changed (Unauthenticated). Closing socket.');
        _currentAccessToken = null;
        _disconnect();
      }
    }
  }

  Future<void> _connect() async {
    if (_isDisposed || _currentAccessToken == null) return;

    _disconnectSocketOnly();
    _updateStatus(WebSocketStatus.reconnecting);

    final wsBase = AppConstants.wsUrl
        .replaceAll('https://', 'wss://')
        .replaceAll('http://', 'ws://');
    final wsUri = Uri.parse('$wsBase/ws?token=$_currentAccessToken');

    _logger.d('Connecting to WebSocket: ${wsUri.scheme}://${wsUri.host}:${wsUri.port}${wsUri.path}?token=REDACTED');

    try {
      const bypassPinning = bool.fromEnvironment('BYPASS_PINNING');
      final client = HttpClient();
      if (bypassPinning) {
        client.badCertificateCallback = (cert, host, port) => true;
      } else {
        client.badCertificateCallback = (cert, host, port) => false;
      }
      
      final connectionFuture = WebSocket.connect(
        wsUri.toString(),
        customClient: client,
      );
      
      _webSocket = await connectionFuture.timeout(const Duration(seconds: 10));
      _reconnectAttempts = 0;
      _updateStatus(WebSocketStatus.connected);
      _logger.i('WebSocket connected successfully.');

      // Resubscribe to sites
      _resubscribeToAllSites();

      _webSocket!.listen(
        _onMessageReceived,
        onError: _onConnectionError,
        onDone: _onConnectionClosed,
        cancelOnError: true,
      );
    } catch (e) {
      _logger.e('WebSocket connection failed: $e');
      _updateStatus(WebSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _disconnectSocketOnly() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _webSocket?.close();
    } catch (_) {}
    _webSocket = null;
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

  void _scheduleReconnect() {
    if (_isDisposed || _currentAccessToken == null) return;
    
    _reconnectTimer?.cancel();
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 30);
    _reconnectAttempts++;

    _logger.d('Scheduling WebSocket reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _connect);
  }

  void _onMessageReceived(dynamic message) {
    if (message is String) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic>) {
          if (!_eventController.isClosed) {
            _eventController.add(decoded);
          }
        }
      } catch (e) {
        _logger.e('WebSocket failed to parse message: $e');
      }
    }
  }

  void _onConnectionError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _onConnectionClosed();
  }

  void _onConnectionClosed() {
    _logger.w('WebSocket connection closed.');
    _updateStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
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
      _logger.d('WebSocket resubscribing to site: $siteId');
      _sendEvent('subscribe:site', {'siteId': siteId});
    }
  }

  void _sendEvent(String event, Map<String, dynamic> data) {
    final socket = _webSocket;
    if (socket != null && isConnected) {
      try {
        final payload = jsonEncode({
          'event': event,
          'data': data,
        });
        socket.add(payload);
      } catch (e) {
        _logger.e('WebSocket failed to send event $event: $e');
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
