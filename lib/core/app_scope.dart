import 'package:flutter/material.dart';
import 'app_settings.dart';

class AppScope extends InheritedNotifier<AppSettings> {
  final AppSettings settings;

  const AppScope({
    super.key,
    required this.settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings settingsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.settings;
  }
}
