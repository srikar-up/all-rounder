import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/fitness/models/daily_quota.dart';
import 'package:all_rounder/features/fitness/models/health_status.dart';
import 'package:all_rounder/features/fitness/services/fake_health_source.dart';
import 'package:all_rounder/features/fitness/services/quota_calculator.dart';

void main() {
  group('Quota Calculator & Interval Merging Tests (Phase 4)', () {
    final baseDate = DateTime(2026, 10, 24);
    final from = DateTime(2026, 10, 24, 0, 0);
    final to = DateTime(2026, 10, 24, 23, 59, 59);

    test('empty spans return zero duration', () {
      final duration = mergedDuration([], from, to);
      expect(duration, Duration.zero);
    });

    test('single span returns its duration', () {
      final spans = [
        (start: DateTime(2026, 10, 24, 8, 0), end: DateTime(2026, 10, 24, 8, 30)),
      ];
      final duration = mergedDuration(spans, from, to);
      expect(duration, const Duration(minutes: 30));
    });

    test('overlapping spans are merged without double-counting', () {
      // App A recorded 09:00 - 10:00 (60 min)
      // App B recorded 09:30 - 10:30 (60 min)
      // Combined should be 09:00 - 10:30 = 90 min (not 120 min)
      final spans = [
        (start: DateTime(2026, 10, 24, 9, 0), end: DateTime(2026, 10, 24, 10, 0)),
        (start: DateTime(2026, 10, 24, 9, 30), end: DateTime(2026, 10, 24, 10, 30)),
      ];
      final duration = mergedDuration(spans, from, to);
      expect(duration, const Duration(minutes: 90));
    });

    test('adjacent spans are merged contiguously', () {
      final spans = [
        (start: DateTime(2026, 10, 24, 7, 0), end: DateTime(2026, 10, 24, 7, 45)),
        (start: DateTime(2026, 10, 24, 7, 45), end: DateTime(2026, 10, 24, 8, 15)),
      ];
      final duration = mergedDuration(spans, from, to);
      expect(duration, const Duration(minutes: 75));
    });

    test('nested spans: inner workout does not add extra time', () {
      final spans = [
        (start: DateTime(2026, 10, 24, 14, 0), end: DateTime(2026, 10, 24, 15, 0)),
        (start: DateTime(2026, 10, 24, 14, 15), end: DateTime(2026, 10, 24, 14, 45)),
      ];
      final duration = mergedDuration(spans, from, to);
      expect(duration, const Duration(minutes: 60));
    });

    test('spans crossing boundaries are properly clipped to window', () {
      final windowStart = DateTime(2026, 10, 24, 10, 0);
      final windowEnd = DateTime(2026, 10, 24, 11, 0);

      // Workout started before window and ends after window
      final spans = [
        (start: DateTime(2026, 10, 24, 9, 30), end: DateTime(2026, 10, 24, 11, 30)),
      ];
      final duration = mergedDuration(spans, windowStart, windowEnd);
      expect(duration, const Duration(minutes: 60));
    });

    test('QuotaProgress fractions and isComplete', () {
      const quota = DailyQuota(stepsGoal: 10000, exerciseMinutesGoal: 30);

      // Halfway
      final p1 = QuotaProgress(
        steps: 5000,
        stepsGoal: quota.stepsGoal,
        exerciseMinutes: 15,
        exerciseMinutesGoal: quota.exerciseMinutesGoal,
        lastRefreshed: DateTime.now(),
      );
      expect(p1.stepsFraction, 0.5);
      expect(p1.exerciseMinutesFraction, 0.5);
      expect(p1.isComplete, false);

      // Complete
      final p2 = QuotaProgress(
        steps: 12000,
        stepsGoal: quota.stepsGoal,
        exerciseMinutes: 45,
        exerciseMinutesGoal: quota.exerciseMinutesGoal,
        lastRefreshed: DateTime.now(),
      );
      expect(p2.stepsFraction, 1.0); // clamped
      expect(p2.exerciseMinutesFraction, 1.0); // clamped
      expect(p2.isComplete, true);

      // Zero-goal guard does not throw divide-by-zero
      final zeroQuota = QuotaProgress(
        steps: 100,
        stepsGoal: 0,
        exerciseMinutes: 0,
        exerciseMinutesGoal: 0,
        lastRefreshed: DateTime.now(),
      );
      expect(zeroQuota.stepsFraction, 1.0);
      expect(zeroQuota.exerciseMinutesFraction, 1.0);
      expect(zeroQuota.isComplete, true);
    });

    test('FakeHealthSource status transitions', () async {
      final fake = FakeHealthSource(currentStatus: HealthStatus.needsPermission);
      expect(await fake.status(), HealthStatus.needsPermission);

      final granted = await fake.requestPermissions();
      expect(granted, true);
      expect(await fake.status(), HealthStatus.ready);
    });
  });
}
