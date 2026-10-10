import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'bus_escape_game.dart';
import 'layout.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

class _Person {
  _Person(this.color, this.pos);

  final int color;
  Offset pos;
}

/// Waiting passengers as little people in a line from the depot door. When
/// someone leaves for a vehicle the rest glide forward to close the gap.
class QueueView extends PositionComponent with HasGameReference<BusEscapeGame> {
  QueueView(this.layout) : super(priority: 5);

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
  }

  /// Removes the first waiting passenger of [color] and returns where they
  /// were standing, so a walking copy can start from there.
  Offset? take(int color) {
    final i = _people.indexWhere((p) => p.color == color);
    if (i < 0) return null;
    return _people.removeAt(i).pos;
  }

  @override
  void update(double dt) {
    final k = 1 - exp(-dt * 12);
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
        Rect.fromCenter(center: p.translate(0, 13), width: 14, height: 5),
        Paint()..color = const Color(0x22000000),
      );
      paintPassenger(canvas, p, person.color);
      if (game.showSymbols) {
        paintSymbol(canvas, p.translate(0, 4), 8, symbolFor(person.color));
      }
    }
  }
}
