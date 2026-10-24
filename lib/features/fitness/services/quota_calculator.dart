import '../models/daily_quota.dart';
import 'health_source.dart';

Duration mergedDuration(
  List<({DateTime start, DateTime end})> spans,
  DateTime from,
  DateTime to,
) {
  final clipped = <({DateTime start, DateTime end})>[];
  for (final s in spans) {
    final a = s.start.isBefore(from) ? from : s.start;
    final b = s.end.isAfter(to) ? to : s.end;
    if (b.isAfter(a)) {
      clipped.add((start: a, end: b));
    }
  }

  if (clipped.isEmpty) return Duration.zero;
  clipped.sort((x, y) => x.start.compareTo(y.start));

  var total = Duration.zero;
  var curStart = clipped.first.start;
  var curEnd = clipped.first.end;

  for (final s in clipped.skip(1)) {
    if (s.start.isAfter(curEnd)) {
      total += curEnd.difference(curStart);
      curStart = s.start;
      curEnd = s.end;
    } else if (s.end.isAfter(curEnd)) {
      curEnd = s.end;
    }
  }

  return total + curEnd.difference(curStart);
}

class QuotaCalculator {
  static Future<QuotaProgress> calculate({
    required HealthSource healthSource,
    required DailyQuota quota,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final startOfDay = DateTime(current.year, current.month, current.day);

    final steps = await healthSource.stepsBetween(startOfDay, current);
    final spans = await healthSource.workoutSpans(startOfDay, current);
    final duration = mergedDuration(spans, startOfDay, current);

    return QuotaProgress(
      steps: steps,
      stepsGoal: quota.stepsGoal,
      exerciseMinutes: duration.inMinutes,
      exerciseMinutesGoal: quota.exerciseMinutesGoal,
      lastRefreshed: current,
    );
  }
}
