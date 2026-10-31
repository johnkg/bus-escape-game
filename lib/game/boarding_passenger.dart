import 'dart:math';
import 'dart:ui';

import 'package:flutter/animation.dart';

import 'layers.dart';
import 'passenger_painter.dart';
import 'symbols.dart';
import 'timed_effect.dart';

/// One passenger walking from the queue to a seat in a parked vehicle.
class BoardingPassenger extends TimedEffect {
  BoardingPassenger({
    required this.from,
    required this.to,
    required this.toScale,
    required this.colorIndex,
    required this.onArrived,
  }) : super(lifetime: walkSeconds, priority: Layer.boarding);

  /// How long the walk from the queue to the seat takes.
  static const double walkSeconds = 0.34;

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

  @override
  void onFinished() => onArrived();

  @override
  void render(Canvas canvas) {
    final u = progress;
    final p = Curves.easeInOutSine.transform(u);
    final pos = Offset.lerp(from, to, p)!.translate(0, -sin(pi * p) * _hop);
    final scale = 1 + (toScale - 1) * p;
    paintPassenger(canvas, pos, colorIndex, scale: scale);
    if (game.showSymbols && u < _symbolUntil) {
      paintPersonSymbol(canvas, pos, colorIndex);
    }
  }
}
