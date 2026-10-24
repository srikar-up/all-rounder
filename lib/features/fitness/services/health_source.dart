import '../models/health_status.dart';

abstract class HealthSource {
  Future<HealthStatus> status();
  Future<bool> requestPermissions();
  Future<void> openInstallPage();
  Future<int> stepsBetween(DateTime start, DateTime end);
  Future<List<({DateTime start, DateTime end})>> workoutSpans(DateTime start, DateTime end);
}
