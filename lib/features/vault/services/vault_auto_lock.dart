import 'package:flutter/widgets.dart';

enum AutoLockDelay {
  immediately(0, 'Immediately'),
  thirtySeconds(30, '30 seconds'),
  oneMinute(60, '1 minute'),
  fiveMinutes(300, '5 minutes');

  final int seconds;
  final String label;
  const AutoLockDelay(this.seconds, this.label);
}

class VaultAutoLockObserver with WidgetsBindingObserver {
  VaultAutoLockObserver({
    required this.onLock,
    this.delay = AutoLockDelay.thirtySeconds,
  });

  final VoidCallback onLock;
  AutoLockDelay delay;
  DateTime? _pausedAt;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      if (delay == AutoLockDelay.immediately) {
        onLock();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= delay.seconds) {
          onLock();
        }
        _pausedAt = null;
      }
    }
  }
}
