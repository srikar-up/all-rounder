import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('all_rounder/secure_screen');

  /// Enables FLAG_SECURE to block screenshots and recent-apps preview
  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Graceful fallback on non-Android platforms, tests, or web
    }
  }

  /// Disables FLAG_SECURE
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {
      // Graceful fallback
    }
  }
}
