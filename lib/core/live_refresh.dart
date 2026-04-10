import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

String liveRefreshSignature(Object? value) =>
    jsonEncode(_normalizeForSignature(value));

Object? _normalizeForSignature(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((left, right) {
        return left.key.toString().compareTo(right.key.toString());
      });
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _normalizeForSignature(entry.value),
    };
  }

  if (value is Iterable) {
    return value.map(_normalizeForSignature).toList(growable: false);
  }

  if (value is DateTime) {
    return value.toIso8601String();
  }

  return value;
}

mixin LiveRefreshState<T extends StatefulWidget> on State<T> {
  Timer? _liveRefreshTimer;
  AppLifecycleListener? _appLifecycleListener;
  bool _isAppInForeground = true;
  bool _isRefreshInProgress = false;

  @protected
  Duration get liveRefreshInterval;

  @protected
  bool get enableLiveRefresh;

  @protected
  Future<void> performLiveRefresh();

  @protected
  Future<void> triggerLiveRefreshNow() async {
    if (!mounted || _isRefreshInProgress) return;
    if (!_isAppInForeground || !enableLiveRefresh) return;

    _isRefreshInProgress = true;
    try {
      await performLiveRefresh();
    } catch (error, stackTrace) {
      debugPrint('Live refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isRefreshInProgress = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleStateChanged,
    );
    _liveRefreshTimer = Timer.periodic(liveRefreshInterval, (_) {
      unawaited(triggerLiveRefreshNow());
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  void _handleAppLifecycleStateChanged(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground) {
      unawaited(triggerLiveRefreshNow());
    }
  }
}
