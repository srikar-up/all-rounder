import '../models/health_status.dart';
import 'health_source.dart';

class FakeHealthSource implements HealthSource {
  FakeHealthSource({
    this.currentStatus = HealthStatus.ready,
    this.steps = 5420,
    List<({DateTime start, DateTime end})>? workouts,
  }) : workouts = workouts ?? [];

  HealthStatus currentStatus;
  int steps;
  List<({DateTime start, DateTime end})> workouts;
  bool installPageOpened = false;
  bool permissionsRequested = false;

  @override
  Future<HealthStatus> status() async => currentStatus;

  @override
  Future<bool> requestPermissions() async {
    permissionsRequested = true;
    if (currentStatus == HealthStatus.needsPermission) {
      currentStatus = HealthStatus.ready;
      return true;
    }
    return currentStatus == HealthStatus.ready;
  }

  @override
  Future<void> openInstallPage() async {
    installPageOpened = true;
  }

  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    return steps;
  }

  @override
  Future<List<({DateTime start, DateTime end})>> workoutSpans(
    DateTime start,
    DateTime end,
  ) async {
    return workouts;
  }
}
