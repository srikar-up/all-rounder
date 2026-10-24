import 'package:flutter/foundation.dart';
import '../models/health_models.dart';

class HealthNotifier extends ChangeNotifier {
  HealthConnectStatus _status = HealthConnectStatus.connected;
  DailyQuota _quota = const DailyQuota(
    stepsTarget: 8000,
    activeMinutesTarget: 45,
    caloriesTarget: 500,
    waterMlTarget: 2500,
  );

  HealthMetrics _metrics = const HealthMetrics(
    steps: 6420,
    activeMinutes: 38,
    calories: 410,
    waterMl: 1800,
    distanceKm: 4.8,
  );

  HealthConnectStatus get status => _status;
  DailyQuota get quota => _quota;
  HealthMetrics get metrics => _metrics;

  double get stepsProgress => (_metrics.steps / _quota.stepsTarget).clamp(0.0, 1.0);
  double get activeMinutesProgress =>
      (_metrics.activeMinutes / _quota.activeMinutesTarget).clamp(0.0, 1.0);
  double get caloriesProgress =>
      (_metrics.calories / _quota.caloriesTarget).clamp(0.0, 1.0);
  double get waterProgress =>
      (_metrics.waterMl / _quota.waterMlTarget).clamp(0.0, 1.0);

  void setStatus(HealthConnectStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void updateQuota({
    int? stepsTarget,
    int? activeMinutesTarget,
    int? caloriesTarget,
    int? waterMlTarget,
  }) {
    _quota = _quota.copyWith(
      stepsTarget: stepsTarget,
      activeMinutesTarget: activeMinutesTarget,
      caloriesTarget: caloriesTarget,
      waterMlTarget: waterMlTarget,
    );
    notifyListeners();
  }

  void addSteps(int steps) {
    final newSteps = _metrics.steps + steps;
    final newKm = newSteps * 0.00075;
    final newCalories = _metrics.calories + (steps * 0.04).round();
    _metrics = _metrics.copyWith(
      steps: newSteps,
      distanceKm: double.parse(newKm.toStringAsFixed(2)),
      calories: newCalories,
    );
    notifyListeners();
  }

  void addWater(int ml) {
    _metrics = _metrics.copyWith(waterMl: _metrics.waterMl + ml);
    notifyListeners();
  }

  void addActiveMinutes(int minutes) {
    _metrics = _metrics.copyWith(
      activeMinutes: _metrics.activeMinutes + minutes,
      calories: _metrics.calories + (minutes * 6),
    );
    notifyListeners();
  }
}
