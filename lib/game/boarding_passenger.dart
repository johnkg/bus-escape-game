import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import 'bus_escape_game.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';
import 'layers.dart';

/// One passenger walking from the queue to a seat in a parked vehicle.
class BoardingPassenger extends PositionComponent
    with HasGameReference<BusEscapeGame> {
  BoardingPassenger({
    required this.from,
    required this.to,
    required this.toScale,
    required this.colorIndex,
    required this.onArrived,
  }) : super(priority: Layer.boarding);

  static const double duration = 0.34;

  /// Peak height of the little hop on the way.
  static const double _hop = 10;

  /// The color symbol rides along until the passenger is nearly seated.
  static const double _symbolUntil = 0.8;

  final Offset from;
  final Offset to;

  /// Size of a seated passenger, so landing is seamless.
  final double toScale;
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
    final u = (_t / duration).clamp(0.0, 1.0);
    final p = Curves.easeInOutSine.transform(u);
    final pos = Offset.lerp(from, to, p)!.translate(0, -sin(pi * p) * _hop);
    final scale = 1 + (toScale - 1) * p;
    paintPassenger(canvas, pos, colorIndex, scale: scale);
    if (game.showSymbols && u < _symbolUntil) {
      paintPersonSymbol(canvas, pos, colorIndex);
    }
  }
}
