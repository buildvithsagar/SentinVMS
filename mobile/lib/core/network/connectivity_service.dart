import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  ConnectivityService({
    this._checkInterval = const Duration(seconds: 30),
    this.lookupHost = 'dns.google',
    this.enabled = true,
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    if (enabled) _init();
  }

  final Duration _checkInterval;
  final Logger _logger;
  final String lookupHost;
  final bool enabled;
  Timer? _timer;

  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  ConnectivityStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  void _init() {
    checkConnection();
    _timer = Timer.periodic(_checkInterval, (_) => checkConnection());
  }

  Future<ConnectivityStatus> checkConnection() async {
    if (!enabled) return ConnectivityStatus.online;
    try {
      final result = await InternetAddress.lookup(
        lookupHost,
      ).timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(ConnectivityStatus.online);
        return ConnectivityStatus.online;
      }
    } catch (_) {
      // Lookup failed
    }

    _updateStatus(ConnectivityStatus.offline);
    return ConnectivityStatus.offline;
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _logger.i('Connectivity state changed to: $newStatus');
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _statusController.close();
  }
}
