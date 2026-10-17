import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import 'bus_escape_game.dart';

/// A short "FULL!" that floats up from a bay as its vehicle pulls away. It
/// only decorates the departure; it never holds the vehicle back.
class FullPop extends PositionComponent with HasGameReference<BusEscapeGame> {
  FullPop({required this.slot}) : super(priority: 3);

  static const double duration = 0.8;

  static final _text = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 15,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
    ),
  );

  final int slot;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final c = game.layout.laneSlotRect(slot).center;
    final pop = p < 0.2 ? 0.6 + 2 * p : 1.0;
    final alpha = p < 0.6 ? 1.0 : 1 - (p - 0.6) / 0.4;
    canvas.saveLayer(
      Rect.fromCenter(center: c, width: 120, height: 120),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    canvas.translate(c.dx, c.dy - 10 - p * 28);
    canvas.scale(pop);
    _text.render(canvas, 'FULL!', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}
