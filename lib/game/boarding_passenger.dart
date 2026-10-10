import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import 'bus_escape_game.dart';
import 'palette.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

/// One passenger hopping from the queue into a parked vehicle.
class BoardingPassenger extends PositionComponent
    with HasGameReference<BusEscapeGame> {
  BoardingPassenger({
    required this.from,
    required this.to,
    required this.colorIndex,
    required this.onArrived,
  }) : super(priority: 6);

  static const double duration = 0.24;

  final Offset from;
  final Offset to;
  final int colorIndex;
  final VoidCallback onArrived;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
      onArrived();
    }
  }

  @override
  void render(Canvas canvas) {
    final p = Curves.easeInOut.transform((_t / duration).clamp(0.0, 1.0));
    final pos = Offset.lerp(from, to, p)!.translate(0, -sin(pi * p) * 18);
    final color = busColors[colorIndex % busColors.length];
    paintPerson(canvas, pos, color, scale: 1 - 0.25 * p);
    if (game.showSymbols) {
      paintSymbol(canvas, pos.translate(0, 4), 8, symbolFor(colorIndex));
    }
  }
}
