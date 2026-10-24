enum HealthConnectStatus {
  connected,
  permissionRevoked,
  notInstalled,
}

class DailyQuota {
  final int stepsTarget;
  final int activeMinutesTarget;
  final int caloriesTarget;
  final int waterMlTarget;

  const DailyQuota({
    this.stepsTarget = 8000,
    this.activeMinutesTarget = 45,
    this.caloriesTarget = 450,
    this.waterMlTarget = 2500,
  });

  DailyQuota copyWith({
    int? stepsTarget,
    int? activeMinutesTarget,
    int? caloriesTarget,
    int? waterMlTarget,
  }) {
    return DailyQuota(
      stepsTarget: stepsTarget ?? this.stepsTarget,
      activeMinutesTarget: activeMinutesTarget ?? this.activeMinutesTarget,
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      waterMlTarget: waterMlTarget ?? this.waterMlTarget,
    );
  }
}

class HealthMetrics {
  final int steps;
  final int activeMinutes;
  final int calories;
  final int waterMl;
  final double distanceKm;

  const HealthMetrics({
    required this.steps,
    required this.activeMinutes,
    required this.calories,
    required this.waterMl,
    required this.distanceKm,
  });

  HealthMetrics copyWith({
    int? steps,
    int? activeMinutes,
    int? calories,
    int? waterMl,
    double? distanceKm,
  }) {
    return HealthMetrics(
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      calories: calories ?? this.calories,
      waterMl: waterMl ?? this.waterMl,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
