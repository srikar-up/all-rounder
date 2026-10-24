import 'dart:math';

abstract class VaultAttemptStorage {
  Future<int> getFailedAttempts();
  Future<void> setFailedAttempts(int count);
  Future<DateTime?> getLastFailedAt();
  Future<void> setLastFailedAt(DateTime? dt);
}

class InMemoryAttemptStorage implements VaultAttemptStorage {
  int _failedAttempts = 0;
  DateTime? _lastFailedAt;

  @override
  Future<int> getFailedAttempts() async => _failedAttempts;

  @override
  Future<void> setFailedAttempts(int count) async => _failedAttempts = count;

  @override
  Future<DateTime?> getLastFailedAt() async => _lastFailedAt;

  @override
  Future<void> setLastFailedAt(DateTime? dt) async => _lastFailedAt = dt;
}

class VaultRateLimiter {
  VaultRateLimiter([VaultAttemptStorage? storage])
      : storage = storage ?? InMemoryAttemptStorage();

  final VaultAttemptStorage storage;

  /// Calculates backoff delay in seconds based on failed attempt count
  /// Delay starts after 3 failures: 1s, 2s, 4s, 8s, up to 300s (5 minutes).
  /// NOTE: This rate limiter slows down interactive UI brute-force attempts.
  /// Offline brute-force resistance is fundamentally enforced by Argon2id parameters.
  static int delayForAttempts(int attempts) {
    if (attempts < 3) return 0;
    final exponent = attempts - 3;
    final seconds = pow(2, exponent).toInt();
    return min(seconds, 300);
  }

  /// Checks how many seconds of lockout remain
  Future<int> remainingLockoutSeconds() async {
    final attempts = await storage.getFailedAttempts();
    final delay = delayForAttempts(attempts);
    if (delay == 0) return 0;

    final lastFailed = await storage.getLastFailedAt();
    if (lastFailed == null) return 0;

    final elapsed = DateTime.now().difference(lastFailed).inSeconds;
    final remaining = delay - elapsed;
    return max(0, remaining);
  }

  /// Records a failed attempt and returns remaining lockout seconds
  Future<int> recordFailure() async {
    final current = await storage.getFailedAttempts();
    final next = current + 1;
    await storage.setFailedAttempts(next);
    await storage.setLastFailedAt(DateTime.now());
    return delayForAttempts(next);
  }

  /// Resets failure count on successful unlock
  Future<void> recordSuccess() async {
    await storage.setFailedAttempts(0);
    await storage.setLastFailedAt(null);
  }
}
