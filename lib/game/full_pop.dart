import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import 'bus_escape_game.dart';
import 'layers.dart';
import 'palette.dart';

/// A short "FULL!" that floats up from a bay as its vehicle pulls away. It
/// only decorates the departure; it never holds the vehicle back.
class FullPop extends PositionComponent with HasGameReference<BusEscapeGame> {
  FullPop({required this.slot}) : super(priority: Layer.fullPop);

  static const double duration = 0.8;

  static const double _fontSize = 15;
  static const double _shadowBlur = 3;

  static final _text = TextPaint(
    style: const TextStyle(
      color: white,
      fontSize: _fontSize,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: textShadow, blurRadius: _shadowBlur)],
    ),
  );

  // It pops in (grows to full size over the first [_growFor] of its life),
  // rises [_rise] px from [_startLift] above the bay, and fades out after
  // [_fadeFrom].
  static const double _growFor = 0.2;
  static const double _startScale = 0.6;
  static const double _fadeFrom = 0.6;
  static const double _startLift = 10;
  static const double _rise = 28;
  static const double _layerSize = 120;

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
    final pop = p < _growFor
        ? _startScale + (1 - _startScale) / _growFor * p
        : 1.0;
    final alpha = p < _fadeFrom ? 1.0 : 1 - (p - _fadeFrom) / (1 - _fadeFrom);
    canvas.saveLayer(
      Rect.fromCenter(center: c, width: _layerSize, height: _layerSize),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    canvas.translate(c.dx, c.dy - _startLift - p * _rise);
    canvas.scale(pop);
    _text.render(canvas, 'FULL!', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}
