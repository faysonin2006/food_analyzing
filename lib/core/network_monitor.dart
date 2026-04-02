import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor._();

  static final NetworkMonitor instance = NetworkMonitor._();

  static const Duration _pollInterval = Duration(seconds: 6);
  static const Duration _dnsTimeout = Duration(seconds: 3);
  static const Duration _socketTimeout = Duration(seconds: 2);

  Timer? _timer;
  bool _isOnline = true;
  DateTime? _lastCheckedAt;

  bool get isOnline => _isOnline;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  void start() {
    if (_timer != null) return;
    _runCheck();
    _timer = Timer.periodic(_pollInterval, (_) => _runCheck());
  }

  Future<void> _runCheck() async {
    final online = await _hasInternetConnection();
    _lastCheckedAt = DateTime.now();
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final lookup = await InternetAddress.lookup(
        'example.com',
      ).timeout(_dnsTimeout);
      if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: _socketTimeout,
      );
      socket.destroy();
      return true;
    } catch (_) {}

    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
