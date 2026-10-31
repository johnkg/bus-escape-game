import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import 'bus_escape_game.dart';
import 'layout.dart';
import 'symbols.dart';
import 'passenger_painter.dart';
import 'layers.dart';
import 'palette.dart';

class _Person {
  _Person(this.color, this.pos);

  final int color;
  Offset pos;
}

/// Waiting passengers as little people in a line from the depot door. When
/// someone leaves for a vehicle the rest glide forward to close the gap.
class QueueView extends PositionComponent with HasGameReference<BusEscapeGame> {
  QueueView(this.layout, {required this.waiting})
    : super(priority: Layer.queue);

  /// How many people are still standing in the line. It drops one at a
  /// time as each passenger walks off to a vehicle, not when the move is
  /// made.
  final ValueNotifier<int> waiting;

  /// How quickly people close a gap (per second, exponential).
  static const double _glideRate = 12;

  // Ground shadow under each person.
  static const double _shadowDrop = 13;
  static const double _shadowWidth = 14;
  static const double _shadowHeight = 5;

  final GameLayout layout;
  final List<_Person> _people = [];

  /// Shows [colors] (front first) at once, with nobody moving.
  void reset(List<int> colors) {
    _people
      ..clear()
      ..addAll([
        for (var i = 0; i < colors.length; i++)
          _Person(colors[i], layout.queuePoint(i)),
      ]);
    waiting.value = _people.length;
  }

  /// Removes the first waiting passenger of [color] and returns where they
  /// were standing, so a walking copy can start from there.
  Offset? take(int color) {
    final i = _people.indexWhere((p) => p.color == color);
    if (i < 0) return null;
    final person = _people.removeAt(i);
    waiting.value = _people.length;
    return person.pos;
  }

  @override
  void update(double dt) {
    final k = 1 - exp(-dt * _glideRate);
    for (var i = 0; i < _people.length; i++) {
      final p = _people[i];
      final t = layout.queuePoint(i);
      p.pos = Offset(
        p.pos.dx + (t.dx - p.pos.dx) * k,
        p.pos.dy + (t.dy - p.pos.dy) * k,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final n = min(_people.length, GameLayout.queueVisible);
    // Back of the line first so the front person is drawn on top.
    for (var i = n - 1; i >= 0; i--) {
      final person = _people[i];
      final p = person.pos;
      canvas.drawOval(
        Rect.fromCenter(
          center: p.translate(0, _shadowDrop),
          width: _shadowWidth,
          height: _shadowHeight,
        ),
        Paint()..color = softShadow,
      );
      paintPassenger(canvas, p, person.color);
      if (game.showSymbols) paintPersonSymbol(canvas, p, person.color);
    }
  }
}
