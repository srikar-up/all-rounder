import 'package:shared_preferences/shared_preferences.dart';

class DailyQuota {
  final int stepsGoal;
  final int exerciseMinutesGoal;

  const DailyQuota({
    this.stepsGoal = 8000,
    this.exerciseMinutesGoal = 30,
  });

  static const String keyStepsGoal = 'all_rounder_fitness_steps_goal';
  static const String keyExerciseGoal = 'all_rounder_fitness_exercise_goal';

  static Future<DailyQuota> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return DailyQuota(
        stepsGoal: prefs.getInt(keyStepsGoal) ?? 8000,
        exerciseMinutesGoal: prefs.getInt(keyExerciseGoal) ?? 30,
      );
    } catch (_) {
      return const DailyQuota();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyStepsGoal, stepsGoal);
      await prefs.setInt(keyExerciseGoal, exerciseMinutesGoal);
    } catch (_) {}
  }
}

class QuotaProgress {
  final int steps;
  final int stepsGoal;
  final int exerciseMinutes;
  final int exerciseMinutesGoal;
  final DateTime lastRefreshed;

  const QuotaProgress({
    required this.steps,
    required this.stepsGoal,
    required this.exerciseMinutes,
    required this.exerciseMinutesGoal,
    required this.lastRefreshed,
  });

  double get stepsFraction {
    if (stepsGoal <= 0) return 1.0;
    return (steps / stepsGoal).clamp(0.0, 1.0);
  }

  double get exerciseMinutesFraction {
    if (exerciseMinutesGoal <= 0) return 1.0;
    return (exerciseMinutes / exerciseMinutesGoal).clamp(0.0, 1.0);
  }

  bool get isComplete {
    final stepsDone = stepsGoal <= 0 || steps >= stepsGoal;
    final exerciseDone = exerciseMinutesGoal <= 0 || exerciseMinutes >= exerciseMinutesGoal;
    return stepsDone && exerciseDone;
  }
}
