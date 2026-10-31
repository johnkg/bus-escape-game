import 'package:flame/components.dart';

import 'bus_escape_game.dart';

/// A short-lived decoration that removes itself after [lifetime] seconds.
abstract class TimedEffect extends PositionComponent
    with HasGameReference<BusEscapeGame> {
  TimedEffect({required this.lifetime, super.priority});

  final double lifetime;
  double _elapsed = 0;

  /// 0 when it starts, 1 when it is done.
  double get progress => (_elapsed / lifetime).clamp(0.0, 1.0);

  /// Called once, right after it removed itself.
  void onFinished() {}

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
      onFinished();
    }
  }
}
