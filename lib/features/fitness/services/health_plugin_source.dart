import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/health_status.dart';
import 'health_source.dart';

class HealthPluginSource implements HealthSource {
  HealthPluginSource() : _health = Health();

  final Health _health;
  bool _configured = false;

  static const List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataAccess> _dataAccess = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (_) {
      _configured = true;
    }
  }

  @override
  Future<HealthStatus> status() async {
    if (kIsWeb || !Platform.isAndroid) {
      return HealthStatus.unsupported;
    }

    try {
      await _ensureConfigured();

      final sdkStatus = await _health.getHealthConnectSdkStatus();
      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
        return HealthStatus.notInstalled;
      }
      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        return HealthStatus.updateRequired;
      }

      final hasPerms = await _health.hasPermissions(_dataTypes, permissions: _dataAccess);
      if (hasPerms != true) {
        return HealthStatus.needsPermission;
      }

      return HealthStatus.ready;
    } catch (_) {
      return HealthStatus.error;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      await _ensureConfigured();

      // Request Android activity recognition first
      final activityStatus = await Permission.activityRecognition.request();
      if (activityStatus.isPermanentlyDenied) {
        return false;
      }

      final granted = await _health.requestAuthorization(
        _dataTypes,
        permissions: _dataAccess,
      );
      return granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openInstallPage() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    if (kIsWeb || !Platform.isAndroid) return 0;

    try {
      await _ensureConfigured();
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<({DateTime start, DateTime end})>> workoutSpans(
    DateTime start,
    DateTime end,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return [];

    try {
      await _ensureConfigured();
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );

      return data.map((d) => (start: d.dateFrom, end: d.dateTo)).toList();
    } catch (_) {
      return [];
    }
  }
}
