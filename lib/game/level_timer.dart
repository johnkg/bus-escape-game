import 'package:flutter/foundation.dart';

/// The countdown on a timed level. The game feeds it frame time while the
/// level is in play; pausing the engine therefore pauses the clock.
class LevelTimer {
  /// Whole seconds left, or null when the level is untimed.
  final ValueNotifier<int?> timeLeft = ValueNotifier(null);

  /// Set once the clock runs out.
  final ValueNotifier<bool> timeUp = ValueNotifier(false);

  double? _limit;
  double _used = 0;

  /// Puts a countdown of [seconds] on the level.
  void start(double seconds) {
    _limit = seconds;
    _used = 0;
    timeUp.value = false;
    timeLeft.value = seconds.ceil();
  }

  /// Share of the clock still left (0 when untimed).
  double get fraction {
    final limit = _limit;
    return limit == null ? 0 : ((limit - _used) / limit).clamp(0.0, 1.0);
  }

  /// Advances the clock by [dt] seconds. [onExpiring] runs just before
  /// [timeUp] flips, so callers can tidy up first.
  void tick(double dt, {VoidCallback? onExpiring}) {
    final limit = _limit;
    if (limit == null || timeUp.value) return;
    _used += dt;
    final left = limit - _used;
    if (left <= 0) {
      timeLeft.value = 0;
      onExpiring?.call();
      timeUp.value = true;
    } else if (left.ceil() != timeLeft.value) {
      timeLeft.value = left.ceil();
    }
  }
}
